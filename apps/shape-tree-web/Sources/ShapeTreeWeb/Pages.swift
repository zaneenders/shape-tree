import Foundation
import HTML
import HTMX
import HTMXExtras
import Hummingbird
import ShapeTreeWebAssets
import ShapeTreeWebCore

enum WebPages {
  static func shell(
    store: ContentStore,
    homeSlug: String,
    documentTitle: String? = nil,
    wasmBoot: (slug: String, title: String)? = nil,
    bootNotFound: Bool = false
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
      div(attrs: [.id("htmx-loading"), .class("htmx-indicator"), .ariaLive("polite")]) { "Loading…" }
      main(attrs: [.id("main")]) {}
    }
  }

  static func navigation(store: ContentStore, isAuthenticated: Bool = false) -> HTML {
    var items: [HTML] = [
      NavHTML.leaf(
        href: "/",
        contentURL: "/htmx/content/index",
        target: "main",
        name: store.siteTitle
      )
    ]

    if !isAuthenticated {
      items.append(
        NavHTML.leaf(href: "/login", name: "Sign in")
      )
    }

    for group in store.postGroups(includingPrivate: isAuthenticated) {
      if let directory = group.directory {
        let branchItems = group.posts.map { post in
          navLeaf(for: post)
        }
        items.append(
          NavHTML.branch(
            id: navBranchID(for: directory),
            name: group.label,
            children: NavHTML.list(class: "nav-flyout", items: branchItems)
          )
        )
      } else {
        for post in group.posts {
          items.append(navLeaf(for: post))
        }
      }
    }

    return NavHTML.styled(NavHTML.list(class: "nav-root", items: items))
  }

  private static func navLeaf(for post: Post) -> HTML {
    if PostWasmAsset.isAvailable, !post.isIndex, !post.isLogin {
      return wasmNavLeaf(for: post)
    }
    return NavHTML.leaf(
      href: post.path,
      contentURL: post.contentURL,
      target: "main",
      name: post.title
    )
  }

  private static func wasmNavLeaf(for post: Post) -> HTML {
    li(attrs: [.class("nav-leaf")]) {
      a(attrs: [
        .class("nav-link nav-wasm-link"),
        .href("/wasm/posts/\(post.slug)"),
        .flag("data-wasm-slug=\"\(htmlAttrEscape(post.slug))\""),
        .flag("data-wasm-title=\"\(htmlAttrEscape(post.title))\""),
      ]) {
        post.title
      }
    }
  }

  static func pageArticle(for post: Post) -> HTML {
    if post.isIndex {
      return indexArticle(bodyHTML: post.bodyHTML)
    }
    return postArticle(post)
  }

  static func articleHTML(for post: Post) -> String {
    pageArticle(for: post).render()
  }

  static func contentFragment(for post: Post, store: ContentStore) -> String {
    HTMX.contentFragment(
      body: pageArticle(for: post).render(),
      baseHead: "",
      extraHead: HTML.tag(.title) { pageTitle(for: post, siteTitle: store.siteTitle) }
    )
  }

  static func notFoundResponse(store: ContentStore, homeSlug: String) -> Response {
    shell(
      store: store,
      homeSlug: homeSlug,
      documentTitle: "Not Found · \(store.siteTitle)",
      bootNotFound: true
    ).makeHTMLResponse(.notFound)
  }

  static func notFoundFragment(store: ContentStore) -> String {
    HTMX.contentFragment(
      body: notFoundArticle().render(),
      baseHead: "",
      extraHead: HTML.tag(.title) { "Not Found · \(store.siteTitle)" }
    )
  }

  static func notFoundArticle() -> HTML {
    article {
      h1 { "404" }
      p { "Page not found." }
    }
  }

  static func post(forSlug rawSlug: String, store: ContentStore) -> Post? {
    let slug = PostWasmAsset.slugCandidates(for: rawSlug).first ?? rawSlug
    return store.post(slug: slug)
  }

  static func canView(_ post: Post, isAuthenticated: Bool) -> Bool {
    !post.isPrivate || isAuthenticated
  }

  private static func indexArticle(bodyHTML: String) -> HTML {
    article {
      if !bodyHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        div(attrs: [.class("post-body")]) {
          HTML.raw(bodyHTML)
        }
      }
    }
  }

  private static func navBranchID(for directory: String) -> String {
    let sanitized =
      directory
      .lowercased()
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: " ", with: "-")
    return "nav-\(sanitized)"
  }

  private static func postArticle(_ post: Post) -> HTML {
    article {
      h1 { post.title }
      p(attrs: [.class("post-meta")]) {
        DateFormatting.displayString(from: post.date)
      }
      if !post.tags.isEmpty {
        ul(attrs: [.class("post-tags")]) {
          for tag in post.tags {
            li(attrs: [.class("post-tag")]) { tag }
          }
        }
      }
      div(attrs: [.class("post-body")]) {
        HTML.raw(post.bodyHTML)
      }
    }
  }

  private static func pageTitle(for post: Post, siteTitle: String) -> String {
    if post.isIndex {
      return siteTitle
    }
    return "\(post.title) · \(siteTitle)"
  }

  private static func htmlAttrEscape(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }

}
