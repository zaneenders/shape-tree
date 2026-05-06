import Foundation
import OpenAPIAsyncHTTPClient
import ShapeTreeClient

// MARK: - Main entry point

@main struct ShapeTreeClientCLI {
  static func main() async throws {
    let serverURL = "http://127.0.0.1:42069"
    let model = "gemma4:e2b"
    let ollamaURL = "http://127.0.0.1:11434"

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

    print("Session: \(session.id)")
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
        path: .init(id: session.id),
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
}
