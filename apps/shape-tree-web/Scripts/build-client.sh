#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/WASMClient"
OUT_JS="$ROOT/Sources/ShapeTreeWebAssets/nav-client"
OUT_WASM="$ROOT/Sources/ShapeTreeWebAssets/NavClientWasm.wasm"
BUILD_DIR="$CLIENT/.build/js"

export PATH="${HOME}/.swiftly/bin:${PATH}"

TAG="$(swiftc -print-target-info | python3 -c 'import json,sys; print(json.load(sys.stdin)["swiftCompilerTag"])')"

SDK_CANDIDATES=("${TAG}_wasm-embedded" "swift-6.3.2-RELEASE_wasm-embedded")

pick_sdk() {
  local candidate
  for candidate in "$@"; do
    if swift sdk list 2>/dev/null | grep -qx "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

SDK_ID="$(pick_sdk "${SDK_CANDIDATES[@]}")" || {
  cat >&2 <<EOF
error: no embedded wasm Swift SDK found.

Install the official bundle (matches Swift ${TAG}):

  swift sdk install \\
    https://download.swift.org/swift-6.3.2-release/wasm-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_wasm.artifactbundle.tar.gz \\
    --checksum a61f0584c93283589f8b2f42db05c1f9a182b506c2957271402992655591dd7c
EOF
  exit 1
}

echo "Building WASMClient (Swift 6) with ${SDK_ID}..."
rm -rf "$BUILD_DIR" "$CLIENT/.build/plugins/PackageToJS/outputs/js.tmp"
(
  cd "$CLIENT"
  # Do not set JAVASCRIPTKIT_EXPERIMENTAL_EMBEDDED_WASM — it skips reactor linker
  # flags and produces a command-mode module (_start) that cannot register JS listeners.
  unset JAVASCRIPTKIT_EXPERIMENTAL_EMBEDDED_WASM
  swift package \
    --swift-sdk "$SDK_ID" \
    --allow-writing-to-package-directory \
    js --use-cdn --output "$BUILD_DIR" --configuration release --debug-info-format none
)

WASM_SRC="$BUILD_DIR/WASMClient.wasm"
if [[ ! -f "$WASM_SRC" ]]; then
  echo "error: wasm output missing at ${WASM_SRC}" >&2
  exit 1
fi

BYTES="$(wc -c < "$WASM_SRC" | tr -d ' ')"
echo "Wasm size before extra opt: $(numfmt --to=iec-i --suffix=B "$BYTES" 2>/dev/null || echo "${BYTES} bytes")"

if command -v wasm-opt >/dev/null; then
  wasm-opt -Oz --strip-debug --strip-producers "$WASM_SRC" -o "$WASM_SRC"
  BYTES="$(wc -c < "$WASM_SRC" | tr -d ' ')"
  echo "Wasm size after wasm-opt -Oz: $(numfmt --to=iec-i --suffix=B "$BYTES" 2>/dev/null || echo "${BYTES} bytes")"
else
  echo "error: wasm-opt not found (brew install binaryen)" >&2
  exit 1
fi

rm -rf "$OUT_JS"
mkdir -p "$OUT_JS"
cp -R "$BUILD_DIR"/* "$OUT_JS"/
cp "$WASM_SRC" "$OUT_WASM"

echo "Wrote JavaScript modules to ${OUT_JS}"
echo "Wrote wasm resource to ${OUT_WASM}"
echo "Run 'swift build' in apps/shape-tree-web to embed assets and serve /assets/nav-client/*"
