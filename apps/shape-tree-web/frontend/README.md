# ShapeTree frontend

WASM client modules for the ShapeTree web demo.

## Bootstraps

- `entry-bootstrap.ts` — boots the SPA shell (`Entry.wasm`)
- `fit-viewer-bootstrap.ts` — lazy-loads `FitViewer.wasm`
- `articles-viewer-bootstrap.ts` — lazy-loads `ArticlesViewer.wasm`
- `favorites-viewer-bootstrap.ts` — lazy-loads `FavoritesViewer.wasm`

Swift UI logic lives in `Sources/` as WASM executables (`Entry`, `FitViewer`, `ArticlesViewer`, `FavoritesViewer`) sharing `ShapeTreeDOM` and `ContentRendering`.
