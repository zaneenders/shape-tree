import JavaScriptKit
import ShapeTreeDOM

struct FitScreenPoint: Sendable {
  let x: Double
  let y: Double
  let heartRate: UInt8?
  let speedMps: Double?
  let altitudeMeters: Double?
  let hue: Double  // pre-computed heart-rate hue
}

nonisolated(unsafe) var fitSummary: FitActivitySummary?
nonisolated(unsafe) var fitScreenPoints: [FitScreenPoint] = []
nonisolated(unsafe) var fitPlaybackIndex: Double = 0
nonisolated(unsafe) var fitMinHeartRate: UInt8 = 60
nonisolated(unsafe) var fitMaxHeartRate: UInt8 = 180
nonisolated(unsafe) var fitHoverIndex: Int?

// Spatial index — grid of point indices for O(1) nearest-neighbor lookup.
nonisolated(unsafe) var fitPointGrid: [Int] = []  // flat list of point indices in cell order
nonisolated(unsafe) var fitPointGridStarts: [Int] = []  // start offset per cell (size = cols * rows + 1)
nonisolated(unsafe) var fitPointGridCols: Int = 0
nonisolated(unsafe) var fitPointGridRows: Int = 0
nonisolated(unsafe) var fitPointGridCellSize: Double = 30

// Offscreen canvas holding the pre-rendered route (base + glow).
nonisolated(unsafe) var fitRouteImage: JSValue?
nonisolated(unsafe) var fitRouteImageDirty: Bool = true

func loadFitActivity(_ summary: FitActivitySummary) {
  fitSummary = summary
  fitPlaybackIndex = 0
  fitHoverIndex = nil
  projectFitTrackToCanvas()
}

func projectFitTrackToCanvas() {
  guard let summary = fitSummary, !summary.points.isEmpty else {
    fitScreenPoints = []
    fitPointGrid = []
    fitPointGridStarts = []
    fitRouteImageDirty = true
    return
  }

  let lats = summary.points.map { $0.lat }
  let lons = summary.points.map { $0.lon }
  guard let minLat = lats.min(), let maxLat = lats.max(),
    let minLon = lons.min(), let maxLon = lons.max()
  else {
    fitScreenPoints = []
    fitPointGrid = []
    fitPointGridStarts = []
    fitRouteImageDirty = true
    return
  }

  let heartRates = summary.points.compactMap { $0.heartRate }
  if let minHR = heartRates.min(), let maxHR = heartRates.max(), maxHR > minHR {
    fitMinHeartRate = minHR
    fitMaxHeartRate = maxHR
  }
  let hrSpan = max(Double(fitMaxHeartRate - fitMinHeartRate), 1)

  let latSpan = max(maxLat - minLat, 0.0001)
  let lonSpan = max(maxLon - minLon, 0.0001)
  let padding = min(canvasWidth, canvasHeight) * 0.08
  let usableWidth = max(canvasWidth - padding * 2, 1)
  let usableHeight = max(canvasHeight - padding * 2, 1)
  let scale = min(usableWidth / lonSpan, usableHeight / latSpan)

  let projectedWidth = lonSpan * scale
  let projectedHeight = latSpan * scale
  let offsetX = (canvasWidth - projectedWidth) * 0.5
  let offsetY = (canvasHeight - projectedHeight) * 0.5

  fitScreenPoints = summary.points.map { point in
    let x = offsetX + (point.lon - minLon) * scale
    let y = offsetY + (maxLat - point.lat) * scale
    let t = point.heartRate.map { (Double($0) - Double(fitMinHeartRate)) / hrSpan } ?? 0.5
    let hue = 125 - t * 95
    return FitScreenPoint(
      x: x,
      y: y,
      heartRate: point.heartRate,
      speedMps: point.speedMps,
      altitudeMeters: point.altitudeMeters,
      hue: hue
    )
  }

  buildFitPointGrid()
  fitRouteImageDirty = true
}

func stepFitPlayback() {
  guard fitScreenPoints.count > 1 else { return }
  fitPlaybackIndex += 0.45
  if fitPlaybackIndex >= Double(fitScreenPoints.count - 1) {
    fitPlaybackIndex = 0
  }
}

