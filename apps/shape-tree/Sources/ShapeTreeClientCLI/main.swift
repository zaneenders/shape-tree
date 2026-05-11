import ArgumentParser
import Crypto
import Foundation
import JWTKit
import OpenAPIAsyncHTTPClient
import ShapeTreeClient

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// MARK: - On-disk layout (auth.md, "CLI changes")

private enum CLIPaths {
  static let configDirRelative = ".config/shape-tree"
  static let privateKeyName = "id_p256.pem"
  static let metaName = "id_p256.meta.json"
  static let publicJWKName = "id_p256.pub.jwk"

  static var configDir: URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent(configDirRelative, isDirectory: true)
  }

  static var privateKey: URL { configDir.appendingPathComponent(privateKeyName, isDirectory: false) }
  static var meta: URL { configDir.appendingPathComponent(metaName, isDirectory: false) }
  static var publicJWK: URL { configDir.appendingPathComponent(publicJWKName, isDirectory: false) }
}

private struct ClientMeta: Codable {
  /// Cache of the RFC 7638 thumbprint; recomputed from the live public key on every read.
  var kid: String
  /// Human-readable device label; carried in the JWT `dev` header for log breadcrumbs.
  var label: String
}

// MARK: - Filesystem helpers (auth.md, "Keygen UX")

/// Refuses to operate on a config dir that is missing, group-writable, or a symlink.
/// Creates it `0700` if absent. Ensures the directory is owned by the invoking uid.
private func ensureSafeConfigDirectory() throws -> URL {
  let url = CLIPaths.configDir
  let fm = FileManager.default

  if !fm.fileExists(atPath: url.path) {
    let prev = umask(0o077)
    defer { _ = umask(prev) }
    try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    return url
  }

  let attrs = try fm.attributesOfItem(atPath: url.path)
  if let type = attrs[.type] as? FileAttributeType, type == .typeSymbolicLink {
    throw CLIError.unsafeConfigDirectory(reason: "\(url.path) is a symlink")
  }
  if let type = attrs[.type] as? FileAttributeType, type != .typeDirectory {
    throw CLIError.unsafeConfigDirectory(reason: "\(url.path) is not a directory")
  }
  if let mode = attrs[.posixPermissions] as? NSNumber {
    let perms = mode.uint16Value
    if perms & 0o022 != 0 {
      throw CLIError.unsafeConfigDirectory(
        reason: String(format: "%@ is group/world-writable (mode %04o)", url.path, perms))
    }
  }
  if let owner = attrs[.ownerAccountID] as? NSNumber {
    let me = getuid()
    if owner.uint32Value != me {
      throw CLIError.unsafeConfigDirectory(
        reason: "\(url.path) is owned by uid \(owner.uint32Value), not \(me)")
    }
  }
  return url
}

/// Atomically writes `data` to `destination` via a sibling temp file.
///
/// Sets `umask(0o077)` for the duration of the open so the file ends up at
/// `mode` immediately on creation; there is never a window during which the
/// file exists at a looser mode (auth.md, "Keygen UX").
private func atomicWrite(_ data: Data, to destination: URL, mode: Int) throws {
  let parent = destination.deletingLastPathComponent()
  let basename = destination.lastPathComponent
  let temp = parent.appendingPathComponent(".\(basename).tmp.\(UUID().uuidString)")

  let prev = umask(0o077)
  defer { _ = umask(prev) }

  let fm = FileManager.default
  if !fm.createFile(atPath: temp.path, contents: data, attributes: [.posixPermissions: mode]) {
    throw CLIError.fileWriteFailed(temp.path)
  }
  do {
    if fm.fileExists(atPath: destination.path) {
      _ = try? fm.removeItem(at: destination)
    }
    try fm.moveItem(at: temp, to: destination)
  } catch {
    _ = try? fm.removeItem(at: temp)
    throw error
  }
}

private func requireSafePrivateKeyFile(_ url: URL) throws {
  let fm = FileManager.default
  let attrs = try fm.attributesOfItem(atPath: url.path)
  if let type = attrs[.type] as? FileAttributeType, type != .typeRegular {
    throw CLIError.unsafePrivateKey(reason: "\(url.path) is not a regular file")
  }
  if let owner = attrs[.ownerAccountID] as? NSNumber, owner.uint32Value != getuid() {
    throw CLIError.unsafePrivateKey(reason: "\(url.path) is owned by uid \(owner.uint32Value)")
  }
  if let mode = attrs[.posixPermissions] as? NSNumber {
    let perms = mode.uint16Value & 0o777
    if perms & 0o077 != 0, perms != 0o640 {
      throw CLIError.unsafePrivateKey(
        reason: String(format: "%@ has unsafe mode %04o (want 0600)", url.path, perms))
    }
  }
}

// MARK: - Key handling

private func generateNewKey() -> ECDSA.PrivateKey<P256> {
  ECDSA.PrivateKey<P256>()
}

