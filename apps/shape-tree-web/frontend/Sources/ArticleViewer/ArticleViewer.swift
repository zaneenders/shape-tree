import JavaScriptEventLoop
import JavaScriptKit

@JS public func bootstrap() {
  JavaScriptEventLoop.installGlobalExecutor()
}
