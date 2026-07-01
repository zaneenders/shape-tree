import JavaScriptKit

func resizeCanvas(canvas: JSValue, stage: JSValue) {
  let dpr = JSObject.global.devicePixelRatio.number ?? 1
  let cssWidth = jsMax(stage.clientWidth.number ?? 640, 1)
  let maxHeight = jsWindowInnerHeight() * 0.58
  let cssHeight = jsMin(jsMax(cssWidth * 0.58, 260), maxHeight)

  fitViewState.canvasWidth = cssWidth
  fitViewState.canvasHeight = cssHeight

  canvas.style.width = .string(jsPx(cssWidth))
  canvas.style.height = .string(jsPx(cssHeight))
  canvas.width = .number(cssWidth * dpr)
  canvas.height = .number(cssHeight * dpr)

  let context = canvas.getContext("2d")
  _ = context.setTransform(dpr, 0, 0, dpr, 0, 0)

  fitViewState.projectTrackToCanvas()
}

func wireResize(canvas: JSValue, stage: JSValue) {
  let onResize = JSClosure { _ -> JSValue in
    resizeCanvas(canvas: canvas, stage: stage)
    return JSValue.undefined
  }

  _ = JSObject.global.addEventListener!("resize", onResize)

  let observer = JSObject.global.ResizeObserver.object!.new(onResize)
  _ = observer.observe!(stage)
}

func canvasPoint(from event: JSValue, canvas: JSValue) -> (x: Double, y: Double)? {
  let rect = canvas.getBoundingClientRect()
  if let width = rect.width.number, let height = rect.height.number, width > 0, height > 0 {
    let left = rect.left.number ?? 0
    let top = rect.top.number ?? 0
    let clientX = event.clientX.number ?? 0
    let clientY = event.clientY.number ?? 0
    return (
      (clientX - left) * fitViewState.canvasWidth / width,
      (clientY - top) * fitViewState.canvasHeight / height
    )
  }
  return nil
}

func wireCanvasEvents(canvas: JSValue) {
  canvas.onpointermove = .object(
    JSClosure { arguments in
      if let point = canvasPoint(from: arguments[0], canvas: canvas) {
        fitViewState.hoverIndex = fitViewState.nearestPointIndex(x: point.x, y: point.y)
      }
      return JSValue.undefined
    }
  )

  canvas.onpointerleave = .object(
    JSClosure { _ in
      fitViewState.hoverIndex = nil
      return JSValue.undefined
    }
  )

  canvas.tabIndex = .number(0)
}

func stopDrawLoop() {
  fitViewState.drawStep = nil
}

func startDrawLoop(canvas: JSValue) {
  stopDrawLoop()
  let context = canvas.getContext("2d")
  fitViewState.drawStep = JSClosure { _ -> JSValue in
    guard fitViewState.drawStep != nil else { return JSValue.undefined }
    fitViewState.stepPlayback()
    fitViewState.drawFrame(context: context)

    if let drawStep = fitViewState.drawStep {
      _ = JSObject.global.requestAnimationFrame!(drawStep)
    }
    return JSValue.undefined
  }
  _ = fitViewState.drawStep?(JSValue.undefined)
}
