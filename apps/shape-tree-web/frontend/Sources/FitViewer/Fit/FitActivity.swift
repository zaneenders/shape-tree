import SwiftFit

enum FitGlobalMessage {
  static let record: UInt16 = 20
  static let session: UInt16 = 18
  static let activity: UInt16 = 34
}

enum FitRecordField {
  static let timestamp: UInt8 = 0
  static let positionLat: UInt8 = 1
  static let positionLong: UInt8 = 2
  static let altitude: UInt8 = 3
  static let distance: UInt8 = 5
  static let speed: UInt8 = 6
  static let heartRate: UInt8 = 7
}

struct FitTrackPoint: Sendable {
  let lat: Double
  let lon: Double
  let altitudeMeters: Double?
  let heartRate: UInt8?
  let speedMps: Double?
  let distanceMeters: Double?
  let timestamp: UInt32?
}

struct FitActivitySummary: Sendable {
  let points: [FitTrackPoint]
  let sport: String?
  let durationSeconds: Double
  let distanceMeters: Double
  let averageHeartRate: UInt8?
  let maxHeartRate: UInt8?
  let maxSpeedMps: Double
}

enum FitActivityParser {
  private static let semicircleScale = 180.0 / 2_147_483_648.0

  static func parse(bytes: [UInt8]) throws(FITError) -> FitActivitySummary {
    let fit = try FITFile(bytes: bytes)
    var points: [FitTrackPoint] = []
    points.reserveCapacity(fit.messages.count / 4)

    for message in fit.messages where message.globalMessageNumber == FitGlobalMessage.record {
      guard let point = trackPoint(from: message) else { continue }
      points.append(point)
    }

    let sport = fit.messages
      .first { $0.globalMessageNumber == FitGlobalMessage.session }
      .flatMap { stringField($0, number: 5) }

    let heartRates = points.compactMap { $0.heartRate }
    let speeds = points.compactMap { $0.speedMps }
    let distanceMeters = points.last?.distanceMeters ?? 0
    let timestamps = points.compactMap { $0.timestamp }.sorted()
    let durationSeconds: Double
    if let first = timestamps.first, let last = timestamps.last, last > first {
      durationSeconds = Double(last - first)
    } else {
      durationSeconds = Double(points.count)
    }

    return FitActivitySummary(
      points: points,
      sport: sport,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      averageHeartRate: averageHeartRate(from: heartRates),
      maxHeartRate: heartRates.max(),
      maxSpeedMps: speeds.max() ?? 0
    )
  }

  private static func trackPoint(from message: Message) -> FitTrackPoint? {
    let latLon: (lat: Int32, lon: Int32)?
    if let lat = sint32Field(message, number: FitRecordField.positionLat),
      let lon = sint32Field(message, number: FitRecordField.positionLong)
    {
      latLon = (lat, lon)
    } else if let lat = sint32Field(message, number: 0),
      let lon = sint32Field(message, number: 1)
    {
      latLon = (lat, lon)
    } else {
      latLon = nil
    }

    guard let latLon else { return nil }

    let lat = Double(latLon.lat) * semicircleScale
    let lon = Double(latLon.lon) * semicircleScale
    guard lat.isFinite, lon.isFinite, abs(lat) <= 90, abs(lon) <= 180 else { return nil }

    let altitude: Double?
    if let raw = uint16Field(message, number: 2), raw != 0xFFFF {
      altitude = (Double(raw) / 5.0) - 500.0
    } else if let raw = uint16Field(message, number: FitRecordField.altitude), raw != 0xFFFF {
      altitude = (Double(raw) / 5.0) - 500.0
    } else {
      altitude = nil
    }

    let heartRate =
      uint8Field(message, number: 3)
      ?? uint8Field(message, number: FitRecordField.heartRate)
    let speedMps: Double?
    if let raw = uint16Field(message, number: FitRecordField.speed), raw != 0xFFFF {
      speedMps = Double(raw) / 1000.0
    } else {
      speedMps = nil
    }

    let distanceMeters: Double?
    if let raw = uint32Field(message, number: FitRecordField.distance) {
      distanceMeters = Double(raw) / 100.0
    } else {
      distanceMeters = nil
    }

    let timestamp = uint32Field(message, number: FitRecordField.timestamp)

    return FitTrackPoint(
      lat: lat,
      lon: lon,
      altitudeMeters: altitude,
      heartRate: heartRate,
      speedMps: speedMps,
      distanceMeters: distanceMeters,
      timestamp: timestamp
    )
  }

  private static func averageHeartRate(from values: [UInt8]) -> UInt8? {
    guard !values.isEmpty else { return nil }
    let total = values.reduce(UInt(0)) { $0 + UInt($1) }
    return UInt8(total / UInt(values.count))
  }

  private static func field(_ message: Message, number: UInt8) -> Field? {
    message.fields.first { $0.fieldDefinitionNumber == number }
  }

  private static func firstValue(_ field: Field?) -> Value? {
    field?.values.first
  }

  private static func uint8Field(_ message: Message, number: UInt8) -> UInt8? {
    guard let value = firstValue(field(message, number: number)) else { return nil }
    switch value {
    case .uint8(let v), .uint8z(let v), .enumType(let v), .byte(let v): return v
    default: return nil
    }
  }

  private static func uint16Field(_ message: Message, number: UInt8) -> UInt16? {
    guard let value = firstValue(field(message, number: number)) else { return nil }
    switch value {
    case .uint16(let v), .uint16z(let v): return v
    default: return nil
    }
  }

  private static func uint32Field(_ message: Message, number: UInt8) -> UInt32? {
    guard let value = firstValue(field(message, number: number)) else { return nil }
    switch value {
    case .uint32(let v), .uint32z(let v): return v
    default: return nil
    }
  }

  private static func sint32Field(_ message: Message, number: UInt8) -> Int32? {
    guard let value = firstValue(field(message, number: number)) else { return nil }
    switch value {
    case .sint32(let v): return v
    default: return nil
    }
  }

  private static func stringField(_ message: Message, number: UInt8) -> String? {
    guard let value = firstValue(field(message, number: number)) else { return nil }
    if case .string(let text) = value {
      let trimmed = trimWhitespace(text)
      return trimmed.isEmpty ? nil : trimmed
    }
    return nil
  }

  private static func trimWhitespace(_ text: String) -> String {
    var start = text.startIndex
    var end = text.endIndex
    while start < end, text[start].isWhitespace {
      start = text.index(after: start)
    }
    while end > start {
      let prior = text.index(before: end)
      if !text[prior].isWhitespace { break }
      end = prior
    }
    return String(text[start..<end])
  }
}
