// @ts-check
import { instantiatePage } from "./page-instantiate.js";

/** @returns {import('./instantiate.d').Imports} */
export function hostImports() {
  return {
    hostFetchJSON(url, completion) {
      fetch(url, { credentials: "include" })
        .then((response) => (response.ok ? response.json() : null))
        .then((json) => completion(json))
        .catch(() => completion(null));
    },
    hostMountModule(url, completion) {
      globalThis.shapeTree
        .mountPageWasm(url)
        .then((result) => completion(result.ok, result.status))
        .catch(() => completion(false, 0));
    },
    encodeURIComponent(value) {
      return globalThis.encodeURIComponent(value);
    },
    decodeURIComponent(value) {
      return globalThis.decodeURIComponent(value);
    },
    createURLSearchParams(search) {
      return new URLSearchParams(search);
    },
  };
}

// Page wasm uses classic JavaScriptKit (no BridgeJS imports).
export const shapeTreeHost = {
  async mountPageWasm(url) {
    const response = await fetch(url, { cache: "no-store", credentials: "include" });
    if (response.status === 404) {
      return { ok: false, status: 404 };
    }
    if (!response.ok) {
      throw new Error(`mount ${url}: ${response.status}`);
    }
    await instantiatePage(response);
    return { ok: true, status: response.status };
  },
};
