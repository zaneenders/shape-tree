# shape-tree-web

Markdown blog built on the [Lorikeet](https://github.com/zaneenders/lorikeet) HTML DSL (typed HTML + HTMX), [Hummingbird](https://github.com/hummingbird-project/hummingbird), and a Swift WASM client. Point it at a directory of `.md` files and it serves a readable site with HTMX-powered navigation — no JavaScript build step required.

Build the swift WASM client, then start the server using the bundled `.env.example` (no `.env` needed to try it out):

```bash
cd apps/shape-tree-web
./Scripts/build-client.sh
```

### Tests

```bash
swift test
```

Wasm-related tests (`PrivateWasmPostTests`, `PostWasmAssetTests`) need embedded artifacts from `./Scripts/build-client.sh`. If you run `swift test` without that step, those tests record an issue and skip the wasm assertions rather than failing the whole suite.

Integration tests for email login require Postgres and SMTP — see `LoginFlowIntegrationTests` in the test source.

## Setup 

### Environment

For local development, source `.env.example` directly into your shell:

Only create a `.env` file when deploying or when you need values that differ from the defaults (e.g. Postgres/SMTP for login):

```bash
cp .env.example .env
# edit .env with your real values
```

Environment variables (all required):

| Variable | Purpose |
|----------|---------|
| `HOST` | Bind address |
| `PORT` | Listener port |
| `CONTENT_PATH` | Directory of markdown files (scanned recursively) |

`.env.example` includes sample values for local development (`127.0.0.1`, `42069`, `Examples/content`).

### Optional: email login and private directories

To enable passwordless email login for protected content, set all `PG*` variables and run with the included `postgres` service (see `docker-compose.yml`). SMTP settings are required to actually send login links; without them the server logs each login link but does not send email.

| Variable | Purpose |
|----------|---------|
| `SITE_URL` | Public URL used in login links (defaults to `http://HOST:PORT`) |
| `AUTH_PRIVATE_DIRECTORIES` | Comma-separated content directories to protect (e.g. `Private,Notes/Secret`) |
| `PGHOST` / `PGPORT` / `PGUSER` / `PGPASSWORD` / `PGDATABASE` | Postgres connection |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` / `SMTP_FROM` | SMTP relay for login links |

Add allowed users with:

```bash
swift run ShapeTreeWeb --add-user user@example.com
```

Posts inside a private directory are hidden from navigation and require signing in to view.

### Optional: custom login page

By default the `/login` page is a built-in form. To brand it with your own copy, add a `login.md` file to your content directory (the slug defaults to `login`, matched case-insensitively). The file's front matter `title` becomes the heading and its rendered body wraps the login form. Place a `{{login}}` marker anywhere in the body to control where the email field is rendered; if the marker is absent the form is appended to the body. The login post is excluded from the index and navigation, and `/posts/login` redirects to `/login`. When no `login.md` exists, the built-in shell is used.


Markdown files support `---` front matter (`title`, `date`, `tags`, `excerpt`). An `index.md` file becomes the home page. Other files are listed as posts sorted by date. Files in subdirectories are grouped in navigation and on the index. Sample content lives in `Examples/content/`.

### Swift WASM

Installed the sdk and binaryen to build the WASM client correctly.

```bash
swift sdk install \
  https://download.swift.org/swift-6.3.2-release/wasm-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_wasm.artifactbundle.tar.gz \
  --checksum a61f0584c93283589f8b2f42db05c1f9a182b506c2957271402992655591dd7c

brew install binaryen   # for wasm-opt to reduce binary size
# Linux (apt):
# sudo apt install binaryen
chmod +x Scripts/build-client.sh
./Scripts/build-client.sh
```

