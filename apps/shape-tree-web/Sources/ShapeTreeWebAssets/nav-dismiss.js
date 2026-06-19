(function () {
  "use strict";

  if (window.__shapeTreeNavDismiss) {
    return;
  }
  window.__shapeTreeNavDismiss = true;

  function getNav() {
    return document.getElementById("styled-navigation");
  }

  let backdrop = null;

  function backdropEl() {
    if (!document.body) {
      return null;
    }
    if (!backdrop) {
      backdrop = document.createElement("div");
      backdrop.id = "nav-backdrop";
      backdrop.setAttribute("aria-hidden", "true");
      backdrop.addEventListener("click", function () {
        closeAll();
      });
      document.body.appendChild(backdrop);
    }
    return backdrop;
  }

  function syncBackdrop() {
    const nav = getNav();
    const open =
      nav &&
      nav.querySelector('input.nav-disclosure[type="checkbox"]:checked');
    const layer = backdropEl();
    if (layer) {
      layer.hidden = !open;
    }
  }

  /** At each `<ul>`, only one open branch: uncheck other direct sibling disclosures. */
  function closeSiblingDisclosures(clicked) {
    if (!clicked.checked) {
      return;
    }
    const li = clicked.closest("li");
    if (!li || !li.parentElement) {
      return;
    }
    const ul = li.parentElement;
    if (ul.tagName !== "UL") {
      return;
    }
    for (let i = 0; i < ul.children.length; i++) {
      const sib = ul.children[i];
      if (sib === li || sib.tagName !== "LI") {
        continue;
      }
      const other = sib.querySelector(":scope > input.nav-disclosure");
      if (other && other !== clicked) {
        other.checked = false;
      }
    }
  }

  function closeAll() {
    const nav = getNav();
    if (!nav) {
      syncBackdrop();
      return;
    }
    nav
      .querySelectorAll('input.nav-disclosure[type="checkbox"]:checked')
      .forEach(function (el) {
        el.checked = false;
      });
    syncBackdrop();
  }

  function init() {
    if (!document.body) {
      return;
    }

    document.addEventListener("change", function (e) {
      const t = e.target;
      if (
        !t ||
        t.type !== "checkbox" ||
        !t.classList.contains("nav-disclosure")
      ) {
        return;
      }
      const nav = getNav();
      if (!nav || !nav.contains(t)) {
        return;
      }
      closeSiblingDisclosures(t);
      syncBackdrop();
    });

    document.addEventListener("click", function (e) {
      const nav = getNav();
      if (!nav) {
        return;
      }
      if (!nav.contains(e.target)) {
        closeAll();
        return;
      }
      if (e.target.closest("a.nav-link")) {
        closeAll();
      }
    });

    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") {
        closeAll();
      }
    });

    document.addEventListener("htmx:afterSwap", function (e) {
      if (e.detail.target && e.detail.target.id === "main") {
        closeAll();
      }
    });

    document.addEventListener("htmx:afterSettle", function () {
      syncBackdrop();
    });
  }

  if (document.body) {
    init();
  } else {
    document.addEventListener("DOMContentLoaded", init);
  }
})();
