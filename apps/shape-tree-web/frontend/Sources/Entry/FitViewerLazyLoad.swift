import JavaScriptKit
import ShapeTreeDOM

func wireFitViewerLazyLoad(fitSection: JSValue) {
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
