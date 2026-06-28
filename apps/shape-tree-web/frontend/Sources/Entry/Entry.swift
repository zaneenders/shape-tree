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

  // The server renders an auth view by embedding `entry-page-props` JSON.
  // When present, the auth form replaces the default demo content but the
  // nav shell above (heading + tabs) stays visible through the login flow.
  if let props = readPageProps(), !props.page.isEmpty {
    renderAuthView(into: demoPanel, props: props)
    demoTab.innerText = .string("Sign in")
  } else {
    renderDemoContent(into: demoPanel)
  }

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

private func renderDemoContent(into demoPanel: JSValue) {
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
}

private func readPageProps() -> PageProps? {
  let document = JSObject.global.document
  guard let script = document.getElementById("entry-page-props").object else { return nil }
  guard let raw = script.textContent.string, !raw.isEmpty else { return nil }
  guard let parsed = JSObject.global.JSON.parse(JSValue.string(raw)).object else { return nil }
  return PageProps(unsafelyCopying: parsed)
}

private func renderAuthView(into container: JSValue, props: PageProps) {
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

    let form = createElement(
      "form",
      className: "auth-form",
      attributes: ["method": "POST", "action": "/auth/login"]
    )
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

    append(
      createElement("input", attributes: ["type": "hidden", "name": "next", "value": props.next]),
      to: form
    )
    append(
      createElement("button", innerText: "Send sign-in link", attributes: ["type": "submit"]),
      to: form
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

    append(createLink(href: "/login", text: "Back to sign in"), to: main)

  case "verify":
    if !props.token.isEmpty {
      let heading = createElement("h1", innerText: "Confirm sign in")
      append(heading, to: main)

      let blurb = createElement("p", innerText: "Click continue to finish signing in.")
      append(blurb, to: main)

      let form = createElement(
        "form",
        className: "auth-form",
        attributes: ["method": "POST", "action": "/auth/verify"]
      )
      append(form, to: main)

      append(
        createElement("input", attributes: ["type": "hidden", "name": "token", "value": props.token]),
        to: form
      )
      append(
        createElement("input", attributes: ["type": "hidden", "name": "next", "value": props.next]),
        to: form
      )
      append(
        createElement("button", innerText: "Continue", attributes: ["type": "submit"]),
        to: form
      )
    } else {
      let heading = createElement("h1", innerText: "Sign-in link invalid")
      append(heading, to: main)

      let blurb = createElement(
        "p",
        innerText: "This link is missing, expired, or already used."
      )
      append(blurb, to: main)

      append(createLink(href: "/login", text: "Request a new sign-in link"), to: main)
    }

  default:
    break
  }
}

private func createLink(href: String, text: String) -> JSValue {
  createElement("a", innerText: text, attributes: ["href": href])
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
