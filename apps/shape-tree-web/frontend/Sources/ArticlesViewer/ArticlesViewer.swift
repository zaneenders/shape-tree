import ContentRendering
import JavaScriptKit
import ShapeTreeDOM

@JS public func bootstrap() {
  installEventLoop()
}

@JS public func renderArticlesViewer(into container: JSValue) async {
  await renderContentBrowser(
    into: container,
    config: ContentBrowserConfig(
      listPath: "/api/content/articles",
      detailPathPrefix: "/api/content/articles/",
      className: "articles-viewer",
      emptyMessage: "No articles found in the content directory."
    )
  )
}
