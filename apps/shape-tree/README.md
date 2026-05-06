# shape-tree

Hummingbird server wrapping ScribeAgent.

## Configuration

All values are **required**. Create `shape-tree-config.json` in the working directory:

```json
{
  "ollama": {
    "url": "http://127.0.0.1:11434",
    "token": ""
  },
  "agent": {
    "model": "gemma4:e2b",
    "systemPrompt": "You are a helpful coding assistant.",
    "contextWindow": 131072,
    "contextWindowThreshold": 0.85
  }
}
```

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
