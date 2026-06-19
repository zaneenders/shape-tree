# shape-tree-web

Markdown blog built on [Lorikeet](https://github.com/zaneenders/lorikeet) (typed HTML + HTMX) and Hummingbird. Point it at a directory of `.md` files and it serves a readable site with HTMX navigation.

Build the swift WASM client then start the server.
```bash
cd apps/shape-tree-web
./Scripts/build-client.sh
swift run ShapeTreeWeb
```

## Setup 

### Environment

Copy `.env.example` to `.env` and set `CONTENT_PATH` to your markdown directory:

```bash
cp .env.example .env
```

Environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `HOST` | `127.0.0.1` | Bind address |
| `PORT` | `8080` | Listener port |
| `CONTENT_PATH` | `Examples/content` | Directory of markdown files (scanned recursively) |


Markdown files support `---` front matter (`title`, `date`, `tags`, `excerpt`). An `index.md` file becomes the home page. Other files are listed as posts sorted by date. Files in subdirectories are grouped in navigation and on the index. Sample content lives in `Examples/content/`.

### Swift WASM

Installed the sdk and binaryen to build the WASMClient correctly.

```bash
swift sdk install \
  https://download.swift.org/swift-6.3.2-release/wasm-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_wasm.artifactbundle.tar.gz \
  --checksum a61f0584c93283589f8b2f42db05c1f9a182b506c2957271402992655591dd7c

brew install binaryen   # for wasm-opt to reduce binary size
chmod +x Scripts/build-client.sh
./Scripts/build-client.sh
```

