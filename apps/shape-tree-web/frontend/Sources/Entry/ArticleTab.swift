import JavaScriptKit
import ShapeTreeDOM

func wireArticleTab(
  articleTab: JSValue,
  demoTab: JSValue,
  articlePanel: JSValue,
  demoPanel: JSValue
) {
  var articleLoaded = false

  let showDemo = JSClosure { _ -> JSValue in
    setAttribute(demoPanel, "aria-hidden", "false")
    setAttribute(articlePanel, "aria-hidden", "true")
    setAttribute(demoTab, "aria-selected", "true")
    setAttribute(articleTab, "aria-selected", "false")
    return .undefined
  }

  let showArticle = JSClosure { _ -> JSValue in
    setAttribute(demoPanel, "aria-hidden", "true")
    setAttribute(articlePanel, "aria-hidden", "false")
    setAttribute(demoTab, "aria-selected", "false")
    setAttribute(articleTab, "aria-selected", "true")

    if !articleLoaded {
      articleLoaded = true
      loadArticleViewer()
    }

    return .undefined
  }

  demoTab.onclick = .object(showDemo)
  articleTab.onclick = .object(showArticle)
}

private func loadArticleViewer() {
  guard let container = elementById("article-container") else { return }

  let promise = dynamicImport("/article-viewer-bootstrap.js")
  promise.then(success: { moduleValue in
    guard let module = moduleValue.object,
      let mountArticleViewer = module.mountArticleViewer.function
    else {
      return .undefined
    }
    _ = mountArticleViewer(container)
    return .undefined
  })
  promise.catch(failure: { _ in .undefined })
}
