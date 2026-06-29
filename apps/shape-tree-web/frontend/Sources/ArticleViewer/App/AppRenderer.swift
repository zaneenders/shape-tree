import JavaScriptEventLoop
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

  let response: JSValue
  do {
    response = try await fetchURL("/api/article").value
  } catch {
    setInnerText(shell.status, "Failed to load /api/article")
    return
  }

  let json: JSValue
  do {
    json = try await JSPromise(response.json().object!)!.value
  } catch {
    setInnerText(shell.status, "Failed to parse article JSON")
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
