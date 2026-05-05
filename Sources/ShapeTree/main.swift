import Hummingbird
import Logging

let log = Logger(label: "shape-tree.server")

let store = SessionStore()
let router = buildRoutes(store: store, log: log)

let app = Application(
  router: router,
  configuration: .init(
    address: .hostname("0.0.0.0", port: 8080)
  )
)

log.info("event=server.start address=0.0.0.0:8080")

try await app.run()
