import Foundation
import HTML
import HTMX
import HTMXExtras
import ShapeTreeWebAssets
import ShapeTreeWebCore

enum WebPages {
  static func shell(store: ContentStore, initial: Post) -> HTML {
    document(bodyAttrs: [.hxExt("head-support")]) {
      meta(attrs: [.charset("utf-8"), .name("viewport"), .content("width=device-width, initial-scale=1")])
      HTML.tag(.title) { pageTitle(for: initial, siteTitle: store.siteTitle) }
      style(attrs: [.hxPreserve]) { HTML.raw(site_css) }
      script(attrs: [.hxPreserve]) { HTML.raw(htmx_min_js) }
      script(attrs: [.hxPreserve]) { HTML.raw(htmx_head_support) }
      navClientScript()
    } body: {
      HTMX.Attributes.lazyNavShell(get: "/htmx/content/nav")
      div(attrs: [.id("htmx-loading"), .class("htmx-indicator"), .ariaLive("polite")]) { "Loading…" }
      main(attrs: [.id("main")]) {
        pageArticle(for: initial)
      }
    }
  }

  static func wasmPostShell(slug: String, title: String, siteTitle: String) -> HTML {
    document(bodyAttrs: [.hxExt("head-support")]) {
      meta(attrs: [.charset("utf-8"), .name("viewport"), .content("width=device-width, initial-scale=1")])
      HTML.tag(.title) { "\(title) · \(siteTitle)" }
      style(attrs: [.hxPreserve]) { HTML.raw(site_css) }
      script(attrs: [.hxPreserve]) { HTML.raw(htmx_min_js) }
      script(attrs: [.hxPreserve]) { HTML.raw(htmx_head_support) }
      navClientScript()
    } body: {
      HTMX.Attributes.lazyNavShell(get: "/htmx/content/nav")
      div(attrs: [.id("htmx-loading"), .class("htmx-indicator"), .ariaLive("polite")]) { "Loading…" }
      main(attrs: [.id("main")]) {
        p { "Loading \(title) via WASM…" }
      }
      script(attrs: [.type("module")]) {
        HTML.raw(
          """
          import { init } from "/assets/client/index.js";

          async function start() {
            try {
              await init({
                module: fetch("/wasm/wasms/\(slug)", { cache: "no-store" }),
              });
            } catch (err) {
              document.getElementById("main").innerHTML =
                "<p style=\\\"color:red\\\">WASM load failed: " + err.message + "</p>";
              console.error("[wasm-post] load failed", err);
            }
          }
          void start();
          """
        )
      }
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
      return NavHTML.leaf(
        href: "/wasm/posts/\(post.slug)",
        name: post.title
      )
    }
    return NavHTML.leaf(
      href: post.path,
      contentURL: post.contentURL,
      target: "main",
      name: post.title
    )
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

  private static func navClientScript() -> HTML {
    script(attrs: [.type("module"), .hxPreserve]) {
      HTML.raw(
        """
        import { init } from "/assets/client/index.js";

        if (!window.__shapeTreeNavDismiss) {
          window.__shapeTreeNavDismiss = true;

          async function start() {
            await init({
              module: fetch("/assets/client/WASMClient.wasm", { cache: "no-store" }),
            });
          }

          if (document.body) {
            void start();
          } else {
            document.addEventListener("DOMContentLoaded", () => { void start(); });
          }
        }
        """
      )
    }
  }

  private static func pageTitle(for post: Post, siteTitle: String) -> String {
    if post.isIndex {
      return siteTitle
    }
    return "\(post.title) · \(siteTitle)"
  }

}
