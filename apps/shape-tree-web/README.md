# shape-tree-web

Swift Hummingbird server + WASM frontend (JavaScriptKit). Part of the [shape-tree](../../) monorepo.

## Build & run

The server runs without any backing services, but to enable email login + fit-viewer protection you
need Postgres in the background:

```
docker compose up postgres -d
```

(The shipped `.env` already targets `127.0.0.1:5432`, so `swift run ShapeTreeWeb` picks it up
directly.) For traces, also `docker compose up jaeger -d` — or set `OTEL_SDK_DISABLED=true` to skip.

## Testing 

### Email Integration

After configuing your email in the `.env` you can run the end to end email test with: 

```sh
set -a && source apps/shape-tree-web/.env && set +a && SMTP_INTEGRATION_TEST=true swift test --package-path apps/shape-tree-web --filter LoginFlowIntegrationTests
```
