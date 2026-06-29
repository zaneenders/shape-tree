import JavaScriptKit

let jsPi = JSObject.global.Math.object!.PI.number ?? 3.141592653589793

func jsPx(_ value: Double) -> String {
  jsNumber(value, decimals: 0) + "px"
}

func jsNumber(_ value: Double, decimals: Int = 2) -> String {
  if decimals == 0 {
    // Swift-native fast path — no JS bridge for common hue/percent formatting.
    return String(Int(value.rounded()))
  }
  let scale = jsPow(10, Double(decimals))
  let scaled = JSObject.global.Math.round.function!(value * scale).number ?? 0
  let whole = JSObject.global.Math.floor.function!(scaled / scale).number ?? 0
  let fraction = scaled - whole * scale
  var padded = JSObject.global.String.function!(JSObject.global.Math.abs.function!(fraction)).string ?? "0"
  if decimals == 2, fraction < 10 {
    padded = "0" + padded
  }
  return (JSObject.global.String.function!(whole).string ?? "0") + "." + padded
}

func jsPow(_ base: Double, _ exponent: Double) -> Double {
  JSObject.global.Math.object!.pow.function!(base, exponent).number ?? 1
}

func jsWindowInnerHeight() -> Double {
  JSObject.global.innerHeight.number ?? 600
}

func clamp(_ value: Double, min: Double, max: Double) -> Double {
  jsMax(min, jsMin(max, value))
}

func jsRandom() -> Double {
  JSObject.global.Math.object!.random.function!().number ?? 0
}

func jsSin(_ value: Double) -> Double {
  JSObject.global.Math.object!.sin.function!(value).number ?? 0
}

func jsCos(_ value: Double) -> Double {
  JSObject.global.Math.object!.cos.function!(value).number ?? 0
}

func jsHypot(_ x: Double, _ y: Double) -> Double {
  JSObject.global.Math.object!.hypot.function!(x, y).number ?? 0
}

func jsMax(_ a: Double, _ b: Double) -> Double {
  JSObject.global.Math.object!.max.function!(a, b).number ?? a
}

func jsMin(_ a: Double, _ b: Double) -> Double {
  JSObject.global.Math.object!.min.function!(a, b).number ?? a
}
