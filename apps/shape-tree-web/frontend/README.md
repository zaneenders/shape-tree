# frontend

`app/`

Static assets and TypeScript bootstraps. The entry bundle (`app.js`) is inlined into the HTML shell for a fast first TCP load (target: under 14kb).

- `entry-bootstrap.ts` — loads `Entry.wasm`, boots the SPA shell
- `fit-viewer-bootstrap.ts` — lazy-loads `FitViewer.wasm`
- `article-viewer-bootstrap.ts` — lazy-loads `ArticleViewer.wasm`

Swift UI logic lives in `Sources/` as three WASM executables (`Entry`, `FitViewer`, `ArticleViewer`) sharing the `ShapeTreeDOM` library.
