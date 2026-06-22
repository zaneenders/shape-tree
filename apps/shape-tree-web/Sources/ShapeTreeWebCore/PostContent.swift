import Foundation

/// JSON body for `GET /api/get-post-content/:slug`.
public struct PostContentResponse: Codable, Sendable, Equatable {
  public var slug: String
  public var title: String
  public var articleHTML: String

  public init(slug: String, title: String, articleHTML: String) {
    self.slug = slug
    self.title = title
    self.articleHTML = articleHTML
  }
}

extension ContentStore {
  /// Pre-rendered article HTML for client-side display when page wasm is not embedded.
  public func postContentResponse(for post: Post) -> PostContentResponse {
    var html = "<article><h1>\(Self.escapeHTML(post.title))</h1>"
    html += "<p class=\"post-meta\">\(Self.escapeHTML(DateFormatting.displayString(from: post.date)))</p>"
    html += "<div class=\"post-body\">\(post.bodyHTML)</div></article>"

    return PostContentResponse(
      slug: post.slug,
      title: post.title,
      articleHTML: html
    )
  }

  private static func escapeHTML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }
}
