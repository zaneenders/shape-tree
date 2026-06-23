import JavaScriptKit

@main
enum CanvasPage {
  nonisolated(unsafe) static var closures: [JSClosure] = []
  nonisolated(unsafe) static var particles: [Particle] = []
  nonisolated(unsafe) static var mouseX: Double = 0
  nonisolated(unsafe) static var mouseY: Double = 0
  nonisolated(unsafe) static var pointerDown = false
  nonisolated(unsafe) static var width: Double = 800
  nonisolated(unsafe) static var height: Double = 500

  static func main() {
    let document = JSObject.global.document
    guard let main = document.getElementById("main").object else { return }

    _ = main.replaceChildren!()
    guard let article = document.createElement("article").object,
      let heading = document.createElement("h1").object,
      let blurb = document.createElement("p").object,
      let canvas = document.createElement("canvas").object
    else { return }

    heading.innerText = .string("Canvas")
    blurb.className = .string("canvas-blurb")
    blurb.innerText = .string("Move the pointer and hold to pull the field. Built in Swift WASM.")
    canvas.className = .string("playground-canvas")
    _ = canvas.setAttribute!("aria-label", "Interactive particle canvas")

    _ = article.appendChild!(heading)
    _ = article.appendChild!(blurb)
    _ = article.appendChild!(canvas)
    _ = main.appendChild!(article)

    resize(canvas: canvas)
    seedParticles()
    bindPointer(canvas: canvas)
    scheduleFrame(canvas: canvas)
  }

  private static func resize(canvas: JSObject) {
    let dpr = JSObject.global.devicePixelRatio.number ?? 1
    width = 800
    height = 480
    canvas.width = .number(width * dpr)
    canvas.height = .number(height * dpr)
    canvas.style.width = .string("100%")
    canvas.style.maxWidth = .string("800px")
    canvas.style.aspectRatio = .string("5 / 3")
    canvas.style.display = .string("block")

    if let ctx = canvas.getContext!("2d").object {
      _ = ctx.setTransform!(dpr, 0, 0, dpr, 0, 0)
    }
  }

  private static func seedParticles() {
    particles = (0..<90).map { _ in
      Particle(
        x: Double.random(in: 0...width),
        y: Double.random(in: 0...height),
        vx: Double.random(in: -1.2...1.2),
        vy: Double.random(in: -1.2...1.2),
        hue: Double.random(in: 0...360)
      )
    }
  }

  private static func bindPointer(canvas: JSObject) {
    let move = JSClosure { arguments in
      guard let event = arguments[0].object else { return .undefined }
      mouseX = event.offsetX.number ?? mouseX
      mouseY = event.offsetY.number ?? mouseY
      return .undefined
    }
    closures.append(move)
    _ = canvas.addEventListener!("pointermove", JSValue.object(move))

    let down = JSClosure { arguments in
      guard let event = arguments[0].object else { return .undefined }
      pointerDown = true
      mouseX = event.offsetX.number ?? mouseX
      mouseY = event.offsetY.number ?? mouseY
      _ = canvas.setPointerCapture!(event.pointerId)
      return .undefined
    }
    closures.append(down)
    _ = canvas.addEventListener!("pointerdown", JSValue.object(down))

    let up = JSClosure { _ in
      pointerDown = false
      return .undefined
    }
    closures.append(up)
    _ = canvas.addEventListener!("pointerup", JSValue.object(up))
    _ = canvas.addEventListener!("pointerleave", JSValue.object(up))
  }

  private static func scheduleFrame(canvas: JSObject) {
    let tick = JSClosure { _ in
      draw(canvas: canvas)
      scheduleFrame(canvas: canvas)
      return .undefined
    }
    closures.append(tick)
    _ = JSObject.global.requestAnimationFrame!(JSValue.object(tick))
  }

  private static func draw(canvas: JSObject) {
    guard let ctx = canvas.getContext!("2d").object else { return }

    _ = ctx.fillStyle = .string("rgba(8, 10, 18, 0.22)")
    _ = ctx.fillRect!(0, 0, width, height)

    for index in particles.indices {
      var particle = particles[index]

      if pointerDown {
        let dx = mouseX - particle.x
        let dy = mouseY - particle.y
        let dist = max(sqrt(dx * dx + dy * dy), 24)
        let force = 120 / dist
        particle.vx += dx / dist * force * 0.02
        particle.vy += dy / dist * force * 0.02
      }

      particle.x += particle.vx
      particle.y += particle.vy

      if particle.x <= 0 || particle.x >= width {
        particle.vx *= -1
        particle.x = min(max(particle.x, 0), width)
      }
      if particle.y <= 0 || particle.y >= height {
        particle.vy *= -1
        particle.y = min(max(particle.y, 0), height)
      }

      particle.vx *= 0.995
      particle.vy *= 0.995
      particle.hue = (particle.hue + 0.4).truncatingRemainder(dividingBy: 360)

      _ = ctx.fillStyle = .string(
        JSString("hsl(\(Int(particle.hue)) 85% 62%)")
      )
      _ = ctx.beginPath!()
      _ = ctx.arc!(particle.x, particle.y, 2.4, 0, Double.pi * 2)
      _ = ctx.fill!()

      particles[index] = particle
    }

    if pointerDown {
      _ = ctx.strokeStyle = .string("rgba(255, 255, 255, 0.35)")
      _ = ctx.lineWidth = .number(1)
      _ = ctx.beginPath!()
      _ = ctx.arc!(mouseX, mouseY, 28, 0, Double.pi * 2)
      _ = ctx.stroke!()
    }
  }

  private static func sqrt(_ value: Double) -> Double {
    value.squareRoot()
  }
}

struct Particle {
  var x: Double
  var y: Double
  var vx: Double
  var vy: Double
  var hue: Double
}
