# shape-tree-web

Markdown site on [Lorikeet](https://github.com/zaneenders/lorikeet) + [Hummingbird](https://github.com/hummingbird-project/hummingbird) with a Swift WASM client. Content is a directory of `.md` files; subdirectories become nav groups.

## Run

```bash
cd apps/shape-tree-web
./Scripts/build-client.sh   # once; needs wasm SDK + binaryen (see below)
cp .env.example .env        # edit if needed; defaults work for local demo
swift run ShapeTreeWeb
```

`CONTENT_PATH` points at your markdown tree (default `Examples/content`). `index.md` → home page; front matter: `title`, `date`, `tags`, `excerpt`.

## Auth (optional)

Set all `PG*` vars (see `.env.example`) to enable passwordless email login. Set `SMTP_*` to send links; without SMTP, links are logged only.

```bash
swift run ShapeTreeWeb --add-user user@example.com
```

`AUTH_PRIVATE_DIRECTORIES` — comma-separated dirs to hide from nav and require sign-in (e.g. `Private`). Optional branded login: add `login.md` to content; `{{login}}` in the body places the form (appended if omitted).

## WASM client build

```bash
swift sdk install \
  https://download.swift.org/swift-6.3.2-release/wasm-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_wasm.artifactbundle.tar.gz \
  --checksum a61f0584c93283589f8b2f42db05c1f9a182b506c2957271402992655591dd7c
brew install binaryen   # wasm-opt; apt: binaryen
./Scripts/build-client.sh
```

## Custom WASM pages

Interactive pages (no `.md` file): `apps/wasm-post/Sources/CustomPages/`. Register in `apps/wasm-post/custom-pages.manifest` (`Page_Canvas=Canvas`) and `AppPages.swift`, then rebuild. Example: **Canvas** (particle field, **Apps** nav group).

## Tests

```bash
swift test
```

Wasm tests need `./Scripts/build-client.sh` first (skip wasm assertions otherwise). `LoginFlowIntegrationTests` needs Postgres + SMTP.
