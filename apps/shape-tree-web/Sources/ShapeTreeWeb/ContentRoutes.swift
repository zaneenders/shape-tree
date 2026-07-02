import Foundation
import HTTPTypes
import Hummingbird
import ShapeTreeContent
import ShapeTreeMarkdown
import ShapeTreeWebAuth

enum ContentRoutes {
  static func register(
    on router: Router<AppRequestContext>,
    store: ContentStore
  ) {
    for section in ContentSection.allCases {
      let sectionPath = section.rawValue.lowercased()

      router.get("api/content/\(sectionPath)") { _, context in
        let includingPrivate = context.identity != nil
        let items = store.posts(in: section, includingPrivate: includingPrivate).map {
          ContentListItem(post: $0)
        }
        return ContentListResponse(items: items)
      }

      router.get("api/content/\(sectionPath)/:slug") { _, context async throws in
        try detailResponse(for: context, store: store, section: section)
      }
    }
  }

  private static func detailResponse(
    for context: AppRequestContext,
    store: ContentStore,
    section: ContentSection
  ) throws -> ContentDetailResponse {
    guard let slug = context.parameters.get("slug"), !slug.isEmpty else {
      throw HTTPError(.badRequest)
    }

    guard let post = store.post(slug: slug, in: section) else {
      throw HTTPError(.notFound)
    }

    if post.isPrivate && context.identity == nil {
      throw HTTPError(.seeOther, headers: [.location: "/login?next=/"])
    }

    let document = parseArticleDocument(from: post.bodyMarkdown)
    return ContentDetailResponse(
      slug: post.slug,
      title: post.title,
      date: DateFormatting.isoString(from: post.date),
      dateDisplay: DateFormatting.displayString(from: post.date),
      tags: post.tags,
      excerpt: post.excerpt,
      root: document.root
    )
  }
}

private struct ContentListItem: ResponseEncodable {
  let slug: String
  let title: String
  let date: String?
  let dateDisplay: String?
  let excerpt: String?

  init(post: Post) {
    slug = post.slug
    title = post.title
    date = DateFormatting.isoString(from: post.date)
    dateDisplay = DateFormatting.displayString(from: post.date)
    excerpt = post.excerpt
  }
}

private struct ContentListResponse: ResponseEncodable {
  let items: [ContentListItem]
}

private struct ContentDetailResponse: ResponseEncodable {
  let slug: String
  let title: String
  let date: String?
  let dateDisplay: String?
  let tags: [String]
  let excerpt: String?
  let root: MarkdownNode
}
