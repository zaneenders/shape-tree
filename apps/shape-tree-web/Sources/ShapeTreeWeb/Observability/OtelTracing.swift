import Foundation
import Logging
import OTel
import ServiceLifecycle
import Tracing

enum OtelTracing {
  enum BootstrapError: Error, CustomStringConvertible, LocalizedError {
    case openTelemetryDisabled

    var description: String { errorDescription ?? "OpenTelemetry bootstrap failed" }

    var errorDescription: String? {
      switch self {
      case .openTelemetryDisabled:
        return "OpenTelemetry is required but OTEL_SDK_DISABLED=true"
      }
    }
  }

  static func bootstrap(settings: OtelSettings, logger: Logger) throws -> any Service {
    if settings.disabled {
      throw BootstrapError.openTelemetryDisabled
    }

    let tracesEndpoint = otlpTracesURL(fromBase: settings.otlpBaseEndpoint)

    var config = OTel.Configuration.default
    config.serviceName = settings.serviceName
    config.diagnosticLogLevel = .warning
    config.logs.enabled = false
    config.metrics.enabled = false
    config.traces.otlpExporter.endpoint = tracesEndpoint
    config.traces.otlpExporter.protocol = .httpProtobuf

    logger.notice(
      "OpenTelemetry tracing enabled (service: \(settings.serviceName), endpoint: \(tracesEndpoint))"
    )

    // Use the tracing-only backend so OTel does not also try to bootstrap
    // the process-wide `MetricsSystem` — we already gave that to Prometheus.
    let backend = try OTel.makeTracingBackend(configuration: config)
    InstrumentationSystem.bootstrap(backend.factory)
    return backend.service
  }

  /// swift-otel uses the endpoint as-is when set in code (no `/v1/traces` suffix).
  package static func otlpTracesURL(fromBase baseEndpoint: String) -> String {
    if baseEndpoint.contains("/v1/traces") { return baseEndpoint }
    if baseEndpoint.hasSuffix("/") { return "\(baseEndpoint)v1/traces" }
    return "\(baseEndpoint)/v1/traces"
  }
}
