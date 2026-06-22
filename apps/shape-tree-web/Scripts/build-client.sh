#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/../wasm-client"
POST_PKG="$ROOT/../wasm-post"
ASSETS="$ROOT/Sources/ShapeTreeWebAssets"
OUT_JS="$ASSETS/client"
BUILD_DIR="$CLIENT/.build/js"
SDK="${SWIFT_WASM_SDK:-swift-6.3.2-RELEASE_wasm-embedded}"

CONTENT_PATH="${CONTENT_PATH:-$ROOT/Examples/content}"
INDEX_SLUG="${INDEX_SLUG:-Home}"
LOGIN_SLUG="${LOGIN_SLUG:-Login}"

export PATH="${HOME}/.swiftly/bin:${PATH}"

if ! swift sdk list 2>/dev/null | grep -qx "$SDK"; then
  echo "error: wasm SDK '$SDK' not installed (see README → Swift WASM)" >&2
  exit 1
fi

if ! command -v wasm-opt >/dev/null; then
  echo "error: wasm-opt not found (brew install binaryen)" >&2
  exit 1
fi

slug_lower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

should_skip_wasm_for_slug() {
  local slug="$1"
  [[ "$(slug_lower "$slug")" == "$(slug_lower "$LOGIN_SLUG")" ]]
}

patch_client_index_js() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "error: ${file} missing" >&2
    exit 1
  fi
  # PackageToJS emits a default fetch for the product wasm; bootstrap.js always passes module.
  perl -0777 -pi -e '
    s/if \(!module\) \{\s*module = fetch\(new URL\([^)]+\)\)\s*\}/if (!module) {\n    throw new Error("init requires options.module");\n  }/s
  ' "$file"
}

copy_page_js_runtime() {
  local src_dir="$1"
  cp "$src_dir/instantiate.js" "$src_dir/runtime.js" "$OUT_JS/"
  cp "$src_dir/platforms/browser.js" "$OUT_JS/platforms/"
  perl -pi -e "s|'\\@bjorn3/browser_wasi_shim'|'../browser_wasi_shim.js'|g" \
    "$OUT_JS/platforms/browser.js"
}

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
cp "$WASM" "$ASSETS/WASMNav.wasm"
patch_client_index_js "$OUT_JS/index.js"

# WASI shim is committed under Sources/ShapeTreeWebAssets/Vendor/ and served locally.
perl -pi -e "s|'\\@bjorn3/browser_wasi_shim'|'../browser_wasi_shim.js'|g" \
  "$OUT_JS/platforms/browser.js"

echo "Wrote client JS to ${OUT_JS}"
echo "Wrote ${ASSETS}/WASMNav.wasm"

# --- Per-page WASM: generate one .wasm per markdown file ---

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

echo "Generating per-page Swift sources from ${CONTENT_PATH}..."
rm -rf "$PAGES_DIR"
mkdir -p "$PAGES_DIR"
mkdir -p "$POST_PKG/.build"

MD_FILES=()
while IFS= read -r f; do
  MD_FILES+=("$f")
done < <(find "$CONTENT_PATH" -name "*.md" -type f | sort)

BUILD_MD_FILES=()
SKIPPED_SLUGS=()
for f in "${MD_FILES[@]}"; do
  slug="$(basename "$f" .md)"
  if should_skip_wasm_for_slug "$slug"; then
    SKIPPED_SLUGS+=("$slug")
    continue
  fi
  BUILD_MD_FILES+=("$f")
done

if [[ ${#SKIPPED_SLUGS[@]} -gt 0 ]]; then
  echo "Skipping wasm build for login slug(s): ${SKIPPED_SLUGS[*]}"
fi

if [[ ${#BUILD_MD_FILES[@]} -eq 0 ]] && [[ ! -f "$POST_PKG/custom-pages.manifest" ]]; then
  echo "error: no markdown files to build under ${CONTENT_PATH}" >&2
  exit 1
fi

if [[ ${#BUILD_MD_FILES[@]} -gt 0 ]]; then
  "$GENERATOR" "$PAGES_DIR" "$POST_PKG/Package.swift" "$MANIFEST" "${BUILD_MD_FILES[@]}"
else
  : > "$MANIFEST"
  cat > "$POST_PKG/Package.swift" <<'EOF'
// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "WasmPost",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.37.0"),
  ],
  targets: [
  ]
)
EOF
fi

append_custom_page_targets() {
  local custom="$POST_PKG/custom-pages.manifest"
  local pkg="$POST_PKG/Package.swift"
  local fragment="$POST_PKG/.build/custom-targets.fragment"
  [[ -f "$custom" ]] || return 0

  : > "$fragment"
  while IFS='=' read -r target slug; do
    [[ -z "$target" || -z "$slug" ]] && continue
    local source="${slug}.swift"
    if [[ ! -f "$POST_PKG/Sources/CustomPages/$source" ]]; then
      echo "error: custom page source missing: Sources/CustomPages/$source" >&2
      exit 1
    fi
    echo "${target}=${slug}" >> "$MANIFEST"
    cat >> "$fragment" <<EOF
    .executableTarget(
      name: "${target}",
      dependencies: [.product(name: "JavaScriptKit", package: "JavaScriptKit")],
      path: "Sources/CustomPages",
      sources: ["${source}"],
      swiftSettings: [
        .enableExperimentalFeature("Extern"),
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-Osize"], .when(configuration: .release)),
      ]
    ),
EOF
    echo "Registered custom wasm page: ${slug} (${source})"
  done < "$custom"

  python3 - "$pkg" "$fragment" <<'PY'
import sys
from pathlib import Path

pkg_path = Path(sys.argv[1])
fragment_path = Path(sys.argv[2])
text = pkg_path.read_text()
fragment = fragment_path.read_text()
needle = "  ]\n)"
if needle not in text:
    raise SystemExit(f"could not find targets closing in {pkg_path}")
pkg_path.write_text(text.replace(needle, fragment + needle, 1))
PY
}

append_custom_page_targets

echo "Building per-page WASM modules..."
rm -rf "$WASM_POSTS_DIR"
mkdir -p "$WASM_POSTS_DIR"

PAGE_JS_DIR=""
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
  PAGE_JS_DIR="$PAGE_BUILD_DIR"
done <"$MANIFEST"

# Shared JS runtime for page wasm — keep WASMNav index.js (do not overwrite).
if [[ -n "$PAGE_JS_DIR" ]]; then
  copy_page_js_runtime "$PAGE_JS_DIR"
fi

PAGE_COUNT=$(ls "$WASM_POSTS_DIR"/*.wasm 2>/dev/null | wc -l | tr -d ' ')
echo "Wrote $PAGE_COUNT per-page wasm(s) to ${WASM_POSTS_DIR} (index slug: ${INDEX_SLUG})"

echo "Run: swift build && swift run ShapeTreeWeb"