private func loadPrivateKey() throws -> ECDSA.PrivateKey<P256> {
  try requireSafePrivateKeyFile(CLIPaths.privateKey)
  let pem = try String(contentsOf: CLIPaths.privateKey, encoding: .utf8)
  return try ECDSA.PrivateKey<P256>(pem: pem)
}

/// Coordinates of a P-256 public key as base64url-no-padding strings (RFC 7515).
private struct ECCoords {
  let x: String
  let y: String
}

private func ecCoords(of publicKey: ECDSA.PublicKey<P256>) throws -> ECCoords {
  guard let params = publicKey.parameters else {
    throw CLIError.publicKeyExtractionFailed
  }
  let xRaw = Data(base64Encoded: params.x) ?? Data()
  let yRaw = Data(base64Encoded: params.y) ?? Data()
  return ECCoords(
    x: xRaw.base64URLEncodedStringNoPadding(),
    y: yRaw.base64URLEncodedStringNoPadding()
  )
}

/// JSON representation of the device's public JWK (server reads this format
/// from `authorized_keys/<kid>.jwk`). `label` is non-standard but persisted
/// inside the file so operators can `grep` for it during revocation.
private func publicJWKJSON(coords: ECCoords, kid: String, label: String) throws -> Data {
  let body: [String: String] = [
    "crv": "P-256",
    "kty": "EC",
    "x": coords.x,
    "y": coords.y,
    "alg": "ES256",
    "use": "sig",
    "kid": kid,
    "label": label,
  ]
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
  return try encoder.encode(body)
}

private func defaultDeviceLabel() -> String {
  if let host = ProcessInfo.processInfo.hostName.split(separator: ".").first {
    return String(host)
  }
  return "shape-tree-cli"
}

// MARK: - Top-level command

@main struct ShapeTreeClientCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "ShapeTree OpenAPI client and ES256 keypair tool.",
    subcommands: [Keygen.self, Pubkey.self, MintToken.self, Chat.self],
    defaultSubcommand: Chat.self
  )
}

// MARK: - keygen

extension ShapeTreeClientCLI {
  struct Keygen: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract:
        "Generate a P-256 keypair, store it under ~/.config/shape-tree/, print the public JWK."
    )

    @Option(name: .shortAndLong, help: "Human-readable label baked into the public JWK and used as the JWT `dev` header.")
    var label: String?

    @Flag(name: .shortAndLong, help: "Overwrite an existing private key.")
    var force: Bool = false

    func run() async throws {
      _ = try ensureSafeConfigDirectory()

      let fm = FileManager.default
      if fm.fileExists(atPath: CLIPaths.privateKey.path), !force {
        throw CLIError.privateKeyExists(path: CLIPaths.privateKey.path)
      }

      let key = generateNewKey()
      let coords = try ecCoords(of: key.publicKey)
      let kid = JWKThumbprint.thumbprint(crv: "P-256", x: coords.x, y: coords.y)
      let resolvedLabel = (label?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
        $0.isEmpty ? nil : $0
      } ?? defaultDeviceLabel()

      let pem = key.pemRepresentation
      try atomicWrite(Data(pem.utf8), to: CLIPaths.privateKey, mode: 0o600)

      let meta = ClientMeta(kid: kid, label: resolvedLabel)
      let metaJSON = try {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try enc.encode(meta)
      }()
      try atomicWrite(metaJSON, to: CLIPaths.meta, mode: 0o600)

      let pubJWK = try publicJWKJSON(coords: coords, kid: kid, label: resolvedLabel)
      try atomicWrite(pubJWK, to: CLIPaths.publicJWK, mode: 0o644)

      print(String(data: pubJWK, encoding: .utf8)!)
      print("")
      print("kid:    \(kid)")
      print("label:  \(resolvedLabel)")
      print("")
      print("Drop \(CLIPaths.publicJWK.path) into the server's authorized_keys/")
      print("directory as \(kid).jwk to enroll this device.")
    }
  }
}

// MARK: - pubkey

extension ShapeTreeClientCLI {
  struct Pubkey: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Print the public JWK and the SSH-style one-liner for the on-disk keypair."
    )

    func run() async throws {
      let key = try loadPrivateKey()
      let coords = try ecCoords(of: key.publicKey)
      let kid = JWKThumbprint.thumbprint(crv: "P-256", x: coords.x, y: coords.y)

      let storedLabel: String = {
        guard let metaData = try? Data(contentsOf: CLIPaths.meta),
          let stored = try? JSONDecoder().decode(ClientMeta.self, from: metaData)
        else { return defaultDeviceLabel() }
        return stored.label
      }()

      let json = try publicJWKJSON(coords: coords, kid: kid, label: storedLabel)
      print(String(data: json, encoding: .utf8)!)
      print("")
      print("ES256 \(kid) \(storedLabel)")
    }
  }
}

// MARK: - mint-token

