import { init } from "../.build/plugins/PackageToJS/outputs/ArticlesViewer/index.js";

export async function mountArticlesViewer(container: HTMLElement) {
  const { exports } = await init({
    module: fetch("/ArticlesViewer.wasm"),
    getImports: () => ({}),
  });
  exports.bootstrap();
  await exports.renderArticlesViewer(container);
}
