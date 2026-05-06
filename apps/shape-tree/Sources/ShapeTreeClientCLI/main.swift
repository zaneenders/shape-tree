import ArgumentParser
import Foundation
import OpenAPIAsyncHTTPClient
import ShapeTreeClient

@main struct ShapeTreeClientCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "A CLI client for the ShapeTree server."
  )

  @Option(
    name: [ .long],
    help: "ShapeTree server URL."
  )
  var server: String = "http://127.0.0.1:42069"


  mutating func run() async throws {
    guard let serverURL = URL(string: server) else {
      throw ValidationError("Invalid server URL: \(server)")
    }

    let transport = AsyncHTTPClientTransport()
    let client = Client(
      serverURL: serverURL,
      transport: transport
    )

    // Create session (server uses its own configured model/LLM backend)
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
