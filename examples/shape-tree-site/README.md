# Example site for ShapeTree Web

Demo markdown → wasm pipeline and sample content. This is **not** part of the framework — it shows how to author pages that the server serves from `CONTENT_PATH`.

## Layout

```
examples/shape-tree-site/
  content-src/          # markdown source (committed)
  content/              # generated wasm output (gitignored)
  wasm-post/            # compile workspace + ContentGenerator
  Scripts/build-site.sh
```

## Build

Requires the wasm embedded SDK and binaryen (same as the framework — see `apps/shape-tree-web/README.md`).

```bash
./Scripts/build-site.sh
```

Output lands in `content/`. Point the server at it:

```bash
# apps/shape-tree-web/.env
CONTENT_PATH=../../examples/shape-tree-site/content
```

Or use an absolute path.

## Custom WASM pages

Interactive pages without a `.md` file live in `wasm-post/Sources/CustomPages/`. Register in `wasm-post/custom-pages.manifest`:

```
Page_Canvas=Apps/Canvas
```

Then rerun `./Scripts/build-site.sh`.

## Environment

Copy `.env.example` to `.env` to override defaults:

| Variable | Default |
|----------|---------|
| `CONTENT_SOURCE_PATH` | `content-src` (relative to this directory) |
| `CONTENT_OUTPUT` | `content` |
| `INDEX_PATH` | `Home` |
| `LOGIN_SLUG` | `login` (skipped at wasm build; login UI is in ShapeTreeCore) |

## Docker

`./scripts/docker-build.sh` from the repo root runs `build-core.sh` + `build-site.sh`, then copies `content/` into the image at `/content`.
