import { init } from "../.build/plugins/PackageToJS/outputs/Entry/index.js";

// import() is only valid in module code; Entry.wasm calls this for lazy chunks.
globalThis.loadESModule = (url: string) => import(url);

const { exports } = await init({
  module: fetch("/Entry.wasm"),
  getImports: () => ({}),
});
exports.bootstrap();
exports.renderApp();
