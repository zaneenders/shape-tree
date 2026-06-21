import { init } from "./index.js";

function pageTitleFromSite(siteTitle, pageTitle) {
  return pageTitle ? `${pageTitle} · ${siteTitle}` : siteTitle;
}

function readSiteTitle() {
  return document.querySelector("title")?.dataset?.siteTitle ?? "";
}

function setLoading(active) {
  const indicator = document.getElementById("htmx-loading");
  indicator?.classList.toggle("htmx-request", active);
}

function navBranchID(directory) {
  return `nav-${directory.toLowerCase().replace(/\//g, "-").replace(/ /g, "-")}`;
}

function appendContentItem(list, item, homeSlug) {
  const leaf = document.createElement("li");
  leaf.className = "nav-leaf";
  const link = document.createElement("a");
  link.className = item.hasWasm ? "nav-link nav-wasm-link" : "nav-link";
  link.href = item.href;
  link.textContent = item.title;
  if (item.hasWasm) {
    link.dataset.wasmSlug = item.slug;
    link.dataset.wasmTitle = item.title;
    if (item.slug === homeSlug) {
      link.dataset.wasmPath = "/";
    }
  }
  leaf.appendChild(link);
  list.appendChild(leaf);
}

function renderNav(payload) {
  const nav = document.getElementById("styled-navigation");
  if (!nav) return;

  nav.replaceChildren();
  const list = document.createElement("ul");
  list.className = "nav-root";
  const homeSlug = document.body?.dataset?.homeSlug ?? payload.home?.slug;

  appendContentItem(list, payload.home, homeSlug);

  if (payload.signIn) {
    const leaf = document.createElement("li");
    leaf.className = "nav-leaf";
    const link = document.createElement("a");
    link.className = "nav-link";
    link.href = payload.signIn.href;
    link.textContent = payload.signIn.label;
    leaf.appendChild(link);
    list.appendChild(leaf);
  }

  for (const group of payload.groups ?? []) {
    const branch = document.createElement("li");
    branch.className = "nav-branch";
    const branchID = navBranchID(group.directory ?? group.label);
    const input = document.createElement("input");
    input.type = "checkbox";
    input.className = "nav-disclosure";
    input.id = branchID;
    const label = document.createElement("label");
    label.className = "nav-branch-label";
    label.htmlFor = branchID;
    label.textContent = group.label;
    const flyout = document.createElement("ul");
    flyout.className = "nav-flyout";
    for (const item of group.items ?? []) {
      appendContentItem(flyout, item, homeSlug);
    }
    branch.append(input, label, flyout);
    list.appendChild(branch);
  }

  nav.appendChild(list);
}

async function fetchAndRenderNav() {
  const response = await fetch("/api/get-nav-content", { credentials: "include" });
  if (!response.ok) {
    console.error("[wasm-nav] nav fetch failed", response.status);
    return;
  }
  renderNav(await response.json());
}

const shapeTree = {
  refreshNav: fetchAndRenderNav,

  async loadNotFound({ pushState = true, path = location.pathname } = {}) {
    const main = document.getElementById("main");
    if (!main) return;
    setLoading(true);
    try {
      main.innerHTML = "<article><h1>404</h1><p>Page not found.</p></article>";
      document.title = pageTitleFromSite(readSiteTitle(), "Not Found");
      if (pushState) {
        history.pushState({ notFound: true, path }, "", path);
      }
    } finally {
      setLoading(false);
    }
  },

  async loadWasmPost(slug, { pushState = true, title = null, path = null } = {}) {
    const main = document.getElementById("main");
    if (!main) return;
    main.innerHTML = "<p>Loading…</p>";
    setLoading(true);
    const wasmPath = `/wasm/wasms/${encodeURIComponent(slug)}`;
    const postPath = path ?? `/wasm/posts/${encodeURIComponent(slug)}`;
    try {
      const response = await fetch(wasmPath, { cache: "no-store", credentials: "include" });
      if (response.status === 404) {
        await shapeTree.loadNotFound({ pushState, path: postPath });
        return;
      }
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      await init({ module: response });
      const pageTitle = title ?? slug;
      document.title = pageTitleFromSite(readSiteTitle(), pageTitle);
      if (pushState) {
        history.pushState({ wasmSlug: slug, title: pageTitle }, "", postPath);
      }
    } catch (err) {
      main.innerHTML = `<p style="color:red">WASM load failed: ${err.message}</p>`;
      console.error("[wasm-post] load failed", err);
    } finally {
      setLoading(false);
    }
  },
};

globalThis.shapeTree = shapeTree;

window.addEventListener("popstate", (event) => {
  const state = event.state;
  if (state?.wasmSlug) {
    void shapeTree.loadWasmPost(state.wasmSlug, {
      pushState: false,
      title: state.title ?? null,
      path: state.path ?? null,
    });
  } else if (state?.notFound) {
    void shapeTree.loadNotFound({
      pushState: false,
      path: state.path ?? location.pathname,
    });
  }
});

async function boot() {
  if (!window.__shapeTreeWasmNav) {
    window.__shapeTreeWasmNav = true;
    await init({
      module: fetch("/assets/client/WASMNav.wasm", { cache: "no-store" }),
    });
  }

  await fetchAndRenderNav();

  const body = document.body;
  const bootSlug = body?.dataset?.initialWasmSlug;
  if (bootSlug) {
    const bootTitle = body?.dataset?.initialWasmTitle ?? null;
    history.replaceState({ wasmSlug: bootSlug, title: bootTitle }, "", location.pathname);
    await shapeTree.loadWasmPost(bootSlug, { pushState: false, title: bootTitle });
    return;
  }

  if (body?.dataset?.bootNotFound === "true") {
    await shapeTree.loadNotFound({ pushState: false, path: location.pathname });
    return;
  }

  const homeSlug = body?.dataset?.homeSlug;
  if (homeSlug && (location.pathname === "/" || location.pathname === "")) {
    const homeTitle = body?.dataset?.homeTitle ?? null;
    history.replaceState({ wasmSlug: homeSlug, title: homeTitle, path: "/" }, "", "/");
    await shapeTree.loadWasmPost(homeSlug, {
      pushState: false,
      title: homeTitle,
      path: "/",
    });
  }
}

if (document.body) {
  void boot();
} else {
  document.addEventListener("DOMContentLoaded", () => { void boot(); });
}
