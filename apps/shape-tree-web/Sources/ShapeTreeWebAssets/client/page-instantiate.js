// @ts-check
import { SwiftRuntime } from "./runtime.js";
// @ts-ignore
import {
  WASI,
  File,
  OpenFile,
  ConsoleStdout,
  PreopenDirectory,
} from "@bjorn3/browser_wasi_shim";

/** @param {Response | Promise<Response> | WebAssembly.Module | ArrayBuffer} moduleSource */
export async function instantiatePage(moduleSource) {
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
  const importObject = {
    javascript_kit: swift.wasmImports,
    wasi_snapshot_preview1: wasi.wasiImport,
  };

  let instance;
  if (moduleSource instanceof WebAssembly.Module) {
    instance = (await WebAssembly.instantiate(moduleSource, importObject))
      .instance;
  } else if (
    typeof Response === "function" &&
    (moduleSource instanceof Response || moduleSource instanceof Promise)
  ) {
    if (typeof WebAssembly.instantiateStreaming === "function") {
      instance = (
        await WebAssembly.instantiateStreaming(moduleSource, importObject)
      ).instance;
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
  wasi.initialize(instance);
  swift.main();
}
