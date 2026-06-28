import JavaScriptEventLoop
import JavaScriptKit
import ShapeTreeDOM

@JS public func bootstrap() {
  JavaScriptEventLoop.installGlobalExecutor()
}

@JS public func renderApp() {
  let app = createElement("div", id: "app")
  append(app, to: documentBody())

  let heading = createElement("h1", innerText: "ShapeTree · Swift WASM Demo")
  append(heading, to: app)

  let tabBar = createElement("nav", className: "tab-bar", attributes: ["role": "tablist"])
  append(tabBar, to: app)

  let demoTab = createElement(
    "button",
    className: "tab",
    id: "demo-tab",
    innerText: "Demo",
    attributes: [
      "role": "tab",
      "aria-selected": "true",
      "aria-controls": "demo-panel",
    ]
  )
  append(demoTab, to: tabBar)

  let articleTab = createElement(
    "button",
    className: "tab",
    id: "article-tab",
    innerText: "Article",
    attributes: [
      "role": "tab",
      "aria-selected": "false",
      "aria-controls": "article-panel",
    ]
  )
  append(articleTab, to: tabBar)

  let tabPanels = createElement("div", className: "tab-panels")
  append(tabPanels, to: app)

  let demoPanel = createElement(
    "div",
    className: "tab-panel",
    id: "demo-panel",
    attributes: [
      "role": "tabpanel",
      "aria-labelledby": "demo-tab",
      "aria-hidden": "false",
    ]
  )
  append(demoPanel, to: tabPanels)

  let serverSection = createElement("section", id: "server-section")
  append(serverSection, to: demoPanel)

  let serverHeading = createElement("h2", innerText: "Server Message")
  append(serverHeading, to: serverSection)

  let serverStatus = createElement(
    "p",
    className: "status",
    id: "server-status",
    innerText: "Press the button to fetch a message…"
  )
  append(serverStatus, to: serverSection)

  let fetchButton = createElement("button", id: "fetch-button", innerText: "Fetch Message")
  append(fetchButton, to: serverSection)

  fetchButton.onclick = .object(
    JSClosure { _ -> JSValue in
      fetchServerMessage(status: serverStatus)
      return JSValue.undefined
    }
  )

  let fitSection = createElement("section", id: "fit-section")
  append(fitSection, to: demoPanel)

  let fitHeading = createElement("h2", innerText: "FIT Activity Viewer")
  append(fitHeading, to: fitSection)

  let fitContainer = createElement("div", id: "fit-container")
  append(fitContainer, to: fitSection)

  wireFitViewerLazyLoad(fitSection: fitSection)

  let articlePanel = createElement(
    "div",
    className: "tab-panel",
    id: "article-panel",
    attributes: [
      "role": "tabpanel",
      "aria-labelledby": "article-tab",
      "aria-hidden": "true",
    ]
  )
  append(articlePanel, to: tabPanels)

  let articleContainer = createElement("div", id: "article-container")
  append(articleContainer, to: articlePanel)

  wireArticleTab(
    articleTab: articleTab,
    demoTab: demoTab,
    articlePanel: articlePanel,
    demoPanel: demoPanel
  )
}

private func fetchServerMessage(status: JSValue) {
  setInnerText(status, "Loading…")

  let promise = fetchURL("/api/message")
  promise.then(success: { response in
    let jsonPromise = JSPromise(response.json().object!)!
    jsonPromise.then(success: { jsonValue in
      if let body = jsonValue.object {
        let decoded = ServerMessage(unsafelyCopying: body)
        setInnerText(
          status,
          decoded.message + " — " + decoded.server
        )
      } else {
        setInnerText(status, "Failed to fetch message")
      }
      return JSValue.undefined
    })
    jsonPromise.catch(failure: { _ in
      setInnerText(status, "Failed to fetch message")
      return JSValue.undefined
    })
    return JSValue.undefined
  })
  promise.catch(failure: { _ in
    setInnerText(status, "Failed to fetch message")
    return JSValue.undefined
  })
}

@JS struct ServerMessage {
  var message: String
  var server: String
}