extension ShapeTreeClientCLI {
  struct MintToken: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "mint-token",
      abstract: "Sign a short-lived ES256 JWT with the on-disk private key."
    )

    @Option(name: .customLong("ttl-seconds"), help: "Lifetime in seconds (default: 900).")
    var ttlSeconds: UInt64 = 900

    func run() async throws {
      let key = try loadPrivateKey()
      let storedLabel: String = {
        guard let metaData = try? Data(contentsOf: CLIPaths.meta),
          let stored = try? JSONDecoder().decode(ClientMeta.self, from: metaData)
        else { return defaultDeviceLabel() }
        return stored.label
      }()
      let token = try await ShapeTreeTokenIssuer.mintES256(
        privateKey: key,
        deviceLabel: storedLabel,
        ttl: TimeInterval(ttlSeconds)
      )
      print(token)
    }
  }
}

// MARK: - chat (default subcommand: REPL)

extension ShapeTreeClientCLI {
  struct Chat: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Open an interactive REPL against a ShapeTree server."
    )

    @Option(name: .long, help: "ShapeTree server URL.")
    var server: String = "http://127.0.0.1:42069"

    @Option(
      name: [.short, .long],
      help: "Bearer JWT to use verbatim. If unset, mints one with the on-disk ES256 keypair."
    )
    var token: String = ""

    @Option(name: .customLong("ttl-seconds"), help: "Auto-mint lifetime in seconds (default: 900).")
    var ttlSeconds: UInt64 = 900

    func run() async throws {
      guard let serverURL = URL(string: server) else {
        throw ValidationError("Invalid server URL: \(server)")
      }

      let bearer: String
      if !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        bearer = ShapeTreeAPIClientMiddleware.normalizedBearerJWT(token)
      } else {
        let key = try loadPrivateKey()
        let storedLabel: String = {
          guard let metaData = try? Data(contentsOf: CLIPaths.meta),
            let stored = try? JSONDecoder().decode(ClientMeta.self, from: metaData)
          else { return defaultDeviceLabel() }
          return stored.label
        }()
        bearer = try await ShapeTreeTokenIssuer.mintES256(
          privateKey: key,
          deviceLabel: storedLabel,
          ttl: TimeInterval(ttlSeconds)
        )
      }

      let transport = AsyncHTTPClientTransport()
      let middlewares = ShapeTreeAPIClientMiddleware.bearerJWT(bearer)
      let client = Client(
        serverURL: serverURL,
        transport: transport,
        middlewares: middlewares
      )

      print("Creating session...")
      let sessionResponse = try await client.createSession(
        .init(body: .json(.init()))
      )

      let session: Components.Schemas.CreateSessionResponse
      switch sessionResponse {
      case .ok(let ok):
        session = try ok.body.json
      case .badRequest(let err):
        let body = try err.body.json
        throw ValidationError("Error: \(body.error.message)")
      case .undocumented(let code, _):
        throw ValidationError("Error: server returned \(code)")
      }

      print("Session: \(session.id)")
      print("Type a message and press Enter.  /quit to exit.\n")

      while true {
        FileHandle.standardOutput.write(Data("> ".utf8))
        guard let line = readLine() else { break }
        if line.isEmpty { continue }
        if line == "/quit" || line == "/exit" {
          print("Goodbye.")
          break
        }

        let completionResponse = try await client.runCompletionStream(
          path: .init(id: session.id),
          body: .json(.init(message: line))
        )

        switch completionResponse {
        case .ok(let ok):
          do {
            let stream = try ok.decodedCompletionEvents()
            for try await event in stream {
              switch event.kind {
              case .assistant_delta:
                if let fragment = event.text, !fragment.isEmpty {
                  print(fragment, terminator: "")
                }
              case .done:
                break
              case .harness_error:
                let msg = event.harness_error_message ?? "Completion error."
                print()
                print("Error: \(msg)")
              default:
                break
              }
            }
          } catch {
            print()
            print("Error: \(error.localizedDescription)")
          }
        case .badRequest(let err):
          let body = try err.body.json
          print("Error: \(body.error.message)")
        case .notFound(let err):
          let body = try err.body.json
          print("Error: \(body.error.message)")
        case .internalServerError(let err):
          let body = try err.body.json
          print("Error: \(body.error.message)")
        case .undocumented(let code, _):
          print("Error: server returned \(code)")
        }
        print()
      }
    }
  }
}

// MARK: - Errors

private enum CLIError: Error, CustomStringConvertible {
  case unsafeConfigDirectory(reason: String)
  case unsafePrivateKey(reason: String)
  case privateKeyExists(path: String)
  case fileWriteFailed(String)
  case publicKeyExtractionFailed

  var description: String {
    switch self {
    case .unsafeConfigDirectory(let reason): return "unsafe config directory: \(reason)"
    case .unsafePrivateKey(let reason): return "unsafe private key file: \(reason)"
    case .privateKeyExists(let path): return "\(path) already exists; pass --force to overwrite"
    case .fileWriteFailed(let path): return "failed to write \(path)"
    case .publicKeyExtractionFailed: return "could not read x/y from generated key"
    }
  }
}
