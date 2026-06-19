#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/WASMClient"
ASSETS="$ROOT/Sources/ShapeTreeWebAssets"
OUT_JS="$ASSETS/client"
BUILD_DIR="$CLIENT/.build/js"
SDK="${SWIFT_WASM_SDK:-swift-6.3.2-RELEASE_wasm-embedded}"

export PATH="${HOME}/.swiftly/bin:${PATH}"

if ! swift sdk list 2>/dev/null | grep -qx "$SDK"; then
  echo "error: wasm SDK '$SDK' not installed (see README → Swift WASM)" >&2
  exit 1
fi

if ! command -v wasm-opt >/dev/null; then
  echo "error: wasm-opt not found (brew install binaryen)" >&2
  exit 1
fi

echo "Building WASMClient with ${SDK}..."
rm -rf "$BUILD_DIR" "$CLIENT/.build/plugins/PackageToJS/outputs/js.tmp"
(
  cd "$CLIENT"
  # Reactor mode — required so the module can register JS listeners (not command/_start).
  unset JAVASCRIPTKIT_EXPERIMENTAL_EMBEDDED_WASM
  swift package \
    --swift-sdk "$SDK" \
    --allow-writing-to-package-directory \
    js --output "$BUILD_DIR" --configuration release --debug-info-format none
)

WASM="$BUILD_DIR/WASMClient.wasm"
if [[ ! -f "$WASM" ]]; then
  echo "error: wasm output missing at ${WASM}" >&2
  exit 1
fi

wasm-opt -Oz --strip-debug --strip-producers "$WASM" -o "$WASM"

rm -rf "$OUT_JS"
mkdir -p "$OUT_JS/platforms"
cp "$BUILD_DIR/index.js" "$BUILD_DIR/instantiate.js" "$BUILD_DIR/runtime.js" "$OUT_JS/"
cp "$BUILD_DIR/platforms/browser.js" "$OUT_JS/platforms/"
cp "$WASM" "$ASSETS/ClientWasm.wasm"

# WASI shim is committed under Sources/ShapeTreeWebAssets/Vendor/ and served locally.
perl -pi -e "s|'\\@bjorn3/browser_wasi_shim'|'../browser_wasi_shim.js'|g" \
  "$OUT_JS/platforms/browser.js"

echo "Wrote client JS to ${OUT_JS}"
echo "Wrote ${ASSETS}/ClientWasm.wasm"
echo "Run: swift build && swift run ShapeTreeWeb"
