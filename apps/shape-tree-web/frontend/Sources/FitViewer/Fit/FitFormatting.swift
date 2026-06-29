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
