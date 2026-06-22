import Foundation
import HTML
import Hummingbird
import ShapeTreeWebAssets
import ShapeTreeWebCore

enum WebPages {
  static func shell(
    store: ContentStore,
    documentTitle: String? = nil
  ) -> HTML {
    let titleText = documentTitle ?? store.siteTitle

    return document(bodyAttrs: shellBodyAttrs(store: store)) {
      meta(attrs: [.charset("utf-8"), .name("viewport"), .content("width=device-width, initial-scale=1")])
      HTML.tag(.title, attrs: [.flag("data-site-title=\"\(htmlAttrEscape(store.siteTitle))\"")]) {
        titleText
      }
      style { HTML.raw(site_css) }
      script(attrs: [.type("importmap")]) {
        HTML.raw(clientImportMapJSON)
      }
      script(attrs: [.type("module"), .src("/assets/client/bootstrap.js")]) {}
    } body: {
      HTML.tag(
        .nav,
        attrs: [
          .id("styled-navigation"),
          .class("site-nav"),
          .ariaLabel("Site"),
        ]
      ) {}
      div(attrs: [.id("site-loading"), .class("site-loading"), .ariaLive("polite")]) { "Loading…" }
      main(attrs: [.id("main")]) {}
    }
  }

  private static let clientImportMapJSON = """
    {"imports":{"@bjorn3/browser_wasi_shim":"/assets/client/browser_wasi_shim.js"}}
    """

  private static func shellBodyAttrs(store: ContentStore) -> [HTMLAttr] {
    [
      .flag("data-index-path=\"\(htmlAttrEscape(store.indexPath))\""),
      .flag("data-site-title=\"\(htmlAttrEscape(store.siteTitle))\""),
    ]
  }

  static func notFoundResponse(store: ContentStore) -> Response {
    shell(
      store: store,
      documentTitle: "Not Found · \(store.siteTitle)"
    ).makeHTMLResponse(.notFound)
  }

  private static func htmlAttrEscape(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }
}
