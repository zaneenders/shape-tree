# shape-tree

Hummingbird server wrapping ScribeAgent.

## Local development

The only hard dependency is **Ollama** running on the host. The shipped `.env` targets
`http://host.docker.internal:11434` (for Docker compose); for a native `swift run` override it:

```bash
OLLAMA_URL=http://127.0.0.1:11434 swift run ShapeTree
```

Traces are optional — `docker compose up jaeger -d` and set
`OTEL_EXPORTER_OTLP_BASE_ENDPOINT=http://127.0.0.1:4318`, or `OTEL_SDK_DISABLED=true` to skip. There
is no database; the journal is a git working tree under `DATA_PATH`, so the runtime image ships
`git` + `openssh-client`.

## Configuration

All values are **required**. Copy `.env.example` to `.env` and edit:

```bash
cp .env.example .env
```

| Variable | Description |
|---|---|
| `HOST` | Bind address — **defaults to `127.0.0.1` (loopback only)**. Set to a specific LAN IP only behind TLS. `0.0.0.0` logs a warning at startup. |
| `PORT` | Listener port. |
| `DATA_PATH` | Absolute or relative directory for mutable ShapeTree files; relative paths (including `.`) resolve against the server working directory. Journal git state, `journal-subjects.json`, and the ES256 trust store live under `R/.shape-tree/`. |
| `OLLAMA_URL` | Ollama API base URL. |
| `OLLAMA_TOKEN` | Ollama bearer token (may be empty for local Ollama). |
| `AGENT_MODEL` | Ollama model identifier (e.g. `gemma4:e2b`). |
| `AGENT_SYSTEM_PROMPT` | System prompt passed to the agent. |
| `AGENT_CONTEXT_WINDOW` | Model context window size in tokens. |
| `AGENT_CONTEXT_WINDOW_THRESHOLD` | Context utilisation threshold (0–1) that triggers pruning. |
| `JOURNAL_COMMIT_AUTHOR_NAME` | Fallback git author name for journal commits. |
| `JOURNAL_COMMIT_AUTHOR_EMAIL` | Fallback git author email for journal commits. |

System environment variables override `.env` file values.

## Authentication: per-device ES256 keys

ShapeTree uses an SSH-`authorized_keys`-style trust model. Each frontend (iOS app, Mac app)
owns a P-256 private key; the server only knows public keys.

### Trust store

The server reads public keys from:

```
R/.shape-tree/authorized_keys/<thumbprint>.jwk
```

One JWK per enrolled device. The basename **must** equal the RFC 7638 thumbprint of the contained
public key (`^[A-Za-z0-9_-]{43}$`); the server independently recomputes the thumbprint on every
request and 401s on any mismatch. Adding or revoking a key is a file operation — `cp` or `rm` —
nothing more.

### Cryptography

All signing and verification go through Vapor's [JWTKit](https://github.com/vapor/jwt-kit), which
is built on Apple's [swift-crypto](https://github.com/apple/swift-crypto) (and CryptoKit on Apple
platforms). The server only ever accepts `alg: ES256`; HS256 is gone.

JWTs carry:

- `kid` (header) — RFC 7638 thumbprint of the device's public key. The **only** field used to
  locate the verifier.
- `dev` (header) — human-readable device label, e.g. `zane-macbook`. Logged for breadcrumbs only;
  never used for authorization or path construction.
- `sub == kid`, plus `iat`, `exp`, and a random `jti`. TTL is short (5–15 minutes); clients mint
  fresh tokens per request.

The middleware enforces three claim-level pins on top of the signature check:

- `iat` must fall inside `[now − 30 min, now + 60 s]`. Bounds the effective lifetime of any single
  token regardless of what `exp` the issuer chose, and tolerates small positive clock skew.
- `jti` is **mandatory** and must be non-empty. The server records every admitted `(kid, jti)` in
  the in-process ``JWTReplayCache`` until that token's `exp`, so a captured token cannot be
  replayed inside its TTL. The cache is per-process; if you run the server as multiple replicas
  in front of a single trust store you must replace it with a shared store.
- `sub` must equal `kid`, so a token signed by enrolled key A cannot impersonate enrolled key B.

### Bootstrapping an iOS / macOS app device

The first launch generates a P-256 keypair via the Security framework — Secure Enclave on real
devices and Apple silicon Macs, plain Keychain on Simulator and Intel Macs. Tap the network icon in
the chat header → "Device public key" → "Copy public JWK", then save the JSON on the server as
`R/.shape-tree/authorized_keys/<kid>.jwk`. The thumbprint is shown in 8-char groups beside the
JWK so it can be eyeballed against the filename.

"Regenerate device key" wipes and re-creates the on-device keypair; the operator must re-enroll
the new public JWK before the device can call the server.

There is no shared secret: nothing in the config file or in any client image authorizes a request.
The trust anchor is the `<thumbprint>.jwk` file on the server.

### Revocation

```bash
# Find the kid by label:
grep -l '"label": *"zane-iphone"' "$DATA_ROOT/.shape-tree/authorized_keys/"*.jwk

# Revoke:
rm "$DATA_ROOT/.shape-tree/authorized_keys/<thumbprint>.jwk"
```

The next request from that device 401s. Outstanding tokens stay valid only inside their `exp`
window — same posture as SSH session tickets.

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
