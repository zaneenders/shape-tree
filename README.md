# shape-tree

ShapeTree is a small, self-hosted Swift stack for an LLM agent, a markdown journal backed by git,
and a static-ish blog. 

| App | What it is |
|---|---|
| [`apps/shape-tree-api`](apps/shape-tree-api) | Hummingbird server wrapping the [Scribe](https://github.com/zaneenders/scribe) agent. Streams chat completions, tool calls and serves a journal. |
| [`apps/shape-tree-web`](apps/shape-tree-web) | Markdown blog built on [Lorikeet](https://github.com/zaneenders/lorikeet) and [Hummingbird](https://github.com/hummingbird-project/hummingbird/). |
| [`apps/ShapeTreeApp`](apps/ShapeTreeApp) | Cross-platform (iOS + macOS) SwiftUI client that talks to the API. |


## Run it

```bash
./scripts/docker-build.sh && docker compose up -d
# api        -> http://127.0.0.1:42067
# web        -> http://127.0.0.1:42069
# jaeger     -> http://127.0.0.1:16686   (traces)
# parca      -> http://127.0.0.1:7070    (profiles)
# prometheus -> http://127.0.0.1:9090    (metrics)
# grafana    -> http://127.0.0.1:3000    (admin / admin)
```

`scripts/docker-build.sh` cross-compiles the Swift binaries for the host arch (it also builds the
web WASM client), then runs `docker compose build`. The compose file mounts the API's data directory
and the web example content read-only, so a built clone starts end-to-end. Both apps export
OpenTelemetry traces to Jaeger and Prometheus-format metrics on their admin ports; Parca is wired
into Grafana for continuous profiling.

See each subproject's README for `.env` details, the ES256 device-key trust model, and
platform-specific build steps.

> **Note for `server-tower` deployments:** The standalone `docker-compose.yml` in this repo uses
> in-memory Jaeger storage, so traces are lost when the Jaeger container restarts. The production
> orchestration in [`server-tower`](https://github.com/zaneenders/server-tower) overrides this to
> use Badger local storage with a 90-day trace retention period. The standalone compose also omits
> `parca-agent`; `server-tower` adds it so Parca CPU profiles are actually collected.

