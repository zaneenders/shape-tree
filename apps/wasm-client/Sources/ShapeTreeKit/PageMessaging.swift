import JavaScriptKit

public enum PageMessaging {
  public static func post(_ message: PageMessage) {
    try? hostPostToShell(message)
  }

  public static func ready(path: String) {
    post(PageMessage(kind: PageMessageKind.ready, path: path, payload: nil))
  }

  public static func setTitle(_ title: String) {
    post(PageMessage(kind: PageMessageKind.setTitle, path: nil, payload: title))
  }

  public static func navigate(path: String, title: String? = nil) {
    post(PageMessage(kind: PageMessageKind.navigate, path: path, payload: title))
  }

  public static func renderHTML(intoMain html: String) {
    guard let main = try? pageDocument.getElementById("main") else { return }
    try? main.setInnerHTML(html)
  }

  public static func log(_ message: String) {
    try? pageConsole.log(message)
  }
}
