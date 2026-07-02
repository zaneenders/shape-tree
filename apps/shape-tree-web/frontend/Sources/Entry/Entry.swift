import JavaScriptKit
import ShapeTreeDOM

@JS public func bootstrap() {
  installEventLoop()
}

@JS public func renderApp() {
  let app = createElement("div", id: "app")
  append(app, to: documentBody())

  let appHeader = createElement("header", className: "app-header")
  append(appHeader, to: app)

  let brand = createElement("div", className: "app-brand")
  append(brand, to: appHeader)

  let heading = createElement("h1", innerText: "ShapeTree")
  append(heading, to: brand)


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

  let articlesTab = createElement(
    "button",
    className: "tab",
    id: "articles-tab",
    innerText: "Articles",
    attributes: [
      "role": "tab",
      "aria-selected": "false",
      "aria-controls": "articles-panel",
      "hidden": "true",
    ]
  )
  append(articlesTab, to: tabBar)

  let favoritesTab = createElement(
    "button",
    className: "tab",
    id: "favorites-tab",
    innerText: "Favorites",
    attributes: [
      "role": "tab",
      "aria-selected": "false",
      "aria-controls": "favorites-panel",
      "hidden": "true",
    ]
  )
  append(favoritesTab, to: tabBar)

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

  let articlesPanel = createElement(
    "div",
    className: "tab-panel",
    id: "articles-panel",
    attributes: [
      "role": "tabpanel",
      "aria-labelledby": "articles-tab",
      "aria-hidden": "true",
    ]
  )
  append(articlesPanel, to: tabPanels)

  let articlesContainer = createElement("div", id: "articles-container")
  append(articlesContainer, to: articlesPanel)

  let favoritesPanel = createElement(
    "div",
    className: "tab-panel",
    id: "favorites-panel",
    attributes: [
      "role": "tabpanel",
      "aria-labelledby": "favorites-tab",
      "aria-hidden": "true",
    ]
  )
  append(favoritesPanel, to: tabPanels)

  let favoritesContainer = createElement("div", id: "favorites-container")
  append(favoritesContainer, to: favoritesPanel)

  let shell = AppShell(
    routeOutlet: routeOutlet,
    demoTab: demoTab,
    fitTab: fitTab,
    articlesTab: articlesTab,
    favoritesTab: favoritesTab,
    authButton: authButton,
    demoPanel: demoPanel,
    fitPanel: fitPanel,
    articlesPanel: articlesPanel,
    favoritesPanel: favoritesPanel
  )
  setHidden(fitTab, true)
  setHidden(articlesTab, true)
  setHidden(favoritesTab, true)
  JSObject.global.window.appAuthenticated = .boolean(false)
  JSObject.global.window.onAuthFlowRoute = .boolean(false)
  JSObject.global.window.articlesViewerLoaded = .boolean(false)
  JSObject.global.window.favoritesViewerLoaded = .boolean(false)
  renderInitialView(shell: shell)
  wireClientRouter(shell: shell)

  wireAppTabs(shell: shell)
  refreshSessionTabs(shell: shell, openFitIfSignedIn: false)
}
