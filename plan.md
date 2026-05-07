# ShapeTree journal, git, and HTTP — implementation plan

## Goals

- **Journal** matches Scribe’s on-disk format and git behavior (pull / add / commit / push) via a vendored **Sit** wrapper.
- **ShapeTree server** owns the data root: a **required** config value (no optional “maybe Application Support” on the server).
- **HTTP** for journal and APNs registration uses **OpenAPI specs** and the **Swift OpenAPI** stack with **AsyncHTTPClient** (`OpenAPIAsyncHTTPClient`), not ad-hoc `URLSession`.
- **Local testing**: repo stays clean by gitignoring the mutable journal tree under the configured root.

---

## 1. Server: required data path and directory layout

### Config

- Add a **required** field to ShapeTree server configuration, e.g. `data_path` or `scribe_data_path` (name TBD in code).
- Semantics:
  - **Absolute path**: use as-is as the **data root** `R`.
  - **`.`** (or other relative path): resolve relative to the server’s **current working directory** at startup (document this in config comments / example).

### Layout under `R`

All mutable Scribe-compatible artifacts live under **one** dot-folder inside `R` (pick one convention for shape-tree and stick to it):

- **Option A (recommended):** `R/.shape-tree/` — journal data, subjects file, device registry if stored on disk, etc.
- **Option B:** `R/.scribe/` — same content, useful if you want byte-for-byte familiarity with Scribe tooling docs.

Suggested contents (mirror Scribe server expectations):

| Path | Purpose |
|------|--------|
| `{dot}/journal-subjects.json` | Subject labels for entries |
| `{dot}/Journal/` | Git repo root; `yy/MM/yy-MM-dd.md` daily files |
| `{dot}/devices/` | (If APNs token storage matches Scribe) one JSON file per device |

Bootstrap on first run: create `{dot}` if missing, create `Journal/` and `git init` if missing, create default `journal-subjects.json` if missing.

### Gitignore (local testing)

- Add patterns so developers can set `data_path: "."` and keep the repo clean, e.g.:

  - `/.shape-tree/` or `/.scribe/` (depending on chosen name)
  - Or ignore only the heavy subtree: `/.shape-tree/Journal/` if you prefer committing tiny config samples but not history — **usually ignore the whole dot-folder** for simplicity.

- Document in README or example config: **“point `data_path` at checkout root for dev; dot-folder is gitignored.”**

---

## 2. Sit (git) — vendored module

- Copy **`Sit.swift`** (and helpers if still needed) from Scribe’s `Sources/Sit/` into this repo, e.g. `apps/shape-tree/Sources/Sit/`.
- Add SPM target **`Sit`** with dependencies aligned to Scribe: **`swift-subprocess`**, **`swift-log`**, **System / SystemPackage** as required.
- **Journal write path** on the server should follow Scribe **`JournalService`** semantics where it matters:
  - `git pull --rebase` when the working tree is clean (ignore benign “no remote” failures).
  - If **unstaged changes**: skip pull; stage **only** the journal file (or narrowly scoped paths); commit behavior matches Scribe (soft failure vs hard error as in reference).
  - `git add` / `git commit` / `git push` after append.
- Keep the **markdown block rules** (subject heading `# a, b`, `-----` separators) aligned with Scribe so files stay interchangeable.

---

## 3. HTTP — OpenAPI + Async HTTP client

### Specs

- **Copy** (then own) OpenAPI YAML from Scribe, e.g.:
  - Journal: `JournalProtocol/openapi.yaml` + generator config.
  - APNs: `APNsProtocol/openapi.yaml` + generator config.
- **Edit** only when ShapeTree diverges (paths, schemas, auth). Ensure **request bodies** match the running server (e.g. snake_case vs camelCase for `device_token`).

### Codegen targets (SPM)

- Add one or more library targets that use **`OpenAPIGenerator`** with **`OpenAPIRuntime`** and **`OpenAPIAsyncHTTPClient`** (not bare `URLSession`).
- Reuse the same **JWT middleware** pattern as **`ShapeTreeClient`** if journal/APNs routes require Bearer tokens.

### Consumers

- **ShapeTree server**: implement handlers from the journal (and optionally APNs) OpenAPI **server** types, or hand-rolled Hummingbird routes that still satisfy the spec — same public API contract.
- **iOS / macOS app** (when wired): depend on the **client** types generated from the same spec; transport = **AsyncHTTPClient** via `OpenAPIAsyncHTTPClient`.

---

## 4. responsibilities split

| Component | Role |
|-----------|------|
| **ShapeTree server** | Reads **required** `data_path`; resolves `{dot}` under `R`; runs journal git ops via **Sit**; serves journal + device-token HTTP per OpenAPI. |
| **Clients** | No server file path; talk HTTP only (generated client + Async HTTP stack). Optional UX: “server URL”, JWT, push registration — not “Application Support data root” for journal content. |

The earlier “app creates R under Application Support” model is **out of scope** for the canonical store; the **server config path** is the source of truth for journal files.

---

## 5. Implementation phases (suggested)

1. **Config + layout** — Required `data_path`, resolve `R`, define `.shape-tree` (or `.scribe`) subtree, create/bootstrap dirs, `.gitignore` + example config.
2. **Sit** — Vend `Sit` target; smoke-test `git` in a temp dir from tests.
3. **Journal core** — Port/adapt journal append + query logic (markdown + paths) to use `FileManager` or existing stack; call **Sit** from `Journal/` root only.
4. **OpenAPI** — Drop in YAML, generate client/server types; wire **AsyncHTTPClient** for outbound tests if any.
5. **Server routes** — Register journal + `device-token` routes on ShapeTree server; JWT if required.
6. **App** — Later: add generated client products to Xcode (`project.yml`), push registration, journal UI against server.

---

## 6. Testing

- **Unit tests**: path resolution for `data_path` (`.` vs absolute), date → file path, append produces expected markdown.
- **Integration**: temp directory as `data_path`, append entry, assert git state / file content; optional HTTP test via Hummingbird testing + generated request types.

---

## 7. Files likely touched

- `apps/shape-tree/Package.swift` — new targets: `Sit`, journal/APNs OpenAPI clients (and server glue if split).
- `apps/shape-tree/Sources/ShapeTree/` — config loading, journal route registration, services using `data_path`.
- Configuration schema / example — `data_path` required.
- `.gitignore` — dot-data directory under dev roots.
- `apps/ShapeTreeApp/project.yml` — when the app consumes generated clients.

This document is the single place for scope and layout until the implementation PRs land.
