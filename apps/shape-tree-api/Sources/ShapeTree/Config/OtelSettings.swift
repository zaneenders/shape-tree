import Configuration
import Foundation

struct OtelSettings: Sendable {
  let serviceName: String
  let otlpBaseEndpoint: String
  /// Mirrors the OTel spec's `OTEL_SDK_DISABLED` master switch.
  /// Unset == false == OTel enabled (matches the OTel default).
  let disabled: Bool

  init(
    serviceName: String,
    otlpBaseEndpoint: String,
    disabled: Bool
  ) {
    self.serviceName = serviceName
    self.otlpBaseEndpoint = otlpBaseEndpoint
    self.disabled = disabled
  }

  static func load(from config: ConfigReader) throws -> OtelSettings {
    let serviceName =
      try config.requiredString(forKey: "OTEL_SERVICE_NAME", isSecret: false)
    let otlpBaseEndpoint =
      try config.requiredString(forKey: "OTEL_EXPORTER_OTLP_BASE_ENDPOINT", isSecret: false)
    let disabled = config.bool(forKey: "OTEL_SDK_DISABLED", isSecret: false) ?? false

    return OtelSettings(
      serviceName: serviceName,
      otlpBaseEndpoint: otlpBaseEndpoint,
      disabled: disabled
    )
  }
}
