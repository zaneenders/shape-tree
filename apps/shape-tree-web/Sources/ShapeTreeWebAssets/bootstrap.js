import { init } from "./index.js";

function pageTitleFromSite(siteTitle, pageTitle) {
  return pageTitle ? `${pageTitle} · ${siteTitle}` : siteTitle;
}

function readSiteTitle() {
  return document.querySelector("title")?.dataset?.siteTitle ?? "";
}

function setLoading(active) {
  const indicator = document.getElementById("site-loading");
  const main = document.getElementById("main");
  indicator?.classList.toggle("is-loading", active);
  main?.classList.toggle("is-loading", active);
}

function navBranchID(directory) {
  return `nav-${directory.toLowerCase().replace(/\//g, "-").replace(/ /g, "-")}`;
}

function escapeHTML(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function escapeAttr(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;");
}

function loginFormHTML(next) {
  const nextField = next
    ? `<input type="hidden" name="next" value="${escapeAttr(next)}">`
    : "";
  return `<form class="login-form" method="post" action="/auth/login">
<label for="login-email">Email</label>
<input id="login-email" name="email" type="email" autocomplete="email" required>
${nextField}
<button type="submit">Send link</button>
</form>`;
}

function checkEmailHTML() {
  return `<article>
<h1>Check your email</h1>
<p>If your address is allowed, you will receive a sign-in link shortly.</p>
<p><a href="/login" class="login-back-link">Back to sign in</a></p>
</article>`;
}

function verifyFormHTML(token, next) {
  const nextField = next
    ? `<input type="hidden" name="next" value="${escapeAttr(next)}">`
    : "";
  return `<form class="verify-form" method="post" action="/auth/verify">
<input type="hidden" name="token" value="${escapeAttr(token)}">
${nextField}
<button type="submit">Sign in</button>
</form>`;
}

function verifyConfirmHTML(token, next) {
  return `<article>
<h1>Confirm sign in</h1>
<p>Click below to finish signing in on this device.</p>
${verifyFormHTML(token, next)}
</article>`;
}

function verifyFailedHTML() {
  return `<article>
<h1>Link expired or invalid</h1>
<p>This sign-in link may have expired or already been used.</p>
<p><a href="/login" class="nav-login-link">Request a new link</a></p>
</article>`;
}

function renderLoginArticle(payload) {
  const next = payload.next ?? null;
  const bodyHTML = payload.bodyHTML ?? "";
  return `<article>
<h1>${escapeHTML(payload.title)}</h1>
<div class="post-body">${bodyHTML}</div>
${loginFormHTML(next)}
</article>`;
}

function bindLoginForm(main) {
  const form = main.querySelector("form.login-form");
  if (!form) return;
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    void submitLoginForm(form, main);
  });
}

function bindLoginBackLink(main) {
  const link = main.querySelector("a.login-back-link");
  if (!link) return;
  link.addEventListener("click", (event) => {
    event.preventDefault();
    void shapeTree.loadLogin({ pushState: true, next: null });
  });
}

async function submitLoginForm(form, main) {
  const body = new URLSearchParams(new FormData(form)).toString();
  setLoading(true);
  try {
    const response = await fetch("/auth/login", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      credentials: "include",
      body,
    });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    main.innerHTML = checkEmailHTML();
    document.title = pageTitleFromSite(readSiteTitle(), "Check your email");
    bindLoginBackLink(main);
  } finally {
    setLoading(false);
  }
}

function bindVerifyForm(main) {
  const form = main.querySelector("form.verify-form");
  if (!form) return;
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    void submitVerifyForm(form, main);
  });
}

function bindVerifyFailedLink(main) {
  const link = main.querySelector("a.nav-login-link");
  if (!link) return;
  link.addEventListener("click", (event) => {
    event.preventDefault();
    void shapeTree.loadLogin({ pushState: true, next: null });
  });
}

