import { init } from "../.build/plugins/PackageToJS/outputs/FavoritesViewer/index.js";

export async function mountFavoritesViewer(container: HTMLElement) {
  const { exports } = await init({
    module: fetch("/FavoritesViewer.wasm"),
    getImports: () => ({}),
  });
  exports.bootstrap();
  await exports.renderFavoritesViewer(container);
}
