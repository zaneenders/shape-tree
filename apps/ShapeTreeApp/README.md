# ShapeTree Client App

Cross-platform (**iOS** + **macOS**) SwiftUI shell that talks exclusively to your [ShapeTree server](../shape-tree/README.md) via the OpenAPI-generated [ShapeTreeClient](../shape-tree/Sources/ShapeTreeClient/). Transport uses `OpenAPIAsyncHTTPClient`; there is **no journal data path on device** — all journal git work happens server-side (`data.path` + `.shape-tree/`).

## Prerequisites

- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- macOS / Xcode toolchain matching deployment targets declared in `project.yml`

## Code signing

Committed `project.yml` never embeds a development team ID. Signing values live in **`project.local.yml`**, which is **gitignored** and created manually from **`project.local.yml.example`**.

```bash
cd apps/ShapeTreeApp
cp project.local.yml.example project.local.yml
# edit TEAM ids as needed — simulator-only hacks may work briefly with placeholders.
```

Physical devices / notarization require a valid `DEVELOPMENT_TEAM`.

## Generate & open

```bash
xcodegen generate
open ShapeTreeClient.xcodeproj
```

XcodeGen **requires `project.local.yml` to exist** (even stubbed); copy from the example first.

## UI overview

| Tab | Purpose |
|-----|---------|
| **Chat** | Creates an agent session + streaming-ish completion loop (OpenAPI `POST /sessions`, `POST /sessions/{id}/completions`). |
| **Journal** | Loads `GET /journal/subjects`, multi-selects subject ids, appends Markdown via `POST /journal/entries`. Push flow hits `POST /devices/register-token` for server-side JSON storage. |

Default base URL: `http://127.0.0.1:42069` (see `ShapeTreeViewModel.serverURL`).

## API authentication (JWT)

The ShapeTree server signs requests with **`jwt.secret`** in `shape-tree-config.json` ([server README](../shape-tree/README.md)). **Never ship that secret in the client app.** It must stay on the machine running the server (or in your deployment secrets).

The app only needs a **minted JWT** (HS256, valid `sub` / `iat` / `exp` claims) and sends it as `Authorization: Bearer <token>` on every OpenAPI call. The token looks like **`eyJ…` with two dots**—**not** the `jwt.secret` string and **not** the `"jwt": { … }` JSON copied from `shape-tree-config.json`.

- **In the UI**: tap the **network** button in the chat header, then paste the JWT into **API access token** and set **Server URL** if needed. Values persist in **UserDefaults** (`shape_tree_server_url`, `shape_tree_api_bearer_token`). The sheet rejects obvious JSON / wrong-shape pastes before saving.
- **In code**: set `ShapeTreeViewModel.apiBearerToken` before making requests (same persistence applies when changed).

Mint tokens with **`swift run ShapeTreeClientCLI --mint-token`** from `apps/shape-tree` ([details](../shape-tree/README.md)), then pass that token to `--token` / `-t`. Use **`--print-hs256-jwt`** only if you prefer supplying the secret explicitly.

**Rebuild Xcode after changing ATS**: run `xcodegen generate` under `apps/ShapeTreeApp` whenever `project.yml` changes so the Info.plist picks up local-network HTTP allowances.

The server's router installs JWT middleware **before** all generated handlers, so **every HTTP route** (sessions, journal, device registration, etc.) requires a valid Bearer token once `jwt.secret` is configured. Successful TCP hits appear in the server log as `event=http.request`.

## Structure

```
ShapeTreeApp/
├── project.yml                  # XcodeGen project spec (no Team ID)
├── project.local.yml.example    # Template for gitignored project.local.yml
├── ShapeTreeShared/
│   ├── ShapeTreeViewModel.swift # @Observable model (ShapeTreeClient + AsyncHTTPClient)
│   └── Views/
│       ├── ShapeTreeChatView.swift   # Tab host (Chat + Journal)
│       ├── ShapeTreeJournalView.swift
│       └── ShapeTreeChatInputView.swift
├── ShapeTree-iOS-Only/
└── ShapeTree-Mac-Only/
```
