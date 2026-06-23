// @ts-check
import { SwiftRuntime } from "./runtime.js";
import { pageHostImports } from "./host-imports.js";
// @ts-ignore
import {
  WASI,
  File,
  OpenFile,
  ConsoleStdout,
  PreopenDirectory,
} from "@bjorn3/browser_wasi_shim";

/**
 * @param {Response | Promise<Response> | WebAssembly.Module | ArrayBuffer} moduleSource
 * @param {string} pageURL absolute wasm URL (used to load co-located bridge-js.js)
 */
export async function instantiatePage(moduleSource, pageURL) {
  const bridgeURL = pageURL.replace(/\.wasm$/, ".bridge-js.js");
  const { createInstantiator } = await import(bridgeURL);

  const wasi = new WASI(
    ["page.wasm"],
    [],
    [
      new OpenFile(new File([])),
      ConsoleStdout.lineBuffered((line) => console.log(line)),
      ConsoleStdout.lineBuffered((line) => console.error(line)),
      new PreopenDirectory("/", new Map()),
    ],
    { debug: false },
  );

  const swift = new SwiftRuntime({});
  const instantiator = await createInstantiator(
    {
      module: moduleSource,
      getImports: () => pageHostImports(),
      wasi: Object.assign(wasi, {
        setInstance(instance) {
          wasi.inst = instance;
        },
      }),
    },
    swift,
  );

  const importObject = {
    javascript_kit: swift.wasmImports,
    wasi_snapshot_preview1: wasi.wasiImport,
  };

  const importsContext = {
    getInstance: () => instance,
    getExports: () => exports,
    _swift: swift,
  };
  instantiator.addImports(importObject, importsContext);

  let instance;
  let exports;
  if (moduleSource instanceof WebAssembly.Module) {
    instance = (await WebAssembly.instantiate(moduleSource, importObject)).instance;
  } else if (
    typeof Response === "function" &&
    (moduleSource instanceof Response || moduleSource instanceof Promise)
  ) {
    if (typeof WebAssembly.instantiateStreaming === "function") {
      const result = await WebAssembly.instantiateStreaming(moduleSource, importObject);
      instance = result.instance;
    } else {
      const bytes = await (await moduleSource).arrayBuffer();
      const module = await WebAssembly.compile(bytes);
      instance = (await WebAssembly.instantiate(module, importObject)).instance;
    }
  } else {
    const module = await WebAssembly.compile(moduleSource);
    instance = (await WebAssembly.instantiate(module, importObject)).instance;
  }

  swift.setInstance(instance);
  instantiator.setInstance(instance);
  exports = instantiator.createExports(instance);
  wasi.initialize(instance);
  swift.main();

  return { instance, swift, exports };
}