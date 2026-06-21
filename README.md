# shape-tree

ShapeTree is a small, self-hosted Swift stack for an LLM agent, a markdown journal backed by git,
and a static-ish blog. 

| App | What it is |
|---|---|
| [`apps/shape-tree-api`](apps/shape-tree-api) | Hummingbird server wrapping the [Scribe](https://github.com/zaneenders/scribe) agent. Streams chat completions, tool calls and serves a journal. |
| [`apps/shape-tree-web`](apps/shape-tree-web) | Markdown blog built on [Lorikeet](https://github.com/zaneenders/lorikeet) and [Hummingbird](https://github.com/hummingbird-project/hummingbird/). |
| [`apps/ShapeTreeApp`](apps/ShapeTreeApp) | Cross-platform (iOS + macOS) SwiftUI client that talks to the API. |


## Run it

### Setup

```bash
cp apps/shape-tree-api/.env.example apps/shape-tree-api/.env
cp apps/shape-tree-web/.env.example apps/shape-tree-web/.env
```

Edit the two `.env` files with your real values (see each subproject's README for what each variable does). The web app requires SMTP when Postgres auth is configured.

```bash
./scripts/docker-build.sh up
# api        -> http://127.0.0.1:42067
# web        -> http://127.0.0.1:42069
# jaeger     -> http://127.0.0.1:16686   (traces)
# parca      -> http://127.0.0.1:7070    (profiles)
# prometheus -> http://127.0.0.1:9090    (metrics)
# grafana    -> http://127.0.0.1:3000    (admin / admin)
```