func buildFitPointGrid() {
  guard !fitScreenPoints.isEmpty else {
    fitPointGrid = []
    fitPointGridStarts = []
    fitPointGridCols = 0
    fitPointGridRows = 0
    return
  }
  let cellSize = 30.0
  let cols = max(1, Int(canvasWidth / cellSize) + 1)
  let rows = max(1, Int(canvasHeight / cellSize) + 1)
  let cellCount = cols * rows

  // Count points per cell.
  var counts = [Int](repeating: 0, count: cellCount)
  for point in fitScreenPoints {
    let col = Int(point.x / cellSize)
    let row = Int(point.y / cellSize)
    if col >= 0, col < cols, row >= 0, row < rows {
      counts[row * cols + col] &+= 1
    }
  }

  // Build prefix sum for flat storage.
  var starts = [Int](repeating: 0, count: cellCount + 1)
  for i in 0..<cellCount {
    starts[i + 1] = starts[i] + counts[i]
  }
  var grid = [Int](repeating: 0, count: starts[cellCount])
  // Re-count as position trackers for insert.
  var pos = starts

  for (index, point) in fitScreenPoints.enumerated() {
    let col = Int(point.x / cellSize)
    let row = Int(point.y / cellSize)
    guard col >= 0, col < cols, row >= 0, row < rows else { continue }
    let cell = row * cols + col
    grid[pos[cell]] = index
    pos[cell] &+= 1
  }

  fitPointGrid = grid
  fitPointGridStarts = starts
  fitPointGridCols = cols
  fitPointGridRows = rows
  fitPointGridCellSize = cellSize
}

/// Swift-native distance squared — no JS bridge, much faster.
@inline(__always)
private func distanceSq(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
  let dx = x1 - x2
  let dy = y1 - y2
  return dx * dx + dy * dy
}

func nearestFitPointIndex(x: Double, y: Double) -> Int? {
  guard !fitScreenPoints.isEmpty else { return nil }

  // Use spatial index when available.
  if fitPointGridCols > 0, fitPointGridRows > 0 {
    let thresholdSq = 28.0 * 28.0
    var bestIndex: Int?
    var bestDistSq = thresholdSq
    let col = Int(x / fitPointGridCellSize)
    let row = Int(y / fitPointGridCellSize)
    for dr in -1...1 {
      for dc in -1...1 {
        let r = row + dr
        let c = col + dc
        guard r >= 0, r < fitPointGridRows, c >= 0, c < fitPointGridCols else { continue }
        let cell = r * fitPointGridCols + c
        let start = fitPointGridStarts[cell]
        let end = fitPointGridStarts[cell + 1]
        var i = start
        while i < end {
          let idx = fitPointGrid[i]
          let pt = fitScreenPoints[idx]
          let d2 = distanceSq(pt.x, pt.y, x, y)
          if d2 < bestDistSq {
            bestDistSq = d2
            bestIndex = idx
          }
          i &+= 1
        }
      }
    }
    return bestIndex
  }

  // Fallback: full scan with Swift-native distance.
  var bestIndex = 0
  var bestDistSq = Double.greatestFiniteMagnitude
  for (index, point) in fitScreenPoints.enumerated() {
    let d2 = distanceSq(point.x, point.y, x, y)
    if d2 < bestDistSq {
      bestDistSq = d2
      bestIndex = index
    }
  }
  return bestDistSq < (28.0 * 28.0) ? bestIndex : nil
}

func heartRateHue(_ heartRate: UInt8?) -> Double {
  guard let heartRate else { return 195 }
  let span = max(Double(fitMaxHeartRate - fitMinHeartRate), 1)
  let t = (Double(heartRate) - Double(fitMinHeartRate)) / span
  return 125 - t * 95
}

