import JavaScriptKit
import ShapeTreeDOM

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
