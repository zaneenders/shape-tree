import JavaScriptKit
import ShapeTreeDOM

@JS public func renderArticleViewer(into container: JSValue) async {
  let shell = mountFeatureShell(
    into: container,
    className: "article-viewer",
    loadingMessage: "Loading article…"
  )

  let article = createElement("article", className: "article-content")
  append(article, to: shell.wrapper)

  let json: JSValue
  do {
    json = try await fetchResponseJSON("/api/article")
  } catch {
    setInnerText(shell.status, "Failed to load /api/article")
    return
  }

  guard let root = json.object?.root else {
    setInnerText(shell.status, "Article JSON missing root node")
    return
  }

  let html = renderMarkdownNode(root)
  setInnerHTML(article, html)
  setInnerText(shell.status, "Rendered from server-parsed markdown JSON")
}
