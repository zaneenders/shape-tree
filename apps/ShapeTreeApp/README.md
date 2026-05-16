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
| **Chat** | Creates an agent session + streamed completion loop (OpenAPI `POST /sessions`, `POST /sessions/{id}/completions/stream`). |
| **Journal** | Loads `GET /journal/subjects`, multi-selects subject ids, appends Markdown via `POST /journal/entries`. Push flow hits `POST /devices/register-token` for server-side JSON storage. |

Default base URL: `http://127.0.0.1:42069` (see `ShapeTreeViewModel.serverURL`).

## API authentication (per-device ES256 keys)

The app generates a **P-256 keypair on the device** the first time it runs — Secure Enclave on real
iPhones and Apple silicon Macs, plain Keychain elsewhere — and signs every request as a short-lived
**ES256 JWT**. There is no shared secret; the server only trusts public keys it has been told about
out of band.

- **In the UI**: tap the **network** button in the chat header. The "Device public key" section
  shows the public JWK and the 43-char thumbprint (in 8-char groups). Hit **Copy public JWK** and
  drop the JSON onto the server as `R/.shape-tree/authorized_keys/<kid>.jwk`. **Regenerate device
  key** wipes the on-device key and creates a new one — you then have to re-enroll the new public
  JWK before the device can call the server.
- **In code**: `ShapeTreeViewModel.keyStore` exposes `publicJWKJSON()` / `kid()` /
  `regenerateDeviceKey()`. The OpenAPI client middleware (`ShapeTreeAutoMintBearer`) mints a fresh
  ES256 JWT for every outbound call.

The `dev` JWT header carries the device label (defaults to the host name; editable in the
Connection sheet). It's logged for breadcrumbs only — identity is the public key thumbprint.

See the [server README](../shape-tree/README.md) for auth and trust-store details.

**Rebuild Xcode after changing ATS**: run `xcodegen generate` under `apps/ShapeTreeApp` whenever
`project.yml` changes so the Info.plist picks up local-network HTTP allowances.

The server's router installs the ES256 middleware **before** all generated handlers, so **every
HTTP route** requires a valid bearer JWT signed by an enrolled key. Successful TCP hits appear in
the server log as `event=http.request` followed by `event=auth.ok kid=… dev=…`.

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
