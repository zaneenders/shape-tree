import JavaScriptKit
import ShapeTreeDOM

extension FitViewState {
  mutating func renderRouteToImage() {
    guard canvasWidth >= 1, canvasHeight >= 1 else { return }

    let offscreen: JSValue
    if let existing = routeImage {
      offscreen = existing
    } else {
      offscreen = createElement("canvas")
    }
    offscreen.width = .number(canvasWidth)
    offscreen.height = .number(canvasHeight)
    guard let ctx = offscreen.getContext("2d").object else { return }
    let ctxVal = JSValue.object(ctx)

    _ = ctxVal.clearRect(0, 0, canvasWidth, canvasHeight)

    ctxVal.strokeStyle = .string("rgba(120, 150, 190, 0.08)")
    ctxVal.lineWidth = .number(1)
    let step = 48.0
    _ = ctxVal.beginPath()
    var x = 0.0
    while x <= canvasWidth {
      _ = ctxVal.moveTo(x, 0)
      _ = ctxVal.lineTo(x, canvasHeight)
      x += step
    }
    var y = 0.0
    while y <= canvasHeight {
      _ = ctxVal.moveTo(0, y)
      _ = ctxVal.lineTo(canvasWidth, y)
      y += step
    }
    _ = ctxVal.stroke()

    if let summary {
      let altitudes = summary.points.compactMap { $0.altitudeMeters }
      if altitudes.count > 2,
        let minAlt = altitudes.min(),
        let maxAlt = altitudes.max(),
        maxAlt > minAlt
      {
        let ribbonHeight = 36.0
        let baseY = canvasHeight - ribbonHeight - 14
        let stepW = canvasWidth / Double(altitudes.count - 1)
        for index in 1..<altitudes.count {
          let t = (altitudes[index] - minAlt) / (maxAlt - minAlt)
          let barHeight = 6 + t * (ribbonHeight - 8)
          let barX = Double(index - 1) * stepW
          ctxVal.fillStyle = .string(
            "hsla(" + jsNumber(205 - t * 70, decimals: 0) + ", 70%, 58%, 0.55)")
          _ = ctxVal.fillRect(barX, baseY + ribbonHeight - barHeight, stepW + 1, barHeight)
        }
      }
    }

    guard screenPoints.count > 1 else {
      routeImage = offscreen
      routeImageDirty = false
      return
    }

    ctxVal.lineCap = .string("round")
    ctxVal.lineJoin = .string("round")

    for index in 1..<screenPoints.count {
      let prev = screenPoints[index - 1]
      let curr = screenPoints[index]
      ctxVal.strokeStyle = .string("hsla(" + jsNumber(curr.hue, decimals: 0) + ", 88%, 58%, 0.92)")
      ctxVal.lineWidth = .number(4.5)
      _ = ctxVal.beginPath()
      _ = ctxVal.moveTo(prev.x, prev.y)
      _ = ctxVal.lineTo(curr.x, curr.y)
      _ = ctxVal.stroke()
    }

    ctxVal.globalCompositeOperation = .string("lighter")
    ctxVal.lineWidth = .number(10)

    for index in 1..<screenPoints.count {
      let prev = screenPoints[index - 1]
      let curr = screenPoints[index]
      ctxVal.strokeStyle = .string("hsla(" + jsNumber(curr.hue, decimals: 0) + ", 90%, 62%, 0.12)")
      _ = ctxVal.beginPath()
      _ = ctxVal.moveTo(prev.x, prev.y)
      _ = ctxVal.lineTo(curr.x, curr.y)
      _ = ctxVal.stroke()
    }
    ctxVal.globalCompositeOperation = .string("source-over")

    if let first = screenPoints.first {
      _ = ctxVal.beginPath()
      _ = ctxVal.arc(first.x, first.y, 7, 0, jsPi * 2)
      ctxVal.fillStyle = .string("rgba(120, 255, 180, 0.95)")
      _ = ctxVal.fill()
    }
    if let last = screenPoints.last {
      _ = ctxVal.beginPath()
      _ = ctxVal.arc(last.x, last.y, 7, 0, jsPi * 2)
      ctxVal.fillStyle = .string("rgba(255, 120, 120, 0.95)")
      _ = ctxVal.fill()
    }

    routeImage = offscreen
    routeImageDirty = false
  }
}
