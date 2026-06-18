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
      }
      HTML.tag(.body, attrs: [.hxExt("head-support")]) {
        HTML.tag(.div, attrs: [.class("site-header")]) {
          HTML.tag(.h1, attrs: [.class("site-title")]) {
            HTML.tag(.a, attrs: [.href("/")]) { store.siteTitle }
          }
          HTML.tag(.p, attrs: [.class("site-tagline")]) { "Markdown from a content directory" }
        }
        HTML.tag(.div, attrs: [.id("htmx-loading"), .class("htmx-indicator site-loading")]) {
          "Loading…"
        }
        HTMX.Attributes.lazyNavShell(get: "/htmx/content/nav")
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
        name: "Home"
      ),
    ]

    for post in store.publishedPosts.prefix(12) {
      items.append(
        NavHTML.leaf(
          href: post.path,
          contentURL: post.contentURL,
          target: "main",
          name: post.title
        )
      )
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
      HTML.tag(.ul, attrs: [.class("post-list")]) {
        HTML.fragment(
          store.publishedPosts.map { post in
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
