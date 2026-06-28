import JavaScriptKit

func drawFrame(context: JSValue) {
  context.fillStyle = .string("rgba(13, 17, 23, 0.28)")
  _ = context.fillRect(0, 0, canvasWidth, canvasHeight)

  let gradient = context.createLinearGradient(0, 0, canvasWidth, canvasHeight)
  _ = gradient.addColorStop(0, "rgba(17, 24, 39, 0.35)")
  _ = gradient.addColorStop(1, "rgba(3, 7, 18, 0.35)")
  context.fillStyle = gradient
  _ = context.fillRect(0, 0, canvasWidth, canvasHeight)

  drawLinks(context: context)
  drawRipples(context: context)
  drawSparks(context: context)
  drawOrbs(context: context)
  drawPointer(context: context)
}

func drawLinks(context: JSValue) {
  let threshold = jsMin(canvasWidth, canvasHeight) * 0.22
  context.lineWidth = .number(1.5)

  for left in 0..<orbs.count {
    for right in (left + 1)..<orbs.count {
      let a = orbs[left]
      let b = orbs[right]
      let distance = jsHypot(a.x - b.x, a.y - b.y)
      if distance < threshold {
        let alpha = (1 - distance / threshold) * 0.45
        context.strokeStyle = .string("rgba(120, 220, 170, " + jsNumber(alpha) + ")")
        _ = context.beginPath()
        _ = context.moveTo(a.x, a.y)
        _ = context.lineTo(b.x, b.y)
        _ = context.stroke()
      }
    }
  }
}

func drawRipples(context: JSValue) {
  for ripple in ripples {
    _ = context.beginPath()
    _ = context.arc(ripple.x, ripple.y, ripple.radius, 0, jsPi * 2)
    context.strokeStyle = .string("rgba(160, 255, 210, " + jsNumber(ripple.alpha) + ")")
    context.lineWidth = .number(2)
    _ = context.stroke()
  }
}

func drawSparks(context: JSValue) {
  context.globalCompositeOperation = .string("lighter")
  for spark in sparks {
    _ = context.beginPath()
    _ = context.arc(spark.x, spark.y, 1.5 + (1 - spark.life) * 2, 0, jsPi * 2)
    context.fillStyle = .string(
      "hsla(" + jsNumber(spark.hue, decimals: 0) + ", 90%, 65%, " + jsNumber(spark.life * 0.8) + ")")
    _ = context.fill()
  }
  context.globalCompositeOperation = .string("source-over")
}

func drawOrbs(context: JSValue) {
  for (index, orb) in orbs.enumerated() {
    let pulse = 0.5 + 0.5 * jsSin(frame * 0.05 + Double(index))
    let glow = orb.radius + 10 + pulse * 4

    _ = context.beginPath()
    _ = context.arc(orb.x, orb.y, glow, 0, jsPi * 2)
    context.fillStyle = .string("hsla(" + jsNumber(orb.hue, decimals: 0) + ", 80%, 60%, 0.14)")
    _ = context.fill()

    _ = context.beginPath()
    _ = context.arc(orb.x, orb.y, orb.radius + pulse * 2, 0, jsPi * 2)
    context.fillStyle = .string("hsl(" + jsNumber(orb.hue, decimals: 0) + ", 78%, 62%)")
    _ = context.fill()
  }
}

func drawPointer(context: JSValue) {
  if !pointerInside { return }
  _ = context.beginPath()
  _ = context.arc(mouseX, mouseY, 90, 0, jsPi * 2)
  context.strokeStyle = .string(attractMode ? "rgba(120, 220, 180, 0.16)" : "rgba(255, 130, 130, 0.16)")
  context.lineWidth = .number(1.5)
  _ = context.stroke()

  _ = context.beginPath()
  _ = context.arc(mouseX, mouseY, 5, 0, jsPi * 2)
  context.fillStyle = .string(attractMode ? "rgba(170, 255, 210, 0.9)" : "rgba(255, 170, 170, 0.9)")
  _ = context.fill()
}
