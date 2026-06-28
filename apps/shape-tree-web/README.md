# shape-tree-web

Swift Hummingbird server + WASM frontend (JavaScriptKit). Part of the [shape-tree](../../) monorepo.

## Build & run

Requires [bun](https://bun.com/), [Swift with WASM SDK](https://www.swift.org/install/macos/), and [binaryen](https://github.com/WebAssembly/binaryen).

```sh
cd apps/shape-tree-web
cp .env.example .env
swift run ShapeTreeWeb
# open http://127.0.0.1:8080
```

`swift run ShapeTreeWeb` builds the WASM frontend via `shape-tree-web-builder` unless `SKIP_SHAPE_TREE_WEB_BUILD=1`.

## Docker

From the repo root:

```sh
./scripts/docker-build.sh up
# web -> http://127.0.0.1:42069
```

The web image builds WASM + server inside Docker (self-contained `Dockerfile`).

## Frontend

WASM products live in `frontend/` (`Entry`, `FitViewer`, `ArticleViewer`). Bun bundles bootstrap JS into `dist/`.

```sh
cd frontend
bun install
cd ..
swift run shape-tree-web-builder   # or let ShapeTreeWeb run it at startup
```
