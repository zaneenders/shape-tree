import JavaScriptKit
import ShapeTreeDOM

@JS struct SessionInfo {
  var authenticated: Bool
  var email: String?
  var demo: Bool
  var fit: Bool
  var article: Bool
}

func selectDemoTab(shell: AppShell) {
  setAttribute(shell.demoTab, "aria-selected", "true")
  setAttribute(shell.fitTab, "aria-selected", "false")
  setAttribute(shell.articleTab, "aria-selected", "false")
  setAttribute(shell.demoPanel, "aria-hidden", "false")
  setAttribute(shell.fitPanel, "aria-hidden", "true")
  setAttribute(shell.articlePanel, "aria-hidden", "true")
}

func selectFitTab(shell: AppShell) {
  setAttribute(shell.demoTab, "aria-selected", "false")
  setAttribute(shell.fitTab, "aria-selected", "true")
  setAttribute(shell.articleTab, "aria-selected", "false")
  setAttribute(shell.demoPanel, "aria-hidden", "true")
  setAttribute(shell.fitPanel, "aria-hidden", "false")
  setAttribute(shell.articlePanel, "aria-hidden", "true")
}

func selectArticleTab(shell: AppShell) {
  setAttribute(shell.demoTab, "aria-selected", "false")
  setAttribute(shell.fitTab, "aria-selected", "false")
  setAttribute(shell.articleTab, "aria-selected", "true")
  setAttribute(shell.demoPanel, "aria-hidden", "true")
  setAttribute(shell.fitPanel, "aria-hidden", "true")
  setAttribute(shell.articlePanel, "aria-hidden", "false")
}

func wireAppTabs(shell: AppShell) {
  var articleLoaded = false

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

  shell.articleTab.onclick = .object(
    JSClosure { _ -> JSValue in
      selectArticleTab(shell: shell)

      if !articleLoaded {
        articleLoaded = true
        loadArticleViewer()
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
    let jsonPromise = JSPromise(response.json().object!)!
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

func consumeSignedInQuery() -> Bool {
  let location = JSObject.global.location
  let search = location.search.string ?? ""
  guard queryParam("signed-in", in: search) == "1" else { return false }

  let pathname = location.pathname.string ?? "/"
  let cleaned = stripQueryParam("signed-in", from: search)
  _ = JSObject.global.history.replaceState(JSValue.null, "", pathname + cleaned)
  return true
}

private func signedOutSession() -> SessionInfo {
  SessionInfo(authenticated: false, email: nil, demo: true, fit: false, article: true)
}

private func queryParam(_ name: String, in search: String) -> String? {
  guard !search.isEmpty else { return nil }
  let query = search.hasPrefix("?") ? String(search.dropFirst()) : search
  for pair in query.split(separator: "&") {
    let parts = pair.split(separator: "=", maxSplits: 1)
    guard parts.count == 2, parts[0] == Substring(name) else { continue }
    return String(parts[1])
  }
  return nil
}

private func stripQueryParam(_ name: String, from search: String) -> String {
  guard !search.isEmpty else { return "" }
  let hadQuestion = search.hasPrefix("?")
  let query = hadQuestion ? String(search.dropFirst()) : search
  let kept = query.split(separator: "&").compactMap { pair -> String? in
    let parts = pair.split(separator: "=", maxSplits: 1)
    guard parts.count == 2, parts[0] != Substring(name) else { return nil }
    return String(pair)
  }
  if kept.isEmpty { return "" }
  return (hadQuestion ? "?" : "") + kept.joined(separator: "&")
}

private func applySessionTabs(shell: AppShell, session: SessionInfo, openFitIfSignedIn: Bool) {
  JSObject.global.window.appAuthenticated = .boolean(session.authenticated)
  setInnerText(shell.authButton, session.authenticated ? "Sign out" : "Sign in")

  setHidden(shell.demoTab, !session.demo)
  setHidden(shell.fitTab, !session.fit)
  setHidden(shell.articleTab, !session.article)

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
