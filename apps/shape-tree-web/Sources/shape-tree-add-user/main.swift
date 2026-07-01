import ArgumentParser
import Logging
import ShapeTreeWebAuth

@main
struct ShapeTreeAddUser: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "shape-tree-add-user",
    abstract: "Add a ShapeTreeWeb user to the auth database.",
    shouldDisplay: true
  )

  @Argument(help: "Email address of the user to add.")
  var email: String

  func run() async throws {
    let logger = Logger(label: "shape-tree-add-user")
    try await AuthCLI.addUser(email: email, logger: logger)
  }
}
