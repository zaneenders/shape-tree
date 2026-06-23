#!/usr/bin/env bash
set -euo pipefail

# Build the Canvas interactive page into a wasm binary + meta.json.
# Output lands in dist/<CONTENT_PATH>.wasm (+ .meta.json).
#
# Usage:
#   ./scripts/build.sh
#
# Environment:
#   SWIFT_WASM_SDK  SwiftWasm SDK (default: swift-6.3.2-RELEASE_wasm-embedded)
#   CONTENT_PATH    Output content path (default: Private/Canvas)

SDK="${SWIFT_WASM_SDK:-swift-6.3.2-RELEASE_wasm-embedded}"
CONTENT_PATH="${CONTENT_PATH:-Private/Canvas}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
BUILD_DIR="$ROOT/.build/js"

export PATH="${HOME}/.swiftly/bin:${PATH}"

if ! swift sdk list 2>/dev/null | grep -qx "$SDK"; then
  echo "error: wasm SDK '$SDK' not installed" >&2
  echo "  (see https://github.com/swiftwasm/swift for installation)" >&2
  exit 1
fi

if ! command -v wasm-opt >/dev/null; then
  echo "error: wasm-opt not found (brew install binaryen)" >&2
  exit 1
fi

echo "Building Canvas with ${SDK}..."
rm -rf "$BUILD_DIR"
(
  cd "$ROOT"
  unset JAVASCRIPTKIT_EXPERIMENTAL_EMBEDDED_WASM
  swift package \
    --swift-sdk "$SDK" \
    --allow-writing-to-package-directory \
    js --product Canvas --output "$BUILD_DIR" --configuration release --debug-info-format none
)

WASM="$BUILD_DIR/Canvas.wasm"
if [[ ! -f "$WASM" ]]; then
  echo "error: $WASM missing" >&2
  exit 1
fi

wasm-opt -Oz --strip-debug --strip-producers "$WASM" -o "$WASM"

rm -rf "$DIST"
mkdir -p "$(dirname "$DIST/$CONTENT_PATH")"
cp "$WASM" "$DIST/$CONTENT_PATH.wasm"
cp "$ROOT/meta.json" "$DIST/$CONTENT_PATH.meta.json"

echo "Wrote ${DIST}/${CONTENT_PATH}.wasm"
echo "Wrote ${DIST}/${CONTENT_PATH}.meta.json"
