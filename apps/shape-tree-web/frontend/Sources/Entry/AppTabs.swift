import JavaScriptKit
import ShapeTreeDOM

func selectDemoTab(shell: AppShell) {
  setAttribute(shell.demoTab, "aria-selected", "true")
  setAttribute(shell.fitTab, "aria-selected", "false")
  setAttribute(shell.articlesTab, "aria-selected", "false")
  setAttribute(shell.favoritesTab, "aria-selected", "false")
  setAttribute(shell.demoPanel, "aria-hidden", "false")
  setAttribute(shell.fitPanel, "aria-hidden", "true")
  setAttribute(shell.articlesPanel, "aria-hidden", "true")
  setAttribute(shell.favoritesPanel, "aria-hidden", "true")
}

func selectFitTab(shell: AppShell) {
  setAttribute(shell.demoTab, "aria-selected", "false")
  setAttribute(shell.fitTab, "aria-selected", "true")
  setAttribute(shell.articlesTab, "aria-selected", "false")
  setAttribute(shell.favoritesTab, "aria-selected", "false")
  setAttribute(shell.demoPanel, "aria-hidden", "true")
  setAttribute(shell.fitPanel, "aria-hidden", "false")
  setAttribute(shell.articlesPanel, "aria-hidden", "true")
  setAttribute(shell.favoritesPanel, "aria-hidden", "true")
}

func selectArticlesTab(shell: AppShell) {
  setAttribute(shell.demoTab, "aria-selected", "false")
  setAttribute(shell.fitTab, "aria-selected", "false")
  setAttribute(shell.articlesTab, "aria-selected", "true")
  setAttribute(shell.favoritesTab, "aria-selected", "false")
  setAttribute(shell.demoPanel, "aria-hidden", "true")
  setAttribute(shell.fitPanel, "aria-hidden", "true")
  setAttribute(shell.articlesPanel, "aria-hidden", "false")
  setAttribute(shell.favoritesPanel, "aria-hidden", "true")
}

func selectFavoritesTab(shell: AppShell) {
  setAttribute(shell.demoTab, "aria-selected", "false")
  setAttribute(shell.fitTab, "aria-selected", "false")
  setAttribute(shell.articlesTab, "aria-selected", "false")
  setAttribute(shell.favoritesTab, "aria-selected", "true")
  setAttribute(shell.demoPanel, "aria-hidden", "true")
  setAttribute(shell.fitPanel, "aria-hidden", "true")
  setAttribute(shell.articlesPanel, "aria-hidden", "true")
  setAttribute(shell.favoritesPanel, "aria-hidden", "false")
}

func wireAppTabs(shell: AppShell) {
  var articlesLoaded = false
  var favoritesLoaded = false

  shell.demoTab.onclick = .object(
    JSClosure { _ -> JSValue in
      navigateToHome(shell: shell)
      return .undefined
    }
  )

  shell.fitTab.onclick = .object(
    JSClosure { _ -> JSValue in
      guard JSObject.global.window.appAuthenticated.boolean == true else {
        return .undefined
      }
      selectFitTab(shell: shell)
      loadFitViewerOnce()
      return .undefined
    }
  )

  shell.articlesTab.onclick = .object(
    JSClosure { _ -> JSValue in
      selectArticlesTab(shell: shell)

      if !articlesLoaded {
        articlesLoaded = true
        loadArticlesViewer()
      }

      return .undefined
    }
  )

  shell.favoritesTab.onclick = .object(
    JSClosure { _ -> JSValue in
      selectFavoritesTab(shell: shell)

      if !favoritesLoaded {
        favoritesLoaded = true
        loadFavoritesViewer()
      }

      return .undefined
    }
  )

  shell.authButton.onclick = .object(
    JSClosure { _ -> JSValue in
      if JSObject.global.window.appAuthenticated.boolean == true {
        signOut(shell: shell)
      } else {
        navigateToLogin(shell: shell)
      }
      return .undefined
    }
  )
}

