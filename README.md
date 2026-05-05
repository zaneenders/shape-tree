# shape-tree

Hummingbird server wrapping ScribeAgent.

## Testing

You can use the following commands to view current test coverage.

**macOS**
```bash
swift test --enable-code-coverage
PROFDATA=$(find .build -name '*.profdata' -print -quit)
BIN=$(find .build -name 'shape-treePackageTests' -type f -not -path '*.dSYM*' -print -quit)
xcrun llvm-cov report "$BIN" --instr-profile="$PROFDATA" \
  --ignore-filename-regex='\.build/' \
  --ignore-filename-regex='/scribe/Sources/'
```

**Linux**
```bash
swift test --enable-code-coverage
PROFDATA=$(find .build -name '*.profdata' -print -quit)
BIN=$(find .build -name 'shape-treePackageTests' -type f -print -quit)
llvm-cov report "$BIN" --instr-profile="$PROFDATA" \
  --ignore-filename-regex='\.build/' \
  --ignore-filename-regex='/scribe/Sources/'
```
