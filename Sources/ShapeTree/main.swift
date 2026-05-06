import Hummingbird
import Logging

let log = Logger(label: "shape-tree.server")

let store = SessionStore()
let router = buildRoutes(store: store, log: log)
let host = "0.0.0.0"
let port = 42069

let app = Application(
  router: router,
  configuration: .init(
    address: .hostname(host, port: port)
  )
)

log.info("event=server.start address=\(host):\(port)")

try await app.run()
