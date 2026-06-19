# shape-tree-web

Markdown blog built on [Lorikeet](https://github.com/zaneenders/lorikeet) (typed HTML + HTMX) and Hummingbird. Point it at a directory of `.md` files and it serves a readable site with HTMX navigation.

```bash
cd apps/shape-tree-web
swift run ShapeTreeWeb
```

Copy `.env.example` to `.env` and set `CONTENT_PATH` to your markdown directory:

```bash
cp .env.example .env
```

Process environment variables override `.env` values. You can still pass overrides on the command line:

```bash
CONTENT_PATH=/path/to/markdown swift run ShapeTreeWeb
```

Environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `HOST` | `127.0.0.1` | Bind address |
| `PORT` | `8080` | Listener port |
| `CONTENT_PATH` | `Examples/content` | Directory of markdown files (scanned recursively) |

Markdown files support `---` front matter (`title`, `date`, `tags`, `excerpt`). An `index.md` file becomes the home page. Other files are listed as posts sorted by date. Files in subdirectories are grouped in navigation and on the index. Sample content lives in `Examples/content/`.

## Client interactivity (JavaScriptKit)

Navigation flyouts close on click-away, link selection, and Escape. The Swift source lives in `WASMClient/`; the site loads a small wasm module via JavaScriptKit at `/assets/nav-client/*` (with `nav-dismiss.js` as a fallback when wasm assets are missing).

Install the official wasm SDK bundle, then rebuild:

```bash
swift sdk install \
  https://download.swift.org/swift-6.3.2-release/wasm-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_wasm.artifactbundle.tar.gz \
  --checksum a61f0584c93283589f8b2f42db05c1f9a182b506c2957271402992655591dd7c

brew install binaryen   # wasm-opt; strongly recommended
chmod +x Scripts/build-client.sh
./Scripts/build-client.sh
```

`./Scripts/build-client.sh` builds `WASMClient` with the `_wasm-embedded` SDK only (no WASI fallback). Do **not** set `JAVASCRIPTKIT_EXPERIMENTAL_EMBEDDED_WASM=true` — it skips reactor linker flags and breaks browser event listeners. Requires `wasm-opt` (`brew install binaryen`). Expect a ~60 KB wasm module after `wasm-opt -Oz`.

After `./Scripts/build-client.sh`, run `swift build` to embed assets. The server can serve `/assets/nav-client/*` from embedded blobs if you wire the module script back into `Pages.swift`.

## Testing

```bash
swift test
```
