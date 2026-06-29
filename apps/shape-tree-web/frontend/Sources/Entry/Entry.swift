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

func renderDemoContent(into demoPanel: JSValue) {
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
}

func renderAuthView(into container: JSValue, props: PageProps, shell: AppShell) {
  let main = createElement("main", className: "auth-page")
  append(main, to: container)

  switch props.page {
  case "login":
    let heading = createElement("h1", innerText: "Sign in")
    append(heading, to: main)

    let blurb = createElement(
      "p",
      innerText: "Enter your email and we will send you a one-time sign-in link."
    )
    append(blurb, to: main)

    let form = createElement("form", className: "auth-form")
    append(form, to: main)

    let emailLabel = createElement("label", innerText: "Email")
    append(emailLabel, to: form)

    let emailInput = createElement(
      "input",
      attributes: [
        "type": "email",
        "name": "email",
        "required": "true",
        "autocomplete": "email",
      ]
    )
    append(emailInput, to: emailLabel)

    let nextInput = createElement(
      "input",
      attributes: ["type": "hidden", "name": "next", "value": props.next]
    )
    append(nextInput, to: form)

    let status = createElement("p", className: "status", id: "login-status")
    append(status, to: form)

    let submitButton = createElement(
      "button",
      innerText: "Send sign-in link",
      attributes: ["type": "submit"]
    )
    append(submitButton, to: form)

    form.onsubmit = .object(
      JSClosure { arguments -> JSValue in
        if let event = arguments[0].object {
          _ = event.preventDefault!()
        }
        submitLoginForm(
          emailInput: emailInput,
          next: props.next,
          status: status,
          submitButton: submitButton,
          shell: shell
        )
        return .undefined
      }
    )

  case "check-email":
    let heading = createElement("h1", innerText: "Check your email")
    append(heading, to: main)

    let p1 = createElement(
      "p",
      innerText:
        "If an account exists for that address, we sent a sign-in link. The link expires soon and works once."
    )
    append(p1, to: main)

    append(createSpaLink(shell: shell, route: .login(next: "/"), text: "Back to sign in"), to: main)

  case "verify":
    if !props.token.isEmpty {
      let heading = createElement("h1", innerText: "Confirm sign in")
      append(heading, to: main)

      let blurb = createElement("p", innerText: "Click continue to finish signing in.")
      append(blurb, to: main)

      let form = createElement("form", className: "auth-form")
      append(form, to: main)

      let status = createElement("p", className: "status", id: "verify-status")
      append(status, to: form)

      let submitButton = createElement(
        "button",
        innerText: "Continue",
        attributes: ["type": "submit"]
      )
      append(submitButton, to: form)

      form.onsubmit = .object(
        JSClosure { arguments -> JSValue in
          if let event = arguments[0].object {
            _ = event.preventDefault!()
          }
          submitVerifyForm(
            token: props.token,
            next: props.next,
            status: status,
            submitButton: submitButton,
            shell: shell
          )
          return .undefined
        }
      )
    } else {
      let heading = createElement("h1", innerText: "Sign-in link invalid")
      append(heading, to: main)

      let blurb = createElement(
        "p",
        innerText: "This link is missing, expired, or already used."
      )
      append(blurb, to: main)

      append(createSpaLink(shell: shell, route: .login(next: "/"), text: "Request a new sign-in link"), to: main)
    }

  default:
    break
  }
}

private func createSpaLink(shell: AppShell, route: ClientRoute, text: String) -> JSValue {
  let button = createElement(
    "button",
    className: "text-link",
    innerText: text,
    attributes: ["type": "button"]
  )
  button.onclick = .object(
    JSClosure { _ -> JSValue in
      switch route {
      case .home:
        navigateToHome(shell: shell)
      case .login(let next):
        navigateToLogin(shell: shell, next: next)
      case .checkEmail:
        navigateToCheckEmail(shell: shell)
      case .verify:
        navigateToVerify(shell: shell)
      }
      return .undefined
    }
  )
  return button
}

private func submitLoginForm(
  emailInput: JSValue,
  next: String,
  status: JSValue,
  submitButton: JSValue,
  shell: AppShell
) {
  guard let email = emailInput.value.string, !email.isEmpty else { return }
  let body = "email=\(formURLEncode(email))&next=\(formURLEncode(next))"

  setInnerText(status, "Sending…")
  submitButton.disabled = .boolean(true)

  let promise = postFormURL("/auth/login", body: body)
  promise.then(success: { response in
    if response.ok.boolean == true {
      navigateToCheckEmail(shell: shell)
    } else {
      setInnerText(status, "Something went wrong. Try again.")
      submitButton.disabled = .boolean(false)
    }
    return JSValue.undefined
  })
  promise.catch(failure: { _ in
    setInnerText(status, "Something went wrong. Try again.")
    submitButton.disabled = .boolean(false)
    return JSValue.undefined
  })
}

private func submitVerifyForm(
  token: String,
  next: String,
  status: JSValue,
  submitButton: JSValue,
  shell: AppShell
) {
  let body = "token=\(formURLEncode(token))&next=\(formURLEncode(next))"

  setInnerText(status, "Signing in…")
  submitButton.disabled = .boolean(true)

  let promise = postFormURL("/auth/verify", body: body)
  promise.then(success: { response in
    let jsonPromise = responseJSON(response)
    jsonPromise.then(success: { jsonValue in
      guard let body = jsonValue.object else {
        setInnerText(status, "Something went wrong. Try again.")
        submitButton.disabled = .boolean(false)
        return JSValue.undefined
      }
      let result = VerifyResponse(unsafelyCopying: body)
      if result.ok {
        refreshSessionTabs(shell: shell, openFitIfSignedIn: true)
        navigateAfterSignIn(shell: shell, next: result.next ?? "/")
      } else {
        navigateToVerify(shell: shell)
      }
      return JSValue.undefined
    })
    jsonPromise.catch(failure: { _ in
      setInnerText(status, "Something went wrong. Try again.")
      submitButton.disabled = .boolean(false)
      return JSValue.undefined
    })
    return JSValue.undefined
  })
  promise.catch(failure: { _ in
    setInnerText(status, "Something went wrong. Try again.")
    submitButton.disabled = .boolean(false)
    return JSValue.undefined
  })
}

@JS struct VerifyResponse {
  var ok: Bool
  var next: String?
}

@JS struct PageProps {
  var page: String
  var next: String
  var token: String
}

private func fetchServerMessage(status: JSValue) {
  setInnerText(status, "Loading…")

  let promise = fetchURL("/api/message")
  promise.then(success: { response in
    let jsonPromise = responseJSON(response)
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
