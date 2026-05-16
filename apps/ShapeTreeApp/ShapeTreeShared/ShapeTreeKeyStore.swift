import CryptoKit
import Foundation
import Security
import ShapeTreeClient

@MainActor
public final class ShapeTreeKeyStore {

  public enum KeyStoreError: Error, LocalizedError {
    case keychain(OSStatus)
    case missingMaterial
    case malformedKeyMaterial
    case secureEnclaveUnavailable

    public var errorDescription: String? {
      switch self {
      case .keychain(let s): return "Keychain error: OSStatus \(s)"
      case .missingMaterial: return "Device key material missing — generate a key first."
      case .malformedKeyMaterial:
        return "Stored key material is malformed — remove it under Connection settings, then regenerate."
      case .secureEnclaveUnavailable:
        return "The Secure Enclave is not available on this device."
      }
    }
  }

  private static let keychainService = "org.shapetree.shapetree-client.es256"
  private static let keychainAccount = "device-p256-v1"
  private static let labelDefaultsKey = "shape_tree_device_label"

  private var cached: SecureEnclave.P256.Signing.PrivateKey?
  private let labelOverride: String?

  public init(labelOverride: String? = nil) {
    self.labelOverride = labelOverride
  }

  public var deviceLabel: String {
    get {
      if let labelOverride { return labelOverride }
      if let stored = UserDefaults.standard.string(forKey: Self.labelDefaultsKey)?
        .trimmingCharacters(in: .whitespacesAndNewlines), !stored.isEmpty
      {
        return stored
      }
      return Self.defaultDeviceLabel()
    }
    set {
      let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty {
        UserDefaults.standard.removeObject(forKey: Self.labelDefaultsKey)
      } else {
        UserDefaults.standard.set(trimmed, forKey: Self.labelDefaultsKey)
      }
    }
  }

  public var hasKey: Bool {
    if cached != nil { return true }
    return (try? readKeychainBytes()) != nil
  }

  @discardableResult
  public func loadOrGenerate() throws -> SecureEnclave.P256.Signing.PrivateKey {
    if let cached { return cached }
    if let raw = try readKeychainBytes() {
      let key = try Self.deserialize(raw)
      cached = key
      return key
    }
    let key = try Self.generate()
    try writeKeychainBytes(Self.serialize(key))
    cached = key
    return key
  }

  @discardableResult
  public func regenerate() throws -> SecureEnclave.P256.Signing.PrivateKey {
    let key = try Self.generate()
    try writeKeychainBytes(Self.serialize(key))
    cached = key
    return key
  }

  public func deleteKeyMaterial() throws {
    cached = nil
    let q: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.keychainService,
      kSecAttrAccount as String: Self.keychainAccount,
    ]
    let status = SecItemDelete(q as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeyStoreError.keychain(status)
    }
  }

  // MARK: - Public key surface

  public func publicX963Representation() throws -> Data {
    let key = try loadOrGenerate()
    return key.publicKey.x963Representation
  }

  public func kid() throws -> String {
    let raw = try publicX963Representation()
    return try JWKThumbprint.thumbprint(rawP256PublicKey: raw)
  }

  public func publicJWK() throws -> [String: String] {
    let raw = try publicX963Representation()
    let xRaw = raw.subdata(in: 1..<33)
    let yRaw = raw.subdata(in: 33..<65)
    let x = xRaw.base64URLEncodedStringNoPadding()
    let y = yRaw.base64URLEncodedStringNoPadding()
    let kid = JWKThumbprint.thumbprint(crv: "P-256", x: x, y: y)
    return [
      "alg": "ES256",
      "crv": "P-256",
      "kid": kid,
      "kty": "EC",
      "label": deviceLabel,
      "use": "sig",
      "x": x,
      "y": y,
    ]
  }

  public func publicJWKJSON() throws -> String {
    let dict = try publicJWK()
    let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    return String(decoding: data, as: UTF8.self)
  }

  // MARK: - Signing

  /// Preferred app entry point for auth headers; signs via ``ShapeTreeTokenIssuer``.
  public func mintES256JWT(ttl: TimeInterval = 900) throws -> String {
    let kid = try kid()
    let label = deviceLabel
    let key = try loadOrGenerate()
    return try ShapeTreeTokenIssuer.mintES256(
      kid: kid,
      deviceLabel: label,
      ttl: ttl,
      sign: { data in
        try key.signature(for: data).rawRepresentation
      }
    )
  }

  // MARK: - Internals

  private static func generate() throws -> SecureEnclave.P256.Signing.PrivateKey {
    guard SecureEnclave.isAvailable else {
      throw KeyStoreError.secureEnclaveUnavailable
    }
    return try SecureEnclave.P256.Signing.PrivateKey()
  }

  private static func serialize(_ key: SecureEnclave.P256.Signing.PrivateKey) -> Data {
    key.dataRepresentation
  }

  private static func deserialize(_ data: Data) throws -> SecureEnclave.P256.Signing.PrivateKey {
    guard SecureEnclave.isAvailable else {
      throw KeyStoreError.secureEnclaveUnavailable
    }
    if let key = try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data) {
      return key
    }
    throw KeyStoreError.malformedKeyMaterial
  }

  private static func defaultDeviceLabel() -> String {
    #if canImport(UIKit) && !os(macOS)
    return ProcessInfo.processInfo.hostName.split(separator: ".").first.map(String.init)
      ?? "shape-tree-iphone"
    #else
    return Host.current().localizedName ?? "shape-tree-mac"
    #endif
  }

  // MARK: - Keychain bytes (generic password)

  private func readKeychainBytes() throws -> Data? {
    let q: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.keychainService,
      kSecAttrAccount as String: Self.keychainAccount,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(q as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw KeyStoreError.keychain(status) }
    return item as? Data
  }

  private func writeKeychainBytes(_ data: Data) throws {
    let removeQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.keychainService,
      kSecAttrAccount as String: Self.keychainAccount,
    ]
    SecItemDelete(removeQuery as CFDictionary)

    let addQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.keychainService,
      kSecAttrAccount as String: Self.keychainAccount,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let status = SecItemAdd(addQuery as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeyStoreError.keychain(status) }
  }
}
