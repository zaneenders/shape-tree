# shape-tree-web

Swift Hummingbird server + WASM frontend (JavaScriptKit). Part of the [shape-tree](../../) monorepo.

## Build & run

The server **requires** Postgres + SMTP to start (auth is not optional). To run locally with
the monorepo's backing services:

```
docker compose up postgres -d
```

`docker compose up` works zero-setup — defaults are baked into `apps/shape-tree-web/Dockerfile`. For
native `swift run ShapeTreeWeb`, export the environment variables you need (see Configuration below);
the defaults the Dockerfile ships (`HOSTNAME=0.0.0.0`, `STATIC_ROOT=/app/dist`, `SKIP_SHAPE_TREE_WEB_BUILD=1`)
target the Docker image, so for native runs set at least `HOSTNAME=127.0.0.1`, `STATIC_ROOT=dist`,
`SKIP_SHAPE_TREE_WEB_BUILD=0`, and a `SITE_URL` matching the port you'll bind.

For traces, also `docker compose up jaeger -d` — or set `OTEL_SDK_DISABLED=true` to skip.

## Configuration

| Variable | Default (Dockerfile) | Description |
|---|---|---|
| `HOSTNAME` | `0.0.0.0` | Bind address. Use `127.0.0.1` for native `swift run`. |
| `PORT` | `8080` | Listener port. |
| `STATIC_ROOT` | `/app/dist` | Path to the built static assets (WASM/JS). For native run, use `dist`. |
| `SKIP_SHAPE_TREE_WEB_BUILD` | `1` | `1` = assets already built (Docker / pre-built); `0` = build on `swift run`. |
| `OTEL_HOST` | `0.0.0.0` | Admin/metrics bind address. |
| `OTEL_PORT` | `42070` | Admin/metrics listener port. |
| `SITE_URL` | _(none — set always)_ | Public URL used in magic-link emails. |
| `CONTENT_PATH` | `~/content` | Path to markdown content (`Articles/`, `Favorites/`). |
| `INDEX_PATH` | `Home` | Slug of the home page markdown file. |
| `AUTH_PRIVATE_DIRECTORIES` | _(none)_ | Comma-separated content subdirectories protected behind email login. |
| `INDEX_PATH` | _(none)_ | Slug of the home page (e.g. `Home`). |
| `PGHOST` / `PGPORT` / `PGUSER` / `PGPASSWORD` / `PGDATABASE` / `PGSSLMODE` | _(none)_ | Postgres connection. For `docker compose`, defaults are set in `docker-compose.yml` (`PGHOST=postgres`, etc.). |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` / `SMTP_FROM` / `SMTP_TLS` | _(none)_ | SMTP relay for magic-link login emails. **Required for startup.** |
| `AUTH_TOKEN_TTL_MINUTES` | `15` | Magic-link token lifetime. |
| `AUTH_SESSION_TTL_HOURS` | `336` | Session lifetime (14 days). |
| `OTEL_SERVICE_NAME` | `shape-tree-web` | OpenTelemetry service name. |
| `OTEL_EXPORTER_OTLP_BASE_ENDPOINT` | `http://jaeger:4318` | OTLP exporter base URL. |
| `OTEL_SDK_DISABLED` | `false` | Set `true` to skip trace export. |
| `SWIFT_SDK_ID` | `swift-6.3.2-RELEASE_wasm-embedded` | WASM SDK id used by `shape-tree-web-builder` when `SKIP_SHAPE_TREE_WEB_BUILD=0`. |

System environment variables override Dockerfile `ENV` defaults at runtime (in Docker, the
`docker-compose.yml` `environment:` block and the `env_file:` file both override Dockerfile `ENV`).

## Provisioning a login user

The Postgres defaults match `docker-compose.yml` (host `postgres`, db/user/pass
`shape_tree`). Run it natively against the compose-backed Postgres (exposed on
`127.0.0.1:5432`):

```sh
PGHOST=127.0.0.1 PGPORT=5432 \
PGUSER=shape_tree PGPASSWORD=shape_tree PGDATABASE=shape_tree PGSSLMODE=disable \
  swift run --package-path apps/shape-tree-web shape-tree-add-user <email>
```

This runs any pending migrations, then inserts the user. It skips insertion (and
logs a notice) if the email already exists. The `PG*` vars are read from the
environment or a `.env` file in the working directory.

## Testing 

### Email Integration

After configuring your SMTP credentials as environment variables (see the table above), run the end
to end email test with: 

```sh
set -a \
  && export SMTP_HOST=... SMTP_PORT=587 SMTP_USERNAME=... SMTP_PASSWORD=... SMTP_FROM=... \
  && SMTP_INTEGRATION_TEST=true swift test --package-path apps/shape-tree-web --filter LoginFlowIntegrationTests
```
