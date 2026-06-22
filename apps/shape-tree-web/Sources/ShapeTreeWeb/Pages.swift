import Foundation
import HTML
import Hummingbird
import ShapeTreeWebAssets
import ShapeTreeWebCore

enum WebPages {
  static func shell(
    store: ContentStore,
    homeSlug: String,
    documentTitle: String? = nil,
    wasmBoot: (slug: String, title: String)? = nil,
    bootNotFound: Bool = false,
    bootLogin: Bool = false,
    loginNext: String? = nil,
    bootVerify: Bool = false,
    verifyToken: String? = nil,
    verifyNext: String? = nil,
    bootCheckEmail: Bool = false
  ) -> HTML {
    var bodyAttrs: [HTMLAttr] = []
    bodyAttrs.append(.flag("data-home-slug=\"\(htmlAttrEscape(homeSlug))\""))
    bodyAttrs.append(.flag("data-home-title=\"\(htmlAttrEscape(store.siteTitle))\""))

    if let wasmBoot {
      bodyAttrs.append(.flag("data-initial-wasm-slug=\"\(htmlAttrEscape(wasmBoot.slug))\""))
      bodyAttrs.append(.flag("data-initial-wasm-title=\"\(htmlAttrEscape(wasmBoot.title))\""))
    }
    if bootNotFound {
      bodyAttrs.append(.flag("data-boot-not-found=\"true\""))
    }
    if bootLogin {
      bodyAttrs.append(.flag("data-boot-login=\"true\""))
      if let loginNext, !loginNext.isEmpty {
        bodyAttrs.append(.flag("data-login-next=\"\(htmlAttrEscape(loginNext))\""))
      }
    }
    if bootVerify {
      bodyAttrs.append(.flag("data-boot-verify=\"true\""))
      if let verifyToken, !verifyToken.isEmpty {
        bodyAttrs.append(.flag("data-verify-token=\"\(htmlAttrEscape(verifyToken))\""))
      }
      if let verifyNext, !verifyNext.isEmpty {
        bodyAttrs.append(.flag("data-verify-next=\"\(htmlAttrEscape(verifyNext))\""))
      }
    }
    if bootCheckEmail {
      bodyAttrs.append(.flag("data-boot-check-email=\"true\""))
    }

    let titleText = documentTitle ?? store.siteTitle

    return document(bodyAttrs: bodyAttrs) {
      meta(attrs: [.charset("utf-8"), .name("viewport"), .content("width=device-width, initial-scale=1")])
      HTML.tag(.title, attrs: [.flag("data-site-title=\"\(htmlAttrEscape(store.siteTitle))\"")]) {
        titleText
      }
      style { HTML.raw(site_css) }
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

  static func notFoundResponse(store: ContentStore, homeSlug: String) -> Response {
    shell(
      store: store,
      homeSlug: homeSlug,
      documentTitle: "Not Found · \(store.siteTitle)",
      bootNotFound: true
    ).makeHTMLResponse(.notFound)
  }

  static func post(forSlug rawSlug: String, store: ContentStore) -> Post? {
    let slug = PostWasmAsset.slugCandidates(for: rawSlug).first ?? rawSlug
    return store.post(slug: slug)
  }

  static func canView(_ post: Post, isAuthenticated: Bool) -> Bool {
    !post.isPrivate || isAuthenticated
  }

  static func wasmPage(
    forSlug rawSlug: String,
    store: ContentStore,
    isAuthenticated: Bool
  ) -> WasmPage? {
    let slug = PostWasmAsset.slugCandidates(for: rawSlug).first ?? rawSlug
    if let post = store.post(slug: slug) {
      guard canView(post, isAuthenticated: isAuthenticated) else { return nil }
      return WasmPage(slug: post.slug, title: post.title, isLogin: post.isLogin)
    }
    if let page = AppPages.page(slug: slug) {
      guard !page.isPrivate || isAuthenticated else { return nil }
      return WasmPage(slug: page.slug, title: page.title)
    }
    return nil
  }

  private static func htmlAttrEscape(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }

}
