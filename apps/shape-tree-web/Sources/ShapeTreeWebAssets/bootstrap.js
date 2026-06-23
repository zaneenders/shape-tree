import { init } from "./index.js";
import { hostImports, shapeTreeHost } from "./host-imports.js";

globalThis.shapeTree = shapeTreeHost;

async function boot() {
  await init({
    module: fetch("/assets/client/ShapeTreeCore.wasm", { cache: "no-store" }),
    getImports: hostImports,
  });
}

function reportBootError(error) {
  console.error("[shape-tree] core boot failed:", error);
  const loading = document.getElementById("site-loading");
  if (loading) {
    loading.textContent = "Failed to load the app. See the browser console for details.";
    loading.classList.add("is-error");
  }
}

if (document.body) {
  void boot().catch(reportBootError);
} else {
  document.addEventListener("DOMContentLoaded", () => {
    void boot().catch(reportBootError);
  });
}
