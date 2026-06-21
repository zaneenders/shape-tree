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
    initial: Post,
    wasmBoot: (slug: String, title: String)? = nil
  ) -> HTML {
    var bodyAttrs: [HTMLAttr] = [.hxExt("head-support")]
    if let wasmBoot {
      bodyAttrs.append(.flag("data-initial-wasm-slug=\"\(htmlAttrEscape(wasmBoot.slug))\""))
      bodyAttrs.append(.flag("data-initial-wasm-title=\"\(htmlAttrEscape(wasmBoot.title))\""))
    }

    return document(bodyAttrs: bodyAttrs) {
      meta(attrs: [.charset("utf-8"), .name("viewport"), .content("width=device-width, initial-scale=1")])
      HTML.tag(.title, attrs: [.flag("data-site-title=\"\(htmlAttrEscape(store.siteTitle))\"")]) {
        pageTitle(for: initial, siteTitle: store.siteTitle)
      }
      style(attrs: [.hxPreserve]) { HTML.raw(site_css) }
      script(attrs: [.hxPreserve]) { HTML.raw(htmx_min_js) }
      script(attrs: [.hxPreserve]) { HTML.raw(htmx_head_support) }
      navClientScript()
    } body: {
      HTMX.Attributes.lazyNavShell(get: "/htmx/content/nav")
      div(attrs: [.id("htmx-loading"), .class("htmx-indicator"), .ariaLive("polite")]) { "Loading…" }
      main(attrs: [.id("main")]) {
        if let wasmBoot {
          p { "Loading \(wasmBoot.title)…" }
        } else {
          pageArticle(for: initial)
        }
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

  static func notFound(store: ContentStore) -> HTML {
    document(bodyAttrs: [.hxExt("head-support")]) {
      meta(attrs: [.charset("utf-8"), .name("viewport"), .content("width=device-width, initial-scale=1")])
      HTML.tag(.title, attrs: [.flag("data-site-title=\"\(htmlAttrEscape(store.siteTitle))\"")]) {
        "Not Found · \(store.siteTitle)"
      }
      style(attrs: [.hxPreserve]) { HTML.raw(site_css) }
      script(attrs: [.hxPreserve]) { HTML.raw(htmx_min_js) }
      script(attrs: [.hxPreserve]) { HTML.raw(htmx_head_support) }
      navClientScript()
    } body: {
      HTMX.Attributes.lazyNavShell(get: "/htmx/content/nav")
      div(attrs: [.id("htmx-loading"), .class("htmx-indicator"), .ariaLive("polite")]) { "Loading…" }
      main(attrs: [.id("main")]) {
        notFoundArticle()
      }
    }
  }

  static func notFoundResponse(store: ContentStore) -> Response {
    notFound(store: store).makeHTMLResponse(.notFound)
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

  private static func navClientScript() -> HTML {
    script(attrs: [.type("module"), .hxPreserve]) {
      HTML.raw(
        """
        import { init } from "/assets/client/index.js";

        function pageTitleFromSite(siteTitle, pageTitle) {
          return pageTitle ? `${pageTitle} · ${siteTitle}` : siteTitle;
        }

        function readSiteTitle() {
          return document.querySelector("title")?.dataset?.siteTitle ?? "";
        }

        const shapeTree = {
          async loadNotFound({ pushState = true, path = location.pathname } = {}) {
            const indicator = document.getElementById("htmx-loading");
            indicator?.classList.add("htmx-request");
            try {
              await htmx.ajax("GET", "/htmx/content/not-found", {
                target: "#main",
                swap: "innerHTML",
                headers: { "HX-Request": "true" },
              });
              document.title = pageTitleFromSite(readSiteTitle(), "Not Found");
              if (pushState) {
                history.pushState({ notFound: true, path }, "", path);
              }
            } finally {
              indicator?.classList.remove("htmx-request");
            }
          },

          async loadWasmPost(slug, { pushState = true, title = null } = {}) {
            const main = document.getElementById("main");
            const indicator = document.getElementById("htmx-loading");
            if (!main) return;
            main.innerHTML = "<p>Loading…</p>";
            indicator?.classList.add("htmx-request");
            const wasmPath = `/wasm/wasms/${encodeURIComponent(slug)}`;
            const postPath = `/wasm/posts/${encodeURIComponent(slug)}`;
            try {
              const response = await fetch(wasmPath, { cache: "no-store" });
              if (response.status === 404) {
                await shapeTree.loadNotFound({ pushState, path: postPath });
                return;
              }
              if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
              }
              await init({ module: response });
              const pageTitle = title ?? slug;
              document.title = pageTitleFromSite(readSiteTitle(), pageTitle);
              if (pushState) {
                history.pushState(
                  { wasmSlug: slug, title: pageTitle },
                  "",
                  postPath
                );
              }
            } catch (err) {
              main.innerHTML =
                `<p style="color:red">WASM load failed: ${err.message}</p>`;
              console.error("[wasm-post] load failed", err);
            } finally {
              indicator?.classList.remove("htmx-request");
            }
          },
        };

        globalThis.shapeTree = shapeTree;

        window.addEventListener("popstate", (event) => {
          const state = event.state;
          if (state?.wasmSlug) {
            void shapeTree.loadWasmPost(state.wasmSlug, {
              pushState: false,
              title: state.title ?? null,
            });
          } else if (state?.notFound) {
            void shapeTree.loadNotFound({
              pushState: false,
              path: state.path ?? location.pathname,
            });
          }
        });

        if (!window.__shapeTreeWasmNav) {
          window.__shapeTreeWasmNav = true;

          async function start() {
            await init({
              module: fetch("/assets/client/WASMNav.wasm", { cache: "no-store" }),
            });
          }

          if (document.body) {
            void start();
          } else {
            document.addEventListener("DOMContentLoaded", () => { void start(); });
          }
        }

        const bootSlug = document.body?.dataset?.initialWasmSlug;
        if (bootSlug) {
          const bootTitle = document.body?.dataset?.initialWasmTitle ?? null;
          history.replaceState(
            { wasmSlug: bootSlug, title: bootTitle },
            "",
            location.pathname
          );
          void shapeTree.loadWasmPost(bootSlug, { pushState: false, title: bootTitle });
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

  private static func htmlAttrEscape(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }

}
