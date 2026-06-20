import Metrics
import Prometheus

enum PrometheusMetrics {
  static let registry: PrometheusCollectorRegistry = {
    let registry = PrometheusCollectorRegistry()
    let factory = PrometheusMetricsFactory(registry: registry)
    MetricsSystem.bootstrap(factory)
    return registry
  }()
}
