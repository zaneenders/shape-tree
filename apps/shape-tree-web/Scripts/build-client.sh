#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/../wasm-client"
POST_PKG="$ROOT/../wasm-post"
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

echo "Building WASMNav with ${SDK}..."
rm -rf "$BUILD_DIR" "$CLIENT/.build/plugins/PackageToJS/outputs/js.tmp"
(
  cd "$CLIENT"
  # Reactor mode — required so the module can register JS listeners (not command/_start).
  unset JAVASCRIPTKIT_EXPERIMENTAL_EMBEDDED_WASM
  swift package \
    --swift-sdk "$SDK" \
    --allow-writing-to-package-directory \
    js --product WASMNav --output "$BUILD_DIR" --configuration release --debug-info-format none
)

WASM="$BUILD_DIR/WASMNav.wasm"
if [[ ! -f "$WASM" ]]; then
  echo "error: wasm output missing at ${WASM}" >&2
  exit 1
fi

wasm-opt -Oz --strip-debug --strip-producers "$WASM" -o "$WASM"

rm -rf "$OUT_JS"
mkdir -p "$OUT_JS/platforms"
cp "$BUILD_DIR/index.js" "$BUILD_DIR/instantiate.js" "$BUILD_DIR/runtime.js" "$OUT_JS/"
cp "$BUILD_DIR/platforms/browser.js" "$OUT_JS/platforms/"
cp "$ASSETS/Vendor/bootstrap.js" "$OUT_JS/bootstrap.js"
cp "$WASM" "$ASSETS/WASMNav.wasm"

# WASI shim is committed under Sources/ShapeTreeWebAssets/Vendor/ and served locally.
perl -pi -e "s|'\\@bjorn3/browser_wasi_shim'|'../browser_wasi_shim.js'|g" \
  "$OUT_JS/platforms/browser.js"

echo "Wrote client JS to ${OUT_JS}"
echo "Wrote ${ASSETS}/WASMNav.wasm"

# --- Per-page WASM: generate one .wasm per markdown file ---

CONTENT_PATH="${CONTENT_PATH:-/Users/zane/Content}"
GEN_PKG="$POST_PKG/Generator"
PAGES_DIR="$POST_PKG/Sources/Pages"
MANIFEST="$POST_PKG/.build/manifest.txt"
WASM_POSTS_DIR="$ASSETS/WasmPosts"

echo "Building ContentGenerator..."
(
  cd "$GEN_PKG"
  swift build -c release 2>&1
)
GENERATOR="$GEN_PKG/.build/release/ContentGenerator"

echo "Generating per-page Swift sources..."
rm -rf "$PAGES_DIR"
mkdir -p "$PAGES_DIR"
mkdir -p "$POST_PKG/.build"

MD_FILES=()
while IFS= read -r f; do
  MD_FILES+=("$f")
done < <(find "$CONTENT_PATH" -name "*.md" -type f | sort)

"$GENERATOR" "$PAGES_DIR" "$POST_PKG/Package.swift" "$MANIFEST" "${MD_FILES[@]}"

echo "Building per-page WASM modules..."
rm -rf "$WASM_POSTS_DIR"
mkdir -p "$WASM_POSTS_DIR"

FIRST_JS_DIR=""
while IFS='=' read -r target slug; do
  [[ -z "$target" || -z "$slug" ]] && continue
  echo "  Building $slug..."
  PAGE_BUILD_DIR="$POST_PKG/.build/js-$slug"
  (
    cd "$POST_PKG"
    unset JAVASCRIPTKIT_EXPERIMENTAL_EMBEDDED_WASM
    swift package \
      --swift-sdk "$SDK" \
      --allow-writing-to-package-directory \
      js --product "$target" --output "$PAGE_BUILD_DIR" --configuration release --debug-info-format none 2>&1
  ) >/dev/null

  PAGE_WASM="$PAGE_BUILD_DIR/$target.wasm"
  if [[ ! -f "$PAGE_WASM" ]]; then
    echo "error: $PAGE_WASM missing" >&2
    exit 1
  fi

  wasm-opt -Oz --strip-debug --strip-producers "$PAGE_WASM" -o "$PAGE_WASM"
  cp "$PAGE_WASM" "$WASM_POSTS_DIR/$slug.wasm"

  if [[ -z "$FIRST_JS_DIR" ]]; then
    FIRST_JS_DIR="$PAGE_BUILD_DIR"
  fi
done < "$MANIFEST"

# Copy JS shim (shared by all page wasms) from the first build output
if [[ -n "$FIRST_JS_DIR" ]]; then
  cp "$FIRST_JS_DIR/index.js" "$FIRST_JS_DIR/instantiate.js" "$FIRST_JS_DIR/runtime.js" "$OUT_JS/"
  cp "$FIRST_JS_DIR/platforms/browser.js" "$OUT_JS/platforms/"
  cp "$ASSETS/Vendor/bootstrap.js" "$OUT_JS/bootstrap.js"
  perl -pi -e "s|'\\@bjorn3/browser_wasi_shim'|'../browser_wasi_shim.js'|g" \
    "$OUT_JS/platforms/browser.js"
fi

PAGE_COUNT=$(ls "$WASM_POSTS_DIR"/*.wasm 2>/dev/null | wc -l | tr -d ' ')
echo "Wrote $PAGE_COUNT per-page wasm(s) to ${WASM_POSTS_DIR}"

echo "Run: swift build && swift run ShapeTreeWeb"
