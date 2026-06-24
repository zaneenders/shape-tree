# Example site for ShapeTree Web

Demo markdown → wasm pipeline and sample content. This is **not** part of the framework — it shows how to author pages that the server serves from `CONTENT_PATH`.

## Layout

```
examples/
  content-src/              # markdown source for all demo pages (committed)
  st-gen-markdown/
    Package.swift           # SwiftPM manifest (static — only BuildPage target)
    Sources/
      BuildPage/            # Swift CLI tool: md → wasm
    content/                # generated wasm output (gitignored)
```

Hand-written interactive pages (e.g. Canvas) live in a separate package at `examples/st-canvas-demo/` and are copied into `content/` by `scripts/docker-build.sh`.

## Build

Requires the SwiftWasm SDK (`swift-6.3.2-RELEASE_wasm-embedded`) and `wasm-opt` (binaryen) — same toolchain as the framework (see `apps/shape-tree-web/README.md`).

Build the tool, then build a single page:

```bash
swift build --product BuildPage
.build/debug/BuildPage ../content-src/Home.md
```

Output lands in `content/<path>.wasm` (+ `<path>.meta.json`). Add `-v` for verbose subprocess output. Point the server at it:

```bash
# apps/shape-tree-web/.env
CONTENT_PATH=../../examples/st-gen-markdown/content
```

Build all pages (used by `scripts/docker-build.sh`):

```bash
swift build --product BuildPage
find ../content-src -name '*.md' -print0 \
  | while IFS= read -r -d '' md; do .build/debug/BuildPage "$md"; done
```

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `--package-root <path>` | current directory | Package root |
| `--sdk <name>` | `$SWIFT_WASM_SDK` or `swift-6.3.2-RELEASE_wasm-embedded` | SwiftWasm SDK to build with |
| `--content-src <path>` | `../content-src` | Root used to derive the content path |
| `--output <path>` | `content` | Where to write `.wasm` + `.meta.json` |
| `--login-slug <slug>` | `login` | Slug to skip (login UI lives in ShapeTreeCore) |
| `-v`, `--verbose` | off | Print subprocess output and detailed progress |

## How it works

1. Reads the `.md` file, parses front matter (title, date) and markdown body via [swift-markdown](https://github.com/apple/swift-markdown)
2. Renders the body to HTML and emits a `@main` Swift executable that sets `#main.innerHTML` at runtime
3. Writes a throwaway mini-package to `.build/wasm/page-pkg/` (Package.swift + Sources/Page/Page.swift) — the SPM cache persists between runs so only `Page.swift` is recompiled
4. Shells out to `swift package js --product Page --swift-sdk <sdk>` in the temp package (separate `--scratch-path` avoids workspace lock conflicts)
5. Optimizes the `.wasm` with `wasm-opt -Oz --strip-debug --strip-producers`
6. Copies the `.wasm` (renamed from `Page.wasm` to `<contentPath>.wasm`) and `.meta.json` into `content/`

## Docker

`./scripts/docker-build.sh` from the repo root runs `build-core.sh`, builds the `BuildPage` tool and loops over every `examples/content-src/*.md` through it, builds the Canvas package separately and copies its output into `content/`, then copies `content/` into the image at `/content`.
