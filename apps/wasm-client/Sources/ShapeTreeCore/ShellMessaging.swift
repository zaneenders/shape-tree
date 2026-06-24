import JavaScriptKit
import ShapeTreeKit

@JS public func handlePageMessage(_ message: JSObject) {
  PageMessageRouter.handle(PageMessage(unsafelyCopying: message))
}

enum PageMessageRouter {
  static func handle(_ message: PageMessage) {
    switch message.kind {
    case PageMessageKind.ready:
      log("page ready: \(message.path ?? "")")
    case PageMessageKind.setTitle:
      setDocumentTitle(message.payload)
    case PageMessageKind.navigate:
      guard let path = message.path else {
        log("navigate message missing path")
        return
      }
      Router.mountContent(
        path: path,
        title: message.payload,
        browserPath: nil,
        pushState: true
      )
    default:
      log("unknown page message: \(message.kind)")
    }
  }
}

func sendToPage(_ message: ShellMessage) {
  try? hostSendToPage(message.toJSObject())
}

func teardownActivePage() {
  sendToPage(ShellMessage(kind: ShellMessageKind.teardown, payload: nil))
}
