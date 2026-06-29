struct FitPointGrid: Sendable {
  var indices: [Int] = []
  var starts: [Int] = []
  var cols: Int = 0
  var rows: Int = 0
  var cellSize: Double = 30

  mutating func rebuild(screenPoints: [FitScreenPoint], canvasWidth: Double, canvasHeight: Double) {
    guard !screenPoints.isEmpty else {
      indices = []
      starts = []
      cols = 0
      rows = 0
      return
    }

    let cellSize = 30.0
    let cols = max(1, Int(canvasWidth / cellSize) + 1)
    let rows = max(1, Int(canvasHeight / cellSize) + 1)
    let cellCount = cols * rows

    var counts = [Int](repeating: 0, count: cellCount)
    for point in screenPoints {
      let col = Int(point.x / cellSize)
      let row = Int(point.y / cellSize)
      if col >= 0, col < cols, row >= 0, row < rows {
        counts[row * cols + col] &+= 1
      }
    }

    var starts = [Int](repeating: 0, count: cellCount + 1)
    for i in 0..<cellCount {
      starts[i + 1] = starts[i] + counts[i]
    }
    var grid = [Int](repeating: 0, count: starts[cellCount])
    var pos = starts

    for (index, point) in screenPoints.enumerated() {
      let col = Int(point.x / cellSize)
      let row = Int(point.y / cellSize)
      guard col >= 0, col < cols, row >= 0, row < rows else { continue }
      let cell = row * cols + col
      grid[pos[cell]] = index
      pos[cell] &+= 1
    }

    self.indices = grid
    self.starts = starts
    self.cols = cols
    self.rows = rows
    self.cellSize = cellSize
  }

  func nearestPointIndex(x: Double, y: Double, in screenPoints: [FitScreenPoint]) -> Int? {
    guard !screenPoints.isEmpty else { return nil }

    if cols > 0, rows > 0 {
      let thresholdSq = 28.0 * 28.0
      var bestIndex: Int?
      var bestDistSq = thresholdSq
      let col = Int(x / cellSize)
      let row = Int(y / cellSize)
      for dr in -1...1 {
        for dc in -1...1 {
          let r = row + dr
          let c = col + dc
          guard r >= 0, r < rows, c >= 0, c < cols else { continue }
          let cell = r * cols + c
          let start = starts[cell]
          let end = starts[cell + 1]
          var i = start
          while i < end {
            let idx = indices[i]
            let pt = screenPoints[idx]
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

    var bestIndex = 0
    var bestDistSq = Double.greatestFiniteMagnitude
    for (index, point) in screenPoints.enumerated() {
      let d2 = distanceSq(point.x, point.y, x, y)
      if d2 < bestDistSq {
        bestDistSq = d2
        bestIndex = index
      }
    }
    return bestDistSq < (28.0 * 28.0) ? bestIndex : nil
  }
}

@inline(__always)
private func distanceSq(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
  let dx = x1 - x2
  let dy = y1 - y2
  return dx * dx + dy * dy
}
