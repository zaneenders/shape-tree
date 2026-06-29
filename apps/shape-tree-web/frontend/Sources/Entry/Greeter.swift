import JavaScriptKit

@JS class Greeter {
  @JS var name: String

  @JS init(name: String) {
    self.name = name
  }

  @JS public func greet() -> String {
    "Hello, " + name + "!"
  }
}
