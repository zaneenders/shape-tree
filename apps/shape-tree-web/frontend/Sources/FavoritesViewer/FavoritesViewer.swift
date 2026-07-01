import ContentRendering
import JavaScriptKit
import ShapeTreeDOM

@JS public func bootstrap() {
  installEventLoop()
}

@JS public func renderFavoritesViewer(into container: JSValue) async {
  await renderContentBrowser(
    into: container,
    config: ContentBrowserConfig(
      listPath: "/api/content/favorites",
      detailPathPrefix: "/api/content/favorites/",
      className: "favorites-viewer",
      emptyMessage: "No favorites found in the content directory."
    )
  )
}
