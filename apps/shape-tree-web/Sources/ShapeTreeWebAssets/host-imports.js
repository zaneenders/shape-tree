// @ts-check
import {
  clearPage,
  postToShell,
  registerPage,
  registerShell,
  sendToPage,
} from "./message-bus.js";
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
    hostSendToPage(message) {
      sendToPage(message);
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

/** @returns {import('./instantiate.d').Imports} */
export function pageHostImports() {
  return {
    hostPostToShell(message) {
      postToShell(message);
    },
  };
}

export { registerShell, registerPage, clearPage };

export const shapeTreeHost = {
  async mountPageWasm(url) {
    sendToPage({ kind: "teardown" });
    clearPage();

    const response = await fetch(url, { cache: "no-store", credentials: "include" });
    if (response.status === 404) {
      return { ok: false, status: 404 };
    }
    if (!response.ok) {
      throw new Error(`mount ${url}: ${response.status}`);
    }

    const page = await instantiatePage(response, url);
    registerPage(page.exports, url);
    return { ok: true, status: response.status };
  },
};
