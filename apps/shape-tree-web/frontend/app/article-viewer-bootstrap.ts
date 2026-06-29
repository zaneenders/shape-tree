import { init } from "../.build/plugins/PackageToJS/outputs/ArticleViewer/index.js";

export async function mountArticleViewer(container: HTMLElement) {
  const { exports } = await init({
    module: fetch("/ArticleViewer.wasm"),
    getImports: () => ({}),
  });
  exports.bootstrap();
  await exports.renderArticleViewer(container);
}
