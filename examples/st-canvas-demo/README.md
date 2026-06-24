# ShapeTree Canvas

Interactive particle canvas demo — a hand-written Swift WASM page (no markdown). Built as a standalone package, output copied into the example site's `content/` tree at `Private/Canvas.wasm`.

## Layout

```
examples/st-canvas-demo/
  Package.swift
  Sources/Canvas/Canvas.swift
  meta.json                # {"title":"Canvas"}
  scripts/build.sh         # swift package js + wasm-opt -> dist/
  dist/                    # generated output (gitignored)
```

## Build

Requires the SwiftWasm SDK (`swift-6.3.2-RELEASE_wasm-embedded`) and `wasm-opt` (binaryen).

```bash
./scripts/build.sh
```

Output lands in `dist/Private/Canvas.wasm` (+ `dist/Private/Canvas.meta.json`).

### Environment

| Variable | Default | Description |
|----------|---------|-------------|
| `SWIFT_WASM_SDK` | `swift-6.3.2-RELEASE_wasm-embedded` | SwiftWasm SDK |
| `CONTENT_PATH` | `Private/Canvas` | Output path within `dist/` |

## Integration

`scripts/docker-build.sh` runs `build.sh` separately and copies `dist/*` into `examples/st-gen-markdown/content/`. The page is gated by `AUTH_PRIVATE_DIRECTORIES=Private` on the server.
