import Foundation
import HTML
import HTMX
import HTMXExtras
import ShapeTreeWebAssets
import ShapeTreeWebCore

enum WebPages {
  static func shell(store: ContentStore, initial: Post) -> HTML {
    HTML.tag(.html) {
      HTML.tag(.head) {
        HTML.raw(#"<meta charset="utf-8">"#)
        HTML.void(.meta, attrs: [.name("viewport"), .content("width=device-width, initial-scale=1")])
        HTML.tag(.title) { pageTitle(for: initial, siteTitle: store.siteTitle) }
        HTML.raw("<style hx-preserve=\"true\">\n\(site_css)\n</style>")
        HTML.raw("<script hx-preserve=\"true\">\n\(htmx_min_js)\n</script>")
        HTML.raw("<script hx-preserve=\"true\">\n\(htmx_head_support)\n</script>")
        navClientScript()
      }
      HTML.tag(.body, attrs: [.hxExt("head-support")]) {
        HTMX.Attributes.lazyNavShell(get: "/htmx/content/nav")
        HTML.raw(#"<div id="htmx-loading" class="htmx-indicator" aria-live="polite">Loading…</div>"#)
        HTML.tag(.main, attrs: [.id("main")]) {
          pageArticle(for: initial, store: store)
        }
      }
    }
  }

  static func navigation(store: ContentStore) -> HTML {
    var items: [HTML] = [
      NavHTML.leaf(
        href: "/",
        contentURL: "/htmx/content/index",
        target: "main",
        name: store.siteTitle
      )
    ]

    for group in store.publishedPostGroups {
      if let directory = group.directory {
        let branchItems = group.posts.map { post in
          NavHTML.leaf(
            href: post.path,
            contentURL: post.contentURL,
            target: "main",
            name: post.title
          )
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
          items.append(
            NavHTML.leaf(
              href: post.path,
              contentURL: post.contentURL,
              target: "main",
              name: post.title
            )
          )
        }
      }
    }

    return NavHTML.styled(NavHTML.list(class: "nav-root", items: items))
  }

  static func pageArticle(for post: Post, store: ContentStore) -> HTML {
    if post.slug == ContentStore.indexSlug {
      return indexArticle(store: store, bodyHTML: post.bodyHTML)
    }
    return postArticle(post)
  }

  static func contentFragment(for post: Post, store: ContentStore) -> String {
    HTMX.contentFragment(
      body: pageArticle(for: post, store: store).render(),
      baseHead: "",
      extraHead: HTML.tag(.title) { pageTitle(for: post, siteTitle: store.siteTitle) }
    )
  }

  private static func indexArticle(store: ContentStore, bodyHTML: String) -> HTML {
    article {
      h1 { "Posts" }
      if !bodyHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        HTML.tag(.div, attrs: [.class("post-body")]) {
          HTML.raw(bodyHTML)
        }
      }
      let groups = store.publishedPostGroups
      if groups.count == 1, groups[0].directory == nil {
        postList(for: groups[0].posts)
      } else {
        HTML.fragment(
          groups.map { group in
            HTML.tag(.div, attrs: [.class("post-group")]) {
              if group.directory != nil {
                HTML.tag(.div, attrs: [.class("post-group-title")]) { group.label }
              }
              postList(for: group.posts)
            }
          }
        )
      }
    }
  }

  private static func postList(for posts: [Post]) -> HTML {
    HTML.tag(.ul, attrs: [.class("post-list")]) {
      HTML.fragment(
        posts.map { post in
          HTML.tag(.li, attrs: [.class("post-list-item")]) {
            HTML.tag(.div, attrs: [.class("post-list-title")]) {
              HTML.tag(.a, attrs: [.href(post.path)]) { post.title }
            }
            HTML.tag(.p, attrs: [.class("post-meta")]) {
              formattedDate(post.date)
            }
            if let excerpt = post.excerpt, !excerpt.isEmpty {
              HTML.tag(.p, attrs: [.class("post-list-excerpt")]) { excerpt }
            }
          }
        }
      )
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
      HTML.tag(.p, attrs: [.class("post-meta")]) {
        formattedDate(post.date)
      }
      if !post.tags.isEmpty {
        HTML.tag(.ul, attrs: [.class("post-tags")]) {
          HTML.fragment(
            post.tags.map { tag in
              HTML.tag(.li, attrs: [.class("post-tag")]) { tag }
            }
          )
        }
      }
      HTML.tag(.div, attrs: [.class("post-body")]) {
        HTML.raw(post.bodyHTML)
      }
    }
  }

  private static func navClientScript() -> HTML {
    HTML.raw(
      """
      <script type="module" hx-preserve="true">
      import { init } from "/assets/nav-client/index.js";

      if (!window.__shapeTreeNavDismiss) {
        window.__shapeTreeNavDismiss = true;

        async function start() {
          await init({
            module: fetch("/assets/nav-client/WASMClient.wasm", { cache: "no-store" }),
          });
        }

        if (document.body) {
          void start();
        } else {
          document.addEventListener("DOMContentLoaded", () => { void start(); });
        }
      }
      </script>
      """
    )
  }

  private static func pageTitle(for post: Post, siteTitle: String) -> String {
    if post.slug == ContentStore.indexSlug {
      return siteTitle
    }
    return "\(post.title) · \(siteTitle)"
  }

  private static func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }
}
