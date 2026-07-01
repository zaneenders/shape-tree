import JavaScriptKit

nonisolated(unsafe) var fitViewState = FitViewState()

struct FitViewState {
  var summary: FitActivitySummary?
  var screenPoints: [FitScreenPoint] = []
  var playbackIndex: Double = 0
  var minHeartRate: UInt8 = 60
  var maxHeartRate: UInt8 = 180
  var hoverIndex: Int?
  var pointGrid = FitPointGrid()
  var routeImage: JSValue?
  var routeImageDirty = true
  var canvasWidth: Double = 640
  var canvasHeight: Double = 400
  var drawStep: JSClosure?

  mutating func reset() {
    drawStep = nil
    summary = nil
    screenPoints = []
    playbackIndex = 0
    hoverIndex = nil
    pointGrid = FitPointGrid()
    routeImage = nil
    routeImageDirty = true
    canvasWidth = 640
    canvasHeight = 400
  }

  mutating func loadActivity(_ summary: FitActivitySummary) {
    self.summary = summary
    playbackIndex = 0
    hoverIndex = nil
    projectTrackToCanvas()
  }

  mutating func projectTrackToCanvas() {
    guard let summary, !summary.points.isEmpty else {
      screenPoints = []
      pointGrid = FitPointGrid()
      routeImageDirty = true
      return
    }

    let lats = summary.points.map { $0.lat }
    let lons = summary.points.map { $0.lon }
    guard let minLat = lats.min(), let maxLat = lats.max(),
      let minLon = lons.min(), let maxLon = lons.max()
    else {
      screenPoints = []
      pointGrid = FitPointGrid()
      routeImageDirty = true
      return
    }

    let heartRates = summary.points.compactMap { $0.heartRate }
    if let minHR = heartRates.min(), let maxHR = heartRates.max(), maxHR > minHR {
      minHeartRate = minHR
      maxHeartRate = maxHR
    }
    let hrSpan = max(Double(maxHeartRate - minHeartRate), 1)

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

    screenPoints = summary.points.map { point in
      let x = offsetX + (point.lon - minLon) * scale
      let y = offsetY + (maxLat - point.lat) * scale
      let t = point.heartRate.map { (Double($0) - Double(minHeartRate)) / hrSpan } ?? 0.5
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

    pointGrid.rebuild(
      screenPoints: screenPoints,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight
    )
    routeImageDirty = true
  }

  mutating func stepPlayback() {
    guard screenPoints.count > 1 else { return }
    playbackIndex += 0.45
    if playbackIndex >= Double(screenPoints.count - 1) {
      playbackIndex = 0
    }
  }

  func nearestPointIndex(x: Double, y: Double) -> Int? {
    pointGrid.nearestPointIndex(x: x, y: y, in: screenPoints)
  }

  func heartRateHue(_ heartRate: UInt8?) -> Double {
    guard let heartRate else { return 195 }
    let span = max(Double(maxHeartRate - minHeartRate), 1)
    let t = (Double(heartRate) - Double(minHeartRate)) / span
    return 125 - t * 95
  }
}
