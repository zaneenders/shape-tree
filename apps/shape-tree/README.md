# shape-tree

Hummingbird server wrapping ScribeAgent.

## Configuration

All values are **required**. Create `shape-tree-config.json` in the working directory:

```json
{
  "server": {
    "port": 42069
  },
  "data": {
    "path": "."
  },
  "ollama": {
    "url": "http://127.0.0.1:11434",
    "token": ""
  },
  "jwt": {
    "secret": "change-me-use-a-long-random-string"
  },
  "agent": {
    "model": "gemma4:e2b",
    "systemPrompt": "You are a helpful coding assistant.",
    "contextWindow": 131072,
    "contextWindowThreshold": 0.85
  }
}
```

Use `server.port` for the listener. `data.path` is the **absolute or relative directory `R`** for all mutable ShapeTree files; relative paths (including `"."`) resolve against the server process working directory when it reads the config. Journal git state, `journal-subjects.json`, and device-token JSON live under `R/.shape-tree/`. For local development, set `data.path` to the repository root and ignore `.shape-tree/` via git (see repo `.gitignore`).

`jwt.secret` is used for **HS256** JWT verification on every HTTP route (`Authorization: Bearer`). The middleware is registered on the router **before** any OpenAPI handlers are added, so **all** paths require a valid Bearer token once the server starts with a non-empty secret.

**Cryptography:** JWT signing and verification go through Vapor’s **[JWTKit](https://github.com/vapor/jwt-kit)**. JWTKit builds on Apple’s **[swift-crypto](https://github.com/apple/swift-crypto)** (`Crypto`, `CryptoExtras`) for HMAC and related primitives—this repo does not ship custom crypto.

Clients must send a valid token whose signature matches this secret (claims include `sub`, `iat`, `exp`; typical lifetime up to one hour). Prefer **`ShapeTreeClientCLI --mint-token`** (below): it reads `jwt.secret` from `./shape-tree-config.json` in the current directory, mints a **1-hour** JWT with a random `sub`, and prints only the token—no secret on the command line. Alternatively use **`--print-hs256-jwt`** or any HS256 tool that matches this claims shape.

**Important:** `jwt.secret` is only for the server's JSON config and for **signing**. Clients (ShapeTree app, `ShapeTreeClientCLI`) must receive the **minted JWT** string (`eyJ…` with **two dots**). Do **not** paste `jwt.secret`, the raw `"jwt": { … }` block, or other config JSON into the app—that will always yield **401**.

### Minting a client JWT (Swift CLI)

From `apps/shape-tree` (so `./shape-tree-config.json` is present), use JWTKit via the bundled CLI (**same claims shape as the server**: `sub`, `iat`, `exp`; HS256):

```bash
swift run ShapeTreeClientCLI --mint-token
```

This prints one line (JWT starting with `eyJ`). Paste it into the app's Connection field, or pass it as `--token` / `-t` when starting the interactive CLI.

Advanced—put the secret on the command line (avoid shell history on shared machines):

```bash
swift run ShapeTreeClientCLI --print-hs256-jwt 'YOUR_JWT_SECRET_FROM_CONFIG'
```

Optional with `--print-hs256-jwt` only: `--mint-subject shape-tree-cli` (default) and `--mint-ttl-seconds 3600` (default). **`--mint-token` is always 3600 seconds** with a random `sub` (`shape-tree-<uuid>`).

### Generating `jwt.secret`

Use a long, random string and treat it like a password: store it only in config or your secrets manager, not in git.

**Recommended (OpenSSL)** — 32 random bytes as URL-safe base64 (fits cleanly in JSON):

```bash
openssl rand -base64 32
```

**Hex alternative** (64 hex characters ≈ 32 bytes):

```bash
openssl rand -hex 32
```

Paste the output into `jwt.secret` as a JSON string (escape any `"` if you paste quoted shell output). Avoid short or guessable values; rotating the secret invalidates all outstanding JWTs until clients mint new tokens.

`ollama.token` can be empty when no bearer token is required (e.g. local Ollama).

## Testing

You can use the following commands to view current test coverage.

**macOS**
```bash
swift test --enable-code-coverage
PROFDATA=$(find .build -name '*.profdata' -print -quit)
BIN=$(find .build -name 'shape-treePackageTests' -type f -not -path '*.dSYM*' -print -quit)
xcrun llvm-cov report "$BIN" --instr-profile="$PROFDATA" \
  --ignore-filename-regex='\.build\/' \
  --ignore-filename-regex='\/scribe\/Sources\/'
```

**Linux**
```bash
swift test --enable-code-coverage
PROFDATA=$(find .build -name '*.profdata' -print -quit)
BIN=$(find .build -name 'shape-treePackageTests' -type f -print -quit)
llvm-cov report "$BIN" --instr-profile="$PROFDATA" \
  --ignore-filename-regex='\.build\/' \
  --ignore-filename-regex='\/scribe\/Sources\/'
```
