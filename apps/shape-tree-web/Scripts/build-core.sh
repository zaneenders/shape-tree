#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/../wasm-client"
ASSETS="$ROOT/Sources/ShapeTreeWebAssets"
OUT_JS="$ASSETS/client"
BUILD_DIR="$CLIENT/.build/js"
CORE_SDK="${SWIFT_WASM_CORE_SDK:-swift-6.3.2-RELEASE_wasm}"

export PATH="${HOME}/.swiftly/bin:${PATH}"

if ! swift sdk list 2>/dev/null | grep -qx "$CORE_SDK"; then
  echo "error: wasm SDK '$CORE_SDK' not installed (see README → Swift WASM)" >&2
  exit 1
fi

if ! command -v wasm-opt >/dev/null; then
  echo "error: wasm-opt not found (brew install binaryen)" >&2
  exit 1
fi

patch_client_index_js() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "error: ${file} missing" >&2
    exit 1
  fi
  perl -0777 -pi -e '
    s/if \(!module\) \{\s*module = fetch\(new URL\([^)]+\)\)\s*\}/if (!module) {\n    throw new Error("init requires options.module");\n  }/s
  ' "$file"
}

echo "Building ShapeTreeCore with ${CORE_SDK}..."
rm -rf "$BUILD_DIR" "$CLIENT/.build/plugins/PackageToJS/outputs/js.tmp"
(
  cd "$CLIENT"
  unset JAVASCRIPTKIT_EXPERIMENTAL_EMBEDDED_WASM
  swift package \
    --swift-sdk "$CORE_SDK" \
    --allow-writing-to-package-directory \
    js --product ShapeTreeCore --output "$BUILD_DIR" --configuration release --debug-info-format none
)

WASM="$BUILD_DIR/ShapeTreeCore.wasm"
if [[ ! -f "$WASM" ]]; then
  echo "error: wasm output missing at ${WASM}" >&2
  exit 1
fi

wasm-opt -Oz --strip-debug --strip-producers "$WASM" -o "$WASM"

rm -rf "$OUT_JS"
mkdir -p "$OUT_JS/platforms"
cp "$BUILD_DIR/index.js" "$BUILD_DIR/instantiate.js" "$BUILD_DIR/runtime.js" "$OUT_JS/"
cp "$BUILD_DIR/platforms/browser.js" "$OUT_JS/platforms/"
cp "$WASM" "$ASSETS/ShapeTreeCore.wasm"
patch_client_index_js "$OUT_JS/index.js"

perl -pi -e "s|'\\@bjorn3/browser_wasi_shim'|'../browser_wasi_shim.js'|g" \
  "$OUT_JS/platforms/browser.js"

echo "Wrote client JS to ${OUT_JS}"
echo "Wrote ${ASSETS}/ShapeTreeCore.wasm"
