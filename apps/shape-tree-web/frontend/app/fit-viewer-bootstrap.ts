import { init } from "../.build/plugins/PackageToJS/outputs/FitViewer/index.js";

type FitViewerExports = Awaited<ReturnType<typeof init>>["exports"];

let fitViewer: FitViewerExports | null = null;

async function loadFitViewer(): Promise<FitViewerExports> {
  if (fitViewer) {
    return fitViewer;
  }
  const { exports } = await init({
    module: fetch("/FitViewer.wasm"),
    getImports: () => ({}),
  });
  exports.bootstrap();
  fitViewer = exports;
  return exports;
}

export async function mountFitViewer(container: HTMLElement) {
  const exports = await loadFitViewer();
  await exports.renderFitViewer(container);
}

export function teardownFitViewer() {
  fitViewer?.teardownFitViewer();
}
