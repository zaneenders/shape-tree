# shape-tree-web

Markdown site on [Lorikeet](https://github.com/zaneenders/lorikeet) + [Hummingbird](https://github.com/hummingbird-project/hummingbird) with a Swift WASM client. At build time, markdown is compiled into per-page `.wasm` modules on disk; at runtime the server serves them under `/content/**`.

## Run

```bash
cd apps/shape-tree-web
./Scripts/build-client.sh   # once; needs wasm SDK + binaryen (see below)
cp .env.example .env        # edit if needed; defaults work for local demo
swift run ShapeTreeWeb
```

**Environment**

| Variable | Purpose |
|----------|---------|
| `CONTENT_PATH` | Runtime wasm/css tree (default `content`, relative to repo root) |
| `CONTENT_SOURCE_PATH` | Build-only markdown source for `./Scripts/build-client.sh` (default `Examples/content`) |
| `INDEX_PATH` | Home page path within the content tree (default `Home`) |
| `SITE_TITLE` | Optional site title override |

`index.md` → home page; front matter: `title`, `date`, `tags`, `excerpt`. Output layout mirrors source paths (`Articles/new-mac.md` → `content/Articles/new-mac.wasm`).

**URLs**

- `/` — home (same HTML shell as content pages)
- `/content/Articles/new-mac` — HTML shell; Core loads `/content/Articles/new-mac.wasm`
- `/api/get-nav-content` — auth-aware nav JSON

## Auth (optional)

Set all `PG*` vars (see `.env.example`) to enable passwordless email login. Set `SMTP_*` to send links; without SMTP, links are logged only.

```bash
swift run ShapeTreeWeb --add-user user@example.com
```

`AUTH_PRIVATE_DIRECTORIES` — comma-separated dirs to hide from nav and require sign-in (e.g. `Private`). Optional branded login: add `login.md` to content source; `{{login}}` in the body places the form (appended if omitted).

## WASM client build

```bash
swift sdk install \
  https://download.swift.org/swift-6.3.2-release/wasm-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_wasm.artifactbundle.tar.gz \
  --checksum a61f0584c93283589f8b2f42db05c1f9a182b506c2957271402992655591dd7c
brew install binaryen   # wasm-opt; apt: binaryen
./Scripts/build-client.sh
```

## Custom WASM pages

Interactive pages (no `.md` file): `apps/wasm-post/Sources/CustomPages/`. Register in `apps/wasm-post/custom-pages.manifest` (`Page_Canvas=Apps/Canvas`), then rebuild. Example: **Canvas** (particle field, **Apps** nav group).

## Docker

From the repo root:

```bash
./scripts/docker-build.sh up
```

`build-client.sh` runs first, output goes to `apps/shape-tree-web/content/`, and the image copies that tree to `/content` with `CONTENT_PATH=/content`.

## Tests

```bash
swift test
```

Wasm tests need `./Scripts/build-client.sh` first (skip wasm assertions otherwise). `LoginFlowIntegrationTests` needs Postgres + SMTP.
