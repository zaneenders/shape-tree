import JavaScriptKit

func resizeCanvas(canvas: JSValue, stage: JSValue) {
  let dpr = JSObject.global.devicePixelRatio.number ?? 1
  let cssWidth = stage.clientWidth.number ?? 640
  let maxHeight = jsWindowInnerHeight() * 0.58
  let cssHeight = jsMin(jsMax(cssWidth * 0.58, 260), maxHeight)

  canvasWidth = cssWidth
  canvasHeight = cssHeight

  canvas.style.width = .string(jsPx(cssWidth))
  canvas.style.height = .string(jsPx(cssHeight))
  canvas.width = .number(cssWidth * dpr)
  canvas.height = .number(cssHeight * dpr)

  let context = canvas.getContext("2d")
  _ = context.setTransform(dpr, 0, 0, dpr, 0, 0)

  projectFitTrackToCanvas()
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
      (clientX - left) * canvasWidth / width,
      (clientY - top) * canvasHeight / height
    )
  }
  return nil
}

func wireCanvasEvents(canvas: JSValue) {
  canvas.onpointermove = .object(
    JSClosure { arguments in
      if let point = canvasPoint(from: arguments[0], canvas: canvas) {
        mouseX = point.x
        mouseY = point.y
        pointerInside = true
        fitHoverIndex = nearestFitPointIndex(x: point.x, y: point.y)
      }
      return JSValue.undefined
    }
  )

  canvas.onpointerleave = .object(
    JSClosure { _ in
      pointerInside = false
      fitHoverIndex = nil
      return JSValue.undefined
    }
  )

  canvas.tabIndex = .number(0)
}

func startDrawLoop(canvas: JSValue) {
  let context = canvas.getContext("2d")
  drawStep = JSClosure { _ -> JSValue in
    frame += 1
    stepFitPlayback()
    drawFitFrame(context: context)

    if let drawStep {
      _ = JSObject.global.requestAnimationFrame!(drawStep)
    }
    return JSValue.undefined
  }
  _ = drawStep?(JSValue.undefined)
}
