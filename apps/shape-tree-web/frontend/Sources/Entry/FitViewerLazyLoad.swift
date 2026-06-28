import JavaScriptKit
import ShapeTreeDOM

func wireFitViewerLazyLoad(fitSection: JSValue) {
  let promise = fetchURL("/api/session")
  promise.then(success: { response in
    let jsonPromise = JSPromise(response.json().object!)!
    jsonPromise.then(success: { jsonValue in
      guard let body = jsonValue.object else {
        showFitSignInPrompt(fitSection: fitSection)
        return .undefined
      }
      let session = SessionInfo(unsafelyCopying: body)
      if session.authenticated {
        installFitViewerObserver(fitSection: fitSection)
      } else {
        showFitSignInPrompt(fitSection: fitSection)
      }
      return .undefined
    })
    jsonPromise.catch(failure: { _ in
      showFitSignInPrompt(fitSection: fitSection)
      return .undefined
    })
    return .undefined
  })
  promise.catch(failure: { _ in
    showFitSignInPrompt(fitSection: fitSection)
    return .undefined
  })
}

@JS struct SessionInfo {
  var authenticated: Bool
  var email: String?
}

private func showFitSignInPrompt(fitSection: JSValue) {
  guard let container = elementById("fit-container") else { return }
  setInnerHTML(container, "")

  let prompt = createElement(
    "p",
    className: "fit-auth-prompt",
    innerText: "Sign in to view your activity data."
  )
  append(prompt, to: container)

  let link = createElement("a", innerText: "Sign in", attributes: ["href": "/login?next=/"])
  append(link, to: container)
}

private func installFitViewerObserver(fitSection: JSValue) {
  let options = JSObject()
  options.rootMargin = .string("200px")

  let callback = JSClosure { arguments -> JSValue in
    guard let entries = arguments[0].object,
      let entry = entries[0].object,
      entry.isIntersecting.boolean == true
    else {
      return .undefined
    }

    if let observer = arguments[1].object {
      _ = observer.disconnect!()
    }

    loadFitViewer()
    return .undefined
  }

  let observer = JSObject.global.IntersectionObserver.object!.new(callback, options)
  _ = observer.observe!(fitSection)
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
