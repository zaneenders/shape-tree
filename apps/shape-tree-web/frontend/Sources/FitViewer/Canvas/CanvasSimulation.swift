func resetField() {
  orbs = []
  sparks = []
  ripples = []
  let count = 7
  for index in 0..<count {
    let angle = jsPi * 2 * Double(index) / Double(count)
    orbs.append(
      Orb(
        x: canvasWidth * 0.5 + jsCos(angle) * canvasWidth * 0.22,
        y: canvasHeight * 0.5 + jsSin(angle) * canvasHeight * 0.22,
        vx: jsRandom() * 2 - 1,
        vy: jsRandom() * 2 - 1,
        hue: 130 + Double(index) * 18,
        radius: 10 + jsRandom() * 6
      )
    )
  }
  mouseX = canvasWidth * 0.5
  mouseY = canvasHeight * 0.5
}

func addRipple(atX x: Double, atY y: Double) {
  ripples.append(Ripple(x: x, y: y, radius: 8, alpha: 0.55))
  if ripples.count > 12 {
    ripples.removeFirst()
  }
}

func spawnSparks(atX x: Double, atY y: Double, count: Int) {
  for _ in 0..<count {
    let angle = jsRandom() * jsPi * 2
    let speed = 1 + jsRandom() * 4
    sparks.append(
      Spark(
        x: x,
        y: y,
        vx: jsCos(angle) * speed,
        vy: jsSin(angle) * speed,
        life: 1,
        hue: 110 + jsRandom() * 70
      )
    )
  }
  if sparks.count > 200 {
    sparks.removeFirst(sparks.count - 200)
  }
}

func clampOrbsToCanvas() {
  for index in orbs.indices {
    orbs[index].x = clamp(orbs[index].x, min: 20, max: canvasWidth - 20)
    orbs[index].y = clamp(orbs[index].y, min: 20, max: canvasHeight - 20)
  }
}

func stepSimulation() {
  let pointerStrength = attractMode ? 0.04 : -0.06

  for index in orbs.indices {
    var orb = orbs[index]

    if pointerInside {
      let dx = mouseX - orb.x
      let dy = mouseY - orb.y
      let distance = jsMax(8, jsHypot(dx, dy))
      let force = pointerStrength * 120 / distance
      orb.vx += (dx / distance) * force
      orb.vy += (dy / distance) * force
    }

    orb.vx += jsSin(frame * 0.02 + Double(index)) * 0.02
    orb.vy += jsCos(frame * 0.018 + Double(index)) * 0.02
    orb.vx *= 0.985
    orb.vy *= 0.985
    orb.x += orb.vx
    orb.y += orb.vy

    if orb.x < orb.radius {
      orb.x = orb.radius
      orb.vx *= -0.7
    } else if orb.x > canvasWidth - orb.radius {
      orb.x = canvasWidth - orb.radius
      orb.vx *= -0.7
    }
    if orb.y < orb.radius {
      orb.y = orb.radius
      orb.vy *= -0.7
    } else if orb.y > canvasHeight - orb.radius {
      orb.y = canvasHeight - orb.radius
      orb.vy *= -0.7
    }

    orbs[index] = orb
  }

  var rippleIndex = ripples.count - 1
  while rippleIndex >= 0 {
    ripples[rippleIndex].radius += 2.4
    ripples[rippleIndex].alpha -= 0.018
    if ripples[rippleIndex].alpha <= 0 {
      ripples.remove(at: rippleIndex)
    }
    rippleIndex -= 1
  }

  var sparkIndex = sparks.count - 1
  while sparkIndex >= 0 {
    var spark = sparks[sparkIndex]
    spark.life -= 0.025
    if spark.life <= 0 {
      sparks.remove(at: sparkIndex)
    } else {
      spark.vx *= 0.96
      spark.vy = spark.vy * 0.96 + 0.05
      spark.x += spark.vx
      spark.y += spark.vy
      sparks[sparkIndex] = spark
    }
    sparkIndex -= 1
  }
}
