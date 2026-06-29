import JavaScriptKit
import ShapeTreeDOM

@JS public func bootstrap() {
  installEventLoop()
}

@JS public func teardownFitViewer() {
  resetFitViewerState()
}

@JS public func renderFitViewer(into container: JSValue) async {
  resetFitViewerState()

  let shell = mountFeatureShell(
    into: container,
    className: "fit-viewer",
    loadingMessage: "Loading activity…"
  )

  let stage = createElement("div", className: "canvas-stage")
  append(stage, to: shell.wrapper)

  let canvas = createElement("canvas", id: "demo-canvas")
  append(canvas, to: stage)

  let hint = createElement(
    "p",
    className: "hint",
    innerText: "Route colored by heart rate · hover for point stats · green=start · red=finish"
  )
  append(hint, to: shell.wrapper)

  wireCanvasEvents(canvas: canvas)
  wireResize(canvas: canvas, stage: stage)
  resizeCanvas(canvas: canvas, stage: stage)
  startDrawLoop(canvas: canvas)

  var bytes: [UInt8]?
  do {
    bytes = try await fetchBytes("/sample.fit")
  } catch {
    setInnerText(shell.status, "Failed to load /sample.fit")
  }

  if let bytes, !bytes.isEmpty {
    do {
      let summary = try FitActivityParser.parse(bytes: bytes)
      loadFitActivity(summary)
      projectFitTrackToCanvas()

      var statusText = "Parsed \(summary.points.count) GPS points"
      if let sport = summary.sport {
        statusText += " · \(sport)"
      }
      statusText += " · \(formatDistance(summary.distanceMeters))"
      setInnerText(shell.status, statusText)
    } catch {
      setInnerText(shell.status, "FIT parse failed")
    }
  } else if bytes != nil {
    setInnerText(shell.status, "Loaded empty FIT file")
  }
}

private func resetFitViewerState() {
  stopDrawLoop()
  fitSummary = nil
  fitScreenPoints = []
  fitPlaybackIndex = 0
  fitHoverIndex = nil
  fitPointGrid = []
  fitPointGridStarts = []
  fitPointGridCols = 0
  fitPointGridRows = 0
  fitRouteImage = nil
  fitRouteImageDirty = true
}
