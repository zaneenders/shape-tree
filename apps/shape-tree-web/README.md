# shape-tree-web

Wasm host on [Lorikeet](https://github.com/zaneenders/lorikeet) + [Hummingbird](https://github.com/hummingbird-project/hummingbird). Serves a unified HTML shell, embeds `ShapeTreeCore.wasm` for client routing/nav/auth, and reads page modules from a content directory on disk.

## Run

```bash
cd apps/shape-tree-web
./Scripts/build-core.sh        # embed ShapeTreeCore.wasm (required once)
cp .env.example .env
swift run ShapeTreeWeb
```

Point `CONTENT_PATH` at a directory of `*.wasm` files (see [examples/shape-tree-site](../../examples/shape-tree-site) to build demo content).

## Environment

| Variable | Purpose |
|----------|---------|
| `CONTENT_PATH` | Runtime wasm/css tree |
| `INDEX_PATH` | Home page path within the content tree (default `Home`) |
| `SITE_TITLE` | Optional site title override |
| `AUTH_PRIVATE_DIRECTORIES` | Comma-separated dirs hidden from nav until sign-in |

**URLs**

- `/` — home (same HTML shell as content pages)
- `/content/Articles/new-mac` — shell; Core loads `/content/Articles/new-mac.wasm`
- `/api/get-nav-content` — auth-aware nav JSON

## Auth (optional)

Set all `PG*` vars (see `.env.example`) to enable passwordless email login. Set `SMTP_*` to send links; without SMTP, links are logged only.

```bash
swift run ShapeTreeWeb --add-user user@example.com
```

Optional branded login: add `login.md` to your **site build** source; login UI still lives in ShapeTreeCore.

## WASM client build

```bash
swift sdk install \
  https://download.swift.org/swift-6.3.2-release/wasm-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_wasm.artifactbundle.tar.gz \
  --checksum a61f0584c93283589f8b2f42db05c1f9a182b506c2957271402992655591dd7c
brew install binaryen   # wasm-opt; apt: binaryen
./Scripts/build-core.sh
```

`build-client.sh` runs `build-core.sh` plus the example site build for convenience.

## Example site

Demo markdown → wasm pipeline lives in [`examples/shape-tree-site`](../../examples/shape-tree-site) — not part of this package.

## Docker

From the repo root:

```bash
./scripts/docker-build.sh up
```

Builds core wasm + example site content, copies `examples/shape-tree-site/content` to `/content` in the image.

## Tests

```bash
swift test
```

`LoginFlowIntegrationTests` needs Postgres + SMTP.