async function submitVerifyForm(form, main) {
  const body = new URLSearchParams(new FormData(form)).toString();
  setLoading(true);
  try {
    const response = await fetch("/auth/verify", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      credentials: "include",
      body,
    });
    if (response.ok) {
      const payload = await response.json();
      if (payload.redirect) {
        window.location.href = payload.redirect;
        return;
      }
    }
    main.innerHTML = verifyFailedHTML();
    document.title = pageTitleFromSite(readSiteTitle(), "Sign in failed");
    bindVerifyFailedLink(main);
  } finally {
    setLoading(false);
  }
}

function appendContentItem(list, item, homeSlug) {
  const leaf = document.createElement("li");
  leaf.className = "nav-leaf";
  const link = document.createElement("a");
  link.className = "nav-link nav-wasm-link";
  link.href = item.href;
  link.textContent = item.title;
  link.dataset.wasmSlug = item.slug;
  link.dataset.wasmTitle = item.title;
  if (item.slug === homeSlug) {
    link.dataset.wasmPath = "/";
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
    link.className = payload.signIn.spa ? "nav-link nav-login-link" : "nav-link";
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

async function stripSignedInQuery() {
  const params = new URLSearchParams(location.search);
  if (params.get("signed-in") !== "1") return;
  await fetchAndRenderNav();
  params.delete("signed-in");
  const qs = params.toString();
  history.replaceState(
    history.state,
    "",
    location.pathname + (qs ? `?${qs}` : "") + location.hash
  );
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

  async loadLogin({ pushState = true, next = null, path = null } = {}) {
    const main = document.getElementById("main");
    if (!main) return;
    setLoading(true);
    try {
      const query = next ? `?next=${encodeURIComponent(next)}` : "";
      const response = await fetch(`/api/get-login-content${query}`, {
        credentials: "include",
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const payload = await response.json();
      main.innerHTML = renderLoginArticle(payload);
      document.title = pageTitleFromSite(readSiteTitle(), "Sign in");
      bindLoginForm(main);
      const loginPath =
        path ?? (next ? `/login?next=${encodeURIComponent(next)}` : "/login");
      if (pushState) {
        history.pushState({ login: true, next }, "", loginPath);
      }
    } catch (err) {
      main.innerHTML = `<p style="color:red">Login load failed: ${err.message}</p>`;
      console.error("[wasm-login] load failed", err);
    } finally {
      setLoading(false);
    }
  },

  async loadVerify({ token = null, next = null, pushState = true } = {}) {
    const main = document.getElementById("main");
    if (!main) return;
    setLoading(true);
    try {
      if (!token) {
        main.innerHTML = verifyFailedHTML();
        document.title = pageTitleFromSite(readSiteTitle(), "Sign in failed");
        bindVerifyFailedLink(main);
        return;
      }
      main.innerHTML = verifyConfirmHTML(token, next);
      document.title = pageTitleFromSite(readSiteTitle(), "Confirm sign in");
      bindVerifyForm(main);
      if (pushState) {
        const params = new URLSearchParams({ token });
        if (next) params.set("next", next);
        history.pushState(
          { verify: true, token, next },
          "",
          `/auth/verify?${params.toString()}`
        );
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
      main.innerHTML = `<p style="color:red">Content load failed: ${err.message}</p>`;
      console.error("[wasm-post] content load failed", err);
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
  } else if (state?.login) {
    void shapeTree.loadLogin({ pushState: false, next: state.next ?? null });
  } else if (state?.verify) {
    void shapeTree.loadVerify({
      pushState: false,
      token: state.token ?? null,
      next: state.next ?? null,
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
  await stripSignedInQuery();

  const body = document.body;

  if (body?.dataset?.bootLogin === "true") {
    const next = body?.dataset?.loginNext || null;
    history.replaceState({ login: true, next }, "", location.pathname + location.search);
    await shapeTree.loadLogin({ pushState: false, next });
    return;
  }

  if (body?.dataset?.bootVerify === "true") {
    const token = body?.dataset?.verifyToken || null;
    const next = body?.dataset?.verifyNext || null;
    history.replaceState(
      { verify: true, token, next },
      "",
      location.pathname + location.search
    );
    await shapeTree.loadVerify({ pushState: false, token, next });
    return;
  }

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
