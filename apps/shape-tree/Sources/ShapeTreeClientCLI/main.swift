import Foundation
import OpenAPIAsyncHTTPClient
import ShapeTreeClient

// MARK: - Argument parsing

struct Args {
  let serverURL: String

  static func parse() -> Args {
    let defaultServer = "http://127.0.0.1:42069"
    var server = defaultServer

    var args = CommandLine.arguments.dropFirst()
    while let arg = args.popFirst() {
      switch arg {
      case "--server", "-s":
        if let val = args.popFirst() { server = val }
      case "--help", "-h":
        print("""
              Usage: shape-tree-cli [options]

              Options:
                -s, --server <url>   ShapeTree server URL (default: \(defaultServer))
                -h, --help           Show this help

              """)
        Foundation.exit(0)
      default:
        print("Unknown option: \(arg). Use --help for usage.")
        Foundation.exit(1)
      }
    }
    return Args(serverURL: server)
  }
}

// MARK: - Main entry point

@main struct ShapeTreeClientCLI {
  static func main() async throws {
    let args = Args.parse()

    guard let server = URL(string: args.serverURL) else {
      print("Error: invalid server URL: \(args.serverURL)")
      return
    }

    let transport = AsyncHTTPClientTransport()
    let client = Client(
      serverURL: server,
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
