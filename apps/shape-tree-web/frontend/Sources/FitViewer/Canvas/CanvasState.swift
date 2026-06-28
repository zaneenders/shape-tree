import JavaScriptKit

nonisolated(unsafe) var orbs: [Orb] = []
nonisolated(unsafe) var sparks: [Spark] = []
nonisolated(unsafe) var ripples: [Ripple] = []
nonisolated(unsafe) var frame: Double = 0
nonisolated(unsafe) var mouseX: Double = 0
nonisolated(unsafe) var mouseY: Double = 0
nonisolated(unsafe) var pointerInside = false
nonisolated(unsafe) var attractMode = true
nonisolated(unsafe) var canvasWidth: Double = 640
nonisolated(unsafe) var canvasHeight: Double = 400
nonisolated(unsafe) var drawStep: JSClosure?
