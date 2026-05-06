import Foundation
import OpenAPIAsyncHTTPClient
import ShapeTreeClient

// MARK: - Main entry point

@main struct ShapeTreeClientCLI {
  static func main() async throws {
    let args = CommandLine.arguments
    let serverURL = parseServerURL(args) ?? "http://127.0.0.1:42069"
    let model = parseModel(args) ?? "gemma4:e2b"
    let ollamaURL = parseOllamaURL(args) ?? "http://127.0.0.1:11434"

    print("ShapeTree Client CLI")
    print("  server:  \(serverURL)")
    print("  model:   \(model)")
    print("  ollama:  \(ollamaURL)")
    print()

    guard let server = URL(string: serverURL) else {
      print("Error: invalid server URL: \(serverURL)")
      return
    }

    let transport = AsyncHTTPClientTransport()
    let client = Client(
      serverURL: server,
      transport: transport
    )

    // Create session
    print("Creating session...")
    let sessionResponse = try await client.createSession(
      .init(body: .json(.init(model: model, serverURL: ollamaURL)))
    )
    let session: Components.Schemas.CreateSessionResponse
    switch sessionResponse {
    case .ok(let ok):
      session = try ok.body.json
    case .badRequest(let err):
      let body = try err.body.json
      print("Error: \(body.error.message)")
      return
    case .undocumented(let code, _):
      print("Error: server returned \(code)")
      return
    }

    let sessionId = session.id
    print("Session: \(sessionId)")
    print("Type a message and press Enter.  /quit to exit.\n")

    // Interactive REPL
    while true {
      print("> ", terminator: "")
      guard let line = readLine() else { break }
      if line.isEmpty { continue }

      if line == "/quit" || line == "/exit" {
        print("Goodbye.")
        break
      }

      let completionResponse = try await client.runCompletion(
        path: .init(id: sessionId),
        body: .json(.init(message: line))
      )

      switch completionResponse {
      case .ok(let ok):
        let result = try ok.body.json
        print(result.assistant)
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

  // MARK: - Argument parsing

  static func parseServerURL(_ args: [String]) -> String? {
    valueForFlag("--server", args) ?? valueForFlag("-s", args)
  }

  static func parseModel(_ args: [String]) -> String? {
    valueForFlag("--model", args) ?? valueForFlag("-m", args)
  }

  static func parseOllamaURL(_ args: [String]) -> String? {
    valueForFlag("--ollama", args) ?? valueForFlag("-o", args)
  }

  static func valueForFlag(_ flag: String, _ args: [String]) -> String? {
    guard let idx = args.firstIndex(of: flag),
      idx + 1 < args.count
    else { return nil }
    return args[idx + 1]
  }
}
