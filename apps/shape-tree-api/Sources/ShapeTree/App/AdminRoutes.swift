import Hummingbird
import Logging
import NIOCore

func buildAdminApplication(
  host: String,
  port: Int,
  serviceName: String,
  logger: Logger
) -> some ApplicationProtocol {
  var adminLogger = logger
  adminLogger[metadataKey: "server"] = "admin"
  adminLogger.info(
    "event=admin.start address=\(host):\(port) service=\(serviceName)")

  return Application(
    router: buildAdminRouter(),
    configuration: .init(
      address: .hostname(host, port: port),
      serverName: "ShapeTreeAdmin"
    ),
    logger: adminLogger
  )
}

func buildAdminRouter() -> Router<BasicRequestContext> {
  let router = Router(context: BasicRequestContext.self)

  router.get("healthz") { _, _ -> Response in
    Response(
      status: .ok,
      headers: [.contentType: "text/plain; charset=utf-8"],
      body: .init(byteBuffer: ByteBuffer(string: "ok")))
  }

  router.get("metrics") { _, _ -> Response in
    let body = PrometheusMetrics.registry.emitToString()
    return Response(
      status: .ok,
      headers: [.contentType: "text/plain; version=0.0.4; charset=utf-8"],
      body: .init(byteBuffer: ByteBuffer(string: body)))
  }

  return router
}
