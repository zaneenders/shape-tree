# shape-tree-web

Jekyll-inspired markdown blog built on [Lorikeet](https://github.com/zaneenders/lorikeet) (typed HTML + HTMX) and Hummingbird. Point it at a directory of `.md` files and it serves a readable site with HTMX navigation.

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

Markdown files support Jekyll-style `---` front matter (`title`, `date`, `tags`, `excerpt`). An `index.md` file becomes the home page; other files are listed as posts sorted by date. Sample content lives in `Examples/content/`.

## Testing

```bash
swift test
```