/// Build (or rebuild) the offscreen route image. Called when data or size changes.
func renderFitRouteToImage() {
  // Create offscreen canvas once and reuse.
  let offscreen: JSValue
  if let existing = fitRouteImage {
    offscreen = existing
  } else {
    offscreen = createElement("canvas")
  }
  offscreen.width = .number(canvasWidth)
  offscreen.height = .number(canvasHeight)
  guard let ctx = offscreen.getContext("2d").object else { return }
  let ctxVal = JSValue.object(ctx)

  // Clear.
  _ = ctxVal.clearRect(0, 0, canvasWidth, canvasHeight)

  // --- Grid ---
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

  // --- Altitude ribbon ---
  if let summary = fitSummary {
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

  // --- Base sharp route ---
  guard fitScreenPoints.count > 1 else {
    fitRouteImage = offscreen
    fitRouteImageDirty = false
    return
  }

  ctxVal.lineCap = .string("round")
  ctxVal.lineJoin = .string("round")

  for index in 1..<fitScreenPoints.count {
    let prev = fitScreenPoints[index - 1]
    let curr = fitScreenPoints[index]
    ctxVal.strokeStyle = .string("hsla(" + jsNumber(curr.hue, decimals: 0) + ", 88%, 58%, 0.92)")
    ctxVal.lineWidth = .number(4.5)
    _ = ctxVal.beginPath()
    _ = ctxVal.moveTo(prev.x, prev.y)
    _ = ctxVal.lineTo(curr.x, curr.y)
    _ = ctxVal.stroke()
  }

  // --- Glow pass ---
  ctxVal.globalCompositeOperation = .string("lighter")
  ctxVal.lineWidth = .number(10)

  for index in 1..<fitScreenPoints.count {
    let prev = fitScreenPoints[index - 1]
    let curr = fitScreenPoints[index]
    ctxVal.strokeStyle = .string("hsla(" + jsNumber(curr.hue, decimals: 0) + ", 90%, 62%, 0.12)")
    _ = ctxVal.beginPath()
    _ = ctxVal.moveTo(prev.x, prev.y)
    _ = ctxVal.lineTo(curr.x, curr.y)
    _ = ctxVal.stroke()
  }
  ctxVal.globalCompositeOperation = .string("source-over")

  // Start and end markers.
  if let first = fitScreenPoints.first {
    _ = ctxVal.beginPath()
    _ = ctxVal.arc(first.x, first.y, 7, 0, jsPi * 2)
    ctxVal.fillStyle = .string("rgba(120, 255, 180, 0.95)")
    _ = ctxVal.fill()
  }
  if let last = fitScreenPoints.last {
    _ = ctxVal.beginPath()
    _ = ctxVal.arc(last.x, last.y, 7, 0, jsPi * 2)
    ctxVal.fillStyle = .string("rgba(255, 120, 120, 0.95)")
    _ = ctxVal.fill()
  }

  fitRouteImage = offscreen
  fitRouteImageDirty = false
}

func formatDistance(_ meters: Double) -> String {
  if meters >= 1000 {
    return jsNumber(meters / 1000, decimals: 1) + " km"
  }
  return jsNumber(meters, decimals: 0) + " m"
}

func formatDuration(_ seconds: Double) -> String {
  let total = Int(seconds.rounded())
  let hours = total / 3600
  let minutes = (total % 3600) / 60
  let secs = total % 60
  if hours > 0 {
    return "\(hours)h \(minutes)m"
  }
  if minutes > 0 {
    return "\(minutes)m \(secs)s"
  }
  return "\(secs)s"
}

func formatSpeed(_ metersPerSecond: Double) -> String {
  let kmh = metersPerSecond * 3.6
  return jsNumber(kmh, decimals: 1) + " km/h"
}

func drawFitFrame(context: JSValue) {
  context.fillStyle = .string("#070b12")
  _ = context.fillRect(0, 0, canvasWidth, canvasHeight)

  // Blit pre-rendered scene: grid + altitude ribbon + route + markers.
  if fitRouteImageDirty { renderFitRouteToImage() }
  if let img = fitRouteImage {
    _ = context.drawImage(img, 0, 0)
  }

  drawFitPlaybackMarker(context: context)
  drawFitHoverMarker(context: context)
  drawFitHUD(context: context)
}

func drawFitPlaybackMarker(context: JSValue) {
  guard fitScreenPoints.count > 1 else { return }
  let index = Int(fitPlaybackIndex)
  let fraction = fitPlaybackIndex - Double(index)
  let nextIndex = min(Double(fitScreenPoints.count - 1), fitPlaybackIndex + 1)
  let current = fitScreenPoints[index]
  let next = fitScreenPoints[Int(nextIndex)]
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

func drawFitHoverMarker(context: JSValue) {
  guard let index = fitHoverIndex, fitScreenPoints.indices.contains(index) else { return }
  let point = fitScreenPoints[index]
  _ = context.beginPath()
  _ = context.arc(point.x, point.y, 11, 0, jsPi * 2)
  context.strokeStyle = .string("rgba(255, 255, 255, 0.85)")
  context.lineWidth = .number(2)
  _ = context.stroke()
}

func drawFitHUD(context: JSValue) {
  guard let summary = fitSummary else { return }

  var lines: [String] = [
    summary.sport ?? "FIT activity",
    formatDistance(summary.distanceMeters) + " · " + formatDuration(summary.durationSeconds),
    (summary.averageHeartRate.map { "avg HR " + String($0) + " bpm" } ?? "HR n/a")
      + (summary.maxSpeedMps > 0 ? " · peak " + formatSpeed(summary.maxSpeedMps) : ""),
    String(fitScreenPoints.count) + " GPS points · parsed in Swift WASM via SwiftFit",
  ]

  if let hoverIndex = fitHoverIndex,
    fitScreenPoints.indices.contains(hoverIndex),
    let point = fitSummary?.points[hoverIndex]
  {
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
