import JavaScriptKit
import ShapeTreeDOM

public struct ContentBrowserConfig {
  public let listPath: String
  public let detailPathPrefix: String
  public let historyPathPrefix: String
  public let className: String
  public let emptyMessage: String

  public init(
    listPath: String,
    detailPathPrefix: String,
    historyPathPrefix: String,
    className: String,
    emptyMessage: String
  ) {
    self.listPath = listPath
    self.detailPathPrefix = detailPathPrefix
    self.historyPathPrefix = historyPathPrefix
    self.className = className
    self.emptyMessage = emptyMessage
  }

  var historyListPath: String {
    if historyPathPrefix.hasSuffix("/") {
      return String(historyPathPrefix.dropLast())
    }
    return historyPathPrefix
  }
}

@JS public func renderContentBrowser(into container: JSValue, config: ContentBrowserConfig) async {
  let shell = mountFeatureShell(
    into: container,
    className: config.className,
    loadingMessage: "Loading…"
  )

  let listView = createElement("div", className: "content-list-view")
  let detailView = createElement("div", className: "content-detail-view")
  setHidden(detailView, true)
  append(listView, to: shell.wrapper)
  append(detailView, to: shell.wrapper)

  let json: JSValue
  do {
    json = try await fetchResponseJSON(config.listPath)
  } catch {
    setInnerText(shell.status, "Failed to load \(config.listPath)")
    return
  }

  guard let items = json.object?.items.object else {
    setInnerText(shell.status, "List response missing items")
    return
  }

  let count = Int(items.length.number ?? 0)
  if count == 0 {
    setInnerText(shell.status, config.emptyMessage)
    return
  }

  let list = createElement("ul", className: "content-list")
  append(list, to: listView)

  var activeSlug: String?

  func showList() {
    clearElement(detailView)
    setHidden(detailView, true)
    setHidden(listView, false)
    activeSlug = nil
    setInnerText(shell.status, "\(count) item\(count == 1 ? "" : "s")")
  }

  func loadContentDetail(slug: String, updateHistory: Bool) {
    setInnerText(shell.status, "Loading…")

    let url = "\(config.detailPathPrefix)\(slug)"
    let promise = fetchURL(url)
    promise.then(success: { response in
      let jsonPromise = responseJSON(response)
      jsonPromise.then(success: { jsonValue in
        guard let body = jsonValue.object else {
          setInnerText(shell.status, "Detail response missing content")
          return .undefined
        }

        let root = body.root
        guard root.object != nil else {
          setInnerText(shell.status, "Detail response missing content")
          return .undefined
        }

        renderContentDetail(
          body: body,
          root: root,
          listView: listView,
          detailView: detailView
        )
        activeSlug = slug
        setInnerText(shell.status, "")

        if updateHistory {
          pushHistoryPath("\(config.historyPathPrefix)\(slug)")
        }
        return .undefined
      })
      jsonPromise.catch(failure: { _ in
        setInnerText(shell.status, "Failed to load article")
        return .undefined
      })
      return .undefined
    })
    promise.catch(failure: { _ in
      setInnerText(shell.status, "Failed to load article")
      return .undefined
    })
  }

  for index in 0..<count {
    guard let item = items[index].object,
      let slug = item.slug.string,
      let title = item.title.string
    else {
      continue
    }

    let listItem = createElement("li", className: "content-list-item")
    let button = createElement(
      "button",
      className: "content-list-link",
      innerText: title,
      attributes: ["type": "button"]
    )

    if let dateDisplay = item.dateDisplay.string, !dateDisplay.isEmpty {
      let meta = createElement("span", className: "content-list-date", innerText: dateDisplay)
      append(meta, to: listItem)
    }

    button.onclick = .object(
      JSClosure { _ -> JSValue in
        loadContentDetail(slug: slug, updateHistory: true)
        return .undefined
      }
    )

    append(button, to: listItem)
    append(listItem, to: list)
  }

  setInnerText(shell.status, "\(count) item\(count == 1 ? "" : "s")")

  _ = JSObject.global.window.addEventListener(
    "popstate",
    JSClosure { _ -> JSValue in
      let pathname = locationPathname()
      if let slug = contentSlug(from: pathname, config: config) {
        if slug != activeSlug {
          loadContentDetail(slug: slug, updateHistory: false)
        }
        return .undefined
      }

      if pathname == config.historyListPath, activeSlug != nil {
        showList()
      }
      return .undefined
    }
  )

  if let slug = contentSlug(from: locationPathname(), config: config) {
    loadContentDetail(slug: slug, updateHistory: false)
  }

  registerTabListResetHandler(for: config.historyListPath) {
    showList()
  }
}

private func contentSlug(from pathname: String, config: ContentBrowserConfig) -> String? {
  guard pathname.hasPrefix(config.historyPathPrefix) else { return nil }
  let slug = String(pathname.dropFirst(config.historyPathPrefix.count))
  guard !slug.isEmpty, !slug.contains("/") else { return nil }
  return slug
}

private func renderContentDetail(
  body: JSObject,
  root: JSValue,
  listView: JSValue,
  detailView: JSValue
) {
  clearElement(detailView)
  setHidden(detailView, false)
  setHidden(listView, true)

  if let title = body.title.string, !title.isEmpty {
    let heading = createElement("h1", className: "content-title", innerText: title)
    append(heading, to: detailView)
  }

  if let dateDisplay = body.dateDisplay.string, !dateDisplay.isEmpty {
    let meta = createElement("p", className: "content-meta", innerText: dateDisplay)
    append(meta, to: detailView)
  }

  let article = createElement("article", className: "article-content")
  setInnerHTML(article, renderMarkdownNode(root))
  append(article, to: detailView)
}
