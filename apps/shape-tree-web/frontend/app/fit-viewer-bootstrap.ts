import { init } from "../.build/plugins/PackageToJS/outputs/FitViewer/index.js";

export async function mountFitViewer(container: HTMLElement) {
  const { exports } = await init({
    module: fetch("/FitViewer.wasm"),
    getImports: () => ({}),
  });
  exports.bootstrap();
  await exports.renderFitViewer(container);
}
