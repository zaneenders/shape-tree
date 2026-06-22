import { init } from "./index.js";

// The only thing JS does: instantiate wasm modules. Routing, nav rendering, auth
// chrome, and history all live in ShapeTreeCore.wasm. Node wasms render into #main.
globalThis.shapeTree = {
  async mount(url) {
    const response = await fetch(url, { cache: "no-store", credentials: "include" });
    if (response.status === 404) {
      return { ok: false, status: 404 };
    }
    if (!response.ok) {
      throw new Error(`mount ${url}: ${response.status}`);
    }
    await init({ module: response });
    return { ok: true, status: response.status };
  },
};

async function boot() {
  await init({
    module: fetch("/assets/client/ShapeTreeCore.wasm", { cache: "no-store" }),
  });
}

if (document.body) {
  void boot();
} else {
  document.addEventListener("DOMContentLoaded", () => {
    void boot();
  });
}
