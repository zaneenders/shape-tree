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
  "agent": {
    "model": "gemma4:e2b",
    "systemPrompt": "You are a helpful coding assistant.",
    "contextWindow": 131072,
    "contextWindowThreshold": 0.85
  },
  "journal": {
    "commitAuthor": {
      "name": "ShapeTree",
      "email": "shape-tree@localhost"
    }
  }
}
```

`server.port` is the listener. `data.path` is the **absolute or relative directory `R`** for all
mutable ShapeTree files; relative paths (including `"."`) resolve against the server process working
directory. Journal git state, `journal-subjects.json`, **and the ES256 trust store** live under
`R/.shape-tree/`. For local development, set `data.path` to the repository root and ignore
`.shape-tree/` via git (see repo `.gitignore`). `ollama.token` may be empty when no bearer token is
required (e.g. local Ollama).

## Authentication: per-device ES256 keys

ShapeTree uses an SSH-`authorized_keys`-style trust model. Each frontend (CLI, iOS app, Mac app)
owns a P-256 private key; the server only knows public keys. The full design lives in
[`.dev/auth.md`](../../.dev/auth.md); this section covers the day-to-day usage.

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

### Bootstrapping a CLI device

From `apps/shape-tree`:

```bash
swift run ShapeTreeClientCLI keygen --label "$(hostname -s)"
```

This creates a P-256 keypair under `~/.config/shape-tree/`:

- `id_p256.pem` — private key, `0600`.
- `id_p256.meta.json` — cached `kid` and label, `0600`.
- `id_p256.pub.jwk` — public JWK with `kid` and `label` baked in, `0644`.

`keygen` prints the public JWK and the thumbprint. To enroll the CLI on a server you control:

```bash
cp ~/.config/shape-tree/id_p256.pub.jwk \
   "$DATA_ROOT/.shape-tree/authorized_keys/$(jq -r .kid ~/.config/shape-tree/id_p256.pub.jwk).jwk"
```

(In a hardened deploy this is a `sudo install -o root -g shape-tree -m 0640 …` against
`/opt/shape-tree/data/.shape-tree/authorized_keys/`. See `.dev/auth.md`, "Install layout and
permissions".)

### Bootstrapping an iOS / macOS app device

The first launch generates a P-256 keypair via the Security framework — Secure Enclave on real
devices and Apple silicon Macs, plain Keychain on Simulator and Intel Macs. Tap the network icon in
the chat header → "Device public key" → "Copy public JWK", then save the JSON on the server as
`R/.shape-tree/authorized_keys/<kid>.jwk`. The thumbprint is shown in 8-char groups beside the
JWK so it can be eyeballed against the filename.

"Regenerate device key" wipes and re-creates the on-device keypair; the operator must re-enroll
the new public JWK before the device can call the server.

### Tokens (CLI)

```bash
# Print a 15-minute ES256 JWT signed with ~/.config/shape-tree/id_p256.pem.
swift run ShapeTreeClientCLI mint-token

# Drop into the interactive REPL — auto-mints a token from the on-disk key.
swift run ShapeTreeClientCLI

# REPL with a token you minted yourself.
swift run ShapeTreeClientCLI --token "$(swift run ShapeTreeClientCLI mint-token)"
```

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
