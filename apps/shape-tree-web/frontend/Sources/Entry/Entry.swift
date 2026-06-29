import JavaScriptKit
import ShapeTreeDOM

@JS public func bootstrap() {
  installEventLoop()
}

@JS public func renderApp() {
  let app = createElement("div", id: "app")
  append(app, to: documentBody())

  let appHeader = createElement("div", className: "app-header")
  append(appHeader, to: app)

  let heading = createElement("h1", innerText: "ShapeTree · Swift WASM Demo")
  append(heading, to: appHeader)

  let authButton = createElement(
    "button",
    className: "auth-button",
    id: "auth-button",
    innerText: "Sign in",
    attributes: ["type": "button"]
  )
  append(authButton, to: appHeader)

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

  let fitTab = createElement(
    "button",
    className: "tab",
    id: "fit-tab",
    innerText: "Fit",
    attributes: [
      "role": "tab",
      "aria-selected": "false",
      "aria-controls": "fit-panel",
      "hidden": "true",
    ]
  )
  append(fitTab, to: tabBar)

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

  let routeOutlet = createElement("div", id: "route-outlet")
  append(routeOutlet, to: demoPanel)

  let fitPanel = createElement(
    "div",
    className: "tab-panel",
    id: "fit-panel",
    attributes: [
      "role": "tabpanel",
      "aria-labelledby": "fit-tab",
      "aria-hidden": "true",
    ]
  )
  append(fitPanel, to: tabPanels)

  let fitContainer = createElement("div", id: "fit-container")
  append(fitContainer, to: fitPanel)

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

  let shell = AppShell(
    routeOutlet: routeOutlet,
    demoTab: demoTab,
    fitTab: fitTab,
    articleTab: articleTab,
    authButton: authButton,
    demoPanel: demoPanel,
    fitPanel: fitPanel,
    articlePanel: articlePanel
  )
  setHidden(fitTab, true)
  JSObject.global.window.appAuthenticated = .boolean(false)
  JSObject.global.window.onAuthFlowRoute = .boolean(false)
  renderInitialView(shell: shell)
  wireClientRouter(shell: shell)

  wireAppTabs(shell: shell)
  refreshSessionTabs(shell: shell, openFitIfSignedIn: false)
}
