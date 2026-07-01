import JavaScriptKit

extension FitViewState {
  mutating func drawFrame(context: JSValue) {
    guard canvasWidth >= 1, canvasHeight >= 1 else { return }

    context.fillStyle = .string("#070b12")
    _ = context.fillRect(0, 0, canvasWidth, canvasHeight)

    if routeImageDirty { renderRouteToImage() }
    if let img = routeImage, canvasWidth >= 1, canvasHeight >= 1 {
      _ = context.drawImage(img, 0, 0)
    }

    drawPlaybackMarker(context: context)
    drawHoverMarker(context: context)
    drawHUD(context: context)
  }

  private func drawPlaybackMarker(context: JSValue) {
    guard screenPoints.count > 1 else { return }
    let index = Int(playbackIndex)
    let fraction = playbackIndex - Double(index)
    let nextIndex = min(Double(screenPoints.count - 1), playbackIndex + 1)
    let current = screenPoints[index]
    let next = screenPoints[Int(nextIndex)]
    let x = current.x + (next.x - current.x) * fraction
    let y = current.y + (next.y - current.y) * fraction
    let heartRate = next.heartRate ?? current.heartRate

    _ = context.beginPath()
    _ = context.arc(x, y, 18, 0, jsPi * 2)
    context.fillStyle = .string("hsla(" + jsNumber(heartRateHue(heartRate), decimals: 0) + ", 90%, 60%, 0.18)")
    _ = context.fill()

    _ = context.beginPath()
    _ = context.arc(x, y, 6, 0, jsPi * 2)
    context.fillStyle = .string("rgba(255, 255, 255, 0.95)")
    _ = context.fill()
  }

  private func drawHoverMarker(context: JSValue) {
    guard let index = hoverIndex, screenPoints.indices.contains(index) else { return }
    let point = screenPoints[index]
    _ = context.beginPath()
    _ = context.arc(point.x, point.y, 11, 0, jsPi * 2)
    context.strokeStyle = .string("rgba(255, 255, 255, 0.85)")
    context.lineWidth = .number(2)
    _ = context.stroke()
  }

  private func drawHUD(context: JSValue) {
    guard let summary else { return }

    var lines: [String] = [
      summary.sport ?? "FIT activity",
      formatDistance(summary.distanceMeters) + " · " + formatDuration(summary.durationSeconds),
      (summary.averageHeartRate.map { "avg HR " + String($0) + " bpm" } ?? "HR n/a")
        + (summary.maxSpeedMps > 0 ? " · peak " + formatSpeed(summary.maxSpeedMps) : ""),
      String(screenPoints.count) + " GPS points · parsed in Swift WASM via SwiftFit",
    ]

    if let hoverIndex,
      screenPoints.indices.contains(hoverIndex)
    {
      let point = summary.points[hoverIndex]
      let hoverBits = [
        point.heartRate.map { "HR \($0)" },
        point.speedMps.map { formatSpeed($0) },
        point.altitudeMeters.map { jsNumber($0, decimals: 0) + " m elev" },
      ].compactMap { $0 }
      if !hoverBits.isEmpty {
        lines.append("hover · " + hoverBits.joined(separator: " · "))
      }
    }

    context.font = .string("12px ui-monospace, SFMono-Regular, Menlo, monospace")
    context.textBaseline = .string("top")
    var y = 14.0
    for (lineIndex, line) in lines.enumerated() {
      context.fillStyle = .string(lineIndex == 0 ? "rgba(235, 245, 255, 0.95)" : "rgba(180, 200, 225, 0.82)")
      _ = context.fillText(line, 16, y)
      y += lineIndex == 0 ? 20 : 16
    }
  }
}