func refreshSessionTabs(shell: AppShell, openFitIfSignedIn: Bool = false) {
  let promise = fetchURL("/api/session")
  promise.then(success: { response in
    let jsonPromise = responseJSON(response)
    jsonPromise.then(success: { jsonValue in
      guard let body = jsonValue.object else {
        applySessionTabs(shell: shell, session: signedOutSession(), openFitIfSignedIn: false)
        return .undefined
      }
      let session = SessionInfo(unsafelyCopying: body)
      applySessionTabs(shell: shell, session: session, openFitIfSignedIn: openFitIfSignedIn)
      return .undefined
    })
    jsonPromise.catch(failure: { _ in
      applySessionTabs(shell: shell, session: signedOutSession(), openFitIfSignedIn: false)
      return .undefined
    })
    return .undefined
  })
  promise.catch(failure: { _ in
    applySessionTabs(shell: shell, session: signedOutSession(), openFitIfSignedIn: false)
    return .undefined
  })
}

private func signedOutSession() -> SessionInfo {
  SessionInfo(authenticated: false, email: nil, demo: true, fit: false, articles: false, favorites: false)
}

private func applySessionTabs(shell: AppShell, session: SessionInfo, openFitIfSignedIn: Bool) {
  let onAuthFlow = JSObject.global.window.onAuthFlowRoute.boolean == true
  let displaySession = onAuthFlow ? signedOutSession() : session

  JSObject.global.window.appAuthenticated = .boolean(displaySession.authenticated)
  setInnerText(shell.authButton, displaySession.authenticated ? "Sign out" : "Sign in")

  setHidden(shell.demoTab, !displaySession.demo)
  setHidden(shell.fitTab, !displaySession.fit)
  setHidden(shell.articlesTab, !displaySession.articles)
  setHidden(shell.favoritesTab, !displaySession.favorites)

  if !session.fit && isPanelVisible(shell.fitPanel) {
    navigateToHome(shell: shell)
  }

  if openFitIfSignedIn && session.authenticated && session.fit {
    selectFitTab(shell: shell)
    loadFitViewerOnce()
  }
}

func signOut(shell: AppShell) {
  let promise = postURL("/auth/logout")
  promise.then(success: { _ in
    teardownFitViewerIfLoaded()
    JSObject.global.window.fitViewerLoaded = .boolean(false)
    if let container = elementById("fit-container") {
      clearElement(container)
    }
    refreshSessionTabs(shell: shell)
    navigateToHome(shell: shell)
    return .undefined
  })
  promise.catch(failure: { _ in .undefined })
}

private func isPanelVisible(_ panel: JSValue) -> Bool {
  panel.object?.ariaHidden.string == "false"
}

private func loadFitViewerOnce() {
  let window = JSObject.global.window
  if window.fitViewerLoaded.boolean == true { return }
  window.fitViewerLoaded = .boolean(true)
  loadFitViewer()
}

private func loadFitViewer() {
  guard let container = elementById("fit-container") else { return }

  let promise = dynamicImport("/fit-viewer-bootstrap.js")
  promise.then(success: { moduleValue in
    guard let module = moduleValue.object,
      let mountFitViewer = module.mountFitViewer.function
    else {
      return .undefined
    }
    _ = mountFitViewer(container)
    return .undefined
  })
  promise.catch(failure: { _ in .undefined })
}

private func teardownFitViewerIfLoaded() {
  let promise = dynamicImport("/fit-viewer-bootstrap.js")
  promise.then(success: { moduleValue in
    guard let teardown = moduleValue.object?.teardownFitViewer.function else {
      return .undefined
    }
    teardown()
    return .undefined
  })
  promise.catch(failure: { _ in .undefined })
}

private func loadArticlesViewer() {
  guard let container = elementById("articles-container") else { return }

  let promise = dynamicImport("/articles-viewer-bootstrap.js")
  promise.then(success: { moduleValue in
    guard let module = moduleValue.object,
      let mountArticlesViewer = module.mountArticlesViewer.function
    else {
      return .undefined
    }
    _ = mountArticlesViewer(container)
    return .undefined
  })
  promise.catch(failure: { _ in .undefined })
}

private func loadFavoritesViewer() {
  guard let container = elementById("favorites-container") else { return }

  let promise = dynamicImport("/favorites-viewer-bootstrap.js")
  promise.then(success: { moduleValue in
    guard let module = moduleValue.object,
      let mountFavoritesViewer = module.mountFavoritesViewer.function
    else {
      return .undefined
    }
    _ = mountFavoritesViewer(container)
    return .undefined
  })
  promise.catch(failure: { _ in .undefined })
}
