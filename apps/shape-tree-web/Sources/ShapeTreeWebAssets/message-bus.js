/**
 * Routes typed messages between the shell wasm instance and the active page wasm instance.
 */

/** @type {Record<string, unknown> | null} */
let shellExports = null;

/** @type {Record<string, unknown> | null} */
let activePageExports = null;

/** @type {string | null} */
let activePageURL = null;

/** @param {Record<string, unknown>} exports */
export function registerShell(exports) {
  shellExports = exports;
}

/** @param {Record<string, unknown>} exports @param {string} url */
export function registerPage(exports, url) {
  activePageExports = exports;
  activePageURL = url;
}

export function clearPage() {
  activePageExports = null;
  activePageURL = null;
}

/** @returns {string | null} */
export function activePageUrl() {
  return activePageURL;
}

/** @param {{ kind: string, path?: string, payload?: string }} message */
export function postToShell(message) {
  if (!shellExports?.handlePageMessage) {
    console.warn("[shape-tree] shell not ready for page message", message);
    return;
  }
  shellExports.handlePageMessage(message);
}

/** @param {{ kind: string, payload?: string }} message */
export function sendToPage(message) {
  if (!activePageExports?.handleShellMessage) {
    return;
  }
  activePageExports.handleShellMessage(message);
}
