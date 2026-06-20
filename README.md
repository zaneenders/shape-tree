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
./scripts/docker-build.sh && docker compose up --build
# api  -> http://127.0.0.1:42067
# web  -> http://127.0.0.1:42069
```

The compose file mounts the API's data directory and the web example content read-only, so a clean
clone will start end-to-end. See each subproject's README for `.env` details, the ES256 device-key
trust model, and platform-specific build steps.
