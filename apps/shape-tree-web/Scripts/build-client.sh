#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/../wasm-client"
POST_PKG="$ROOT/../wasm-post"
ASSETS="$ROOT/Sources/ShapeTreeWebAssets"
OUT_JS="$ASSETS/client"
BUILD_DIR="$CLIENT/.build/js"
# Per-page nodes are trivial and build tiny in Embedded mode. The core driver uses
# JavaScriptKit promises/DOM building, which pulls Unicode tables only the full SDK has.
SDK="${SWIFT_WASM_SDK:-swift-6.3.2-RELEASE_wasm-embedded}"
CORE_SDK="${SWIFT_WASM_CORE_SDK:-swift-6.3.2-RELEASE_wasm}"

# Demo authoring reads markdown; runtime serves wasm from CONTENT_OUTPUT.
ENV_FILE="$ROOT/.env"
read_env() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- || true; }
if [[ -f "$ENV_FILE" ]]; then
  CONTENT_SOURCE_PATH="${CONTENT_SOURCE_PATH:-$(read_env CONTENT_SOURCE_PATH)}"
  CONTENT_OUTPUT="${CONTENT_OUTPUT:-$(read_env CONTENT_OUTPUT)}"
  INDEX_PATH="${INDEX_PATH:-$(read_env INDEX_PATH)}"
  INDEX_PATH="${INDEX_PATH:-$(read_env INDEX_SLUG)}"
  LOGIN_SLUG="${LOGIN_SLUG:-$(read_env LOGIN_SLUG)}"
fi
CONTENT_SOURCE_PATH="${CONTENT_SOURCE_PATH:-$ROOT/Examples/content}"
CONTENT_OUTPUT="${CONTENT_OUTPUT:-$ROOT/content}"
INDEX_PATH="${INDEX_PATH:-Home}"
LOGIN_SLUG="${LOGIN_SLUG:-login}"

export PATH="${HOME}/.swiftly/bin:${PATH}"

for required_sdk in "$SDK" "$CORE_SDK"; do
  if ! swift sdk list 2>/dev/null | grep -qx "$required_sdk"; then
    echo "error: wasm SDK '$required_sdk' not installed (see README → Swift WASM)" >&2
    exit 1
  fi
done

if ! command -v wasm-opt >/dev/null; then
  echo "error: wasm-opt not found (brew install binaryen)" >&2
  exit 1
fi

slug_lower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

should_skip_wasm_for_path() {
  local path="$1"
  local base
  base="$(basename "$path")"
  [[ "$(slug_lower "$base")" == "$(slug_lower "$LOGIN_SLUG")" ]]
}

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

copy_page_js_runtime() {
  local src_dir="$1"
  cp "$src_dir/instantiate.js" "$src_dir/runtime.js" "$OUT_JS/"
  cp "$src_dir/platforms/browser.js" "$OUT_JS/platforms/"
  perl -pi -e "s|'\\@bjorn3/browser_wasi_shim'|'../browser_wasi_shim.js'|g" \
    "$OUT_JS/platforms/browser.js"
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

GEN_PKG="$POST_PKG/Generator"
PAGES_DIR="$POST_PKG/Sources/Pages"
MANIFEST="$POST_PKG/.build/manifest.txt"
META_DIR="$POST_PKG/.build/meta"

echo "Building ContentGenerator..."
(
  cd "$GEN_PKG"
  swift build -c release 2>&1
)
GENERATOR="$GEN_PKG/.build/release/ContentGenerator"

echo "Generating per-page Swift sources from ${CONTENT_SOURCE_PATH}..."
rm -rf "$PAGES_DIR" "$META_DIR"
mkdir -p "$PAGES_DIR" "$META_DIR" "$POST_PKG/.build"

MD_FILES=()
if [[ -d "$CONTENT_SOURCE_PATH" ]]; then
  while IFS= read -r f; do
    MD_FILES+=("$f")
  done < <(find "$CONTENT_SOURCE_PATH" -name "*.md" -type f | sort)
fi

BUILD_MD_FILES=()
SKIPPED_PATHS=()
for f in "${MD_FILES[@]+"${MD_FILES[@]}"}"; do
  rel="${f#"$CONTENT_SOURCE_PATH"/}"
  path="${rel%.md}"
  if should_skip_wasm_for_path "$path"; then
    SKIPPED_PATHS+=("$path")
    continue
  fi
  BUILD_MD_FILES+=("$f")
done

if [[ ${#SKIPPED_PATHS[@]} -gt 0 ]]; then
  echo "Skipping wasm build for login path(s): ${SKIPPED_PATHS[*]}"
fi

if [[ ${#BUILD_MD_FILES[@]} -eq 0 ]] && [[ ! -f "$POST_PKG/custom-pages.manifest" ]]; then
  echo "error: no markdown files to build under ${CONTENT_SOURCE_PATH}" >&2
  exit 1
fi

if [[ ${#BUILD_MD_FILES[@]} -gt 0 ]]; then
  "$GENERATOR" \
    "$PAGES_DIR" \
    "$POST_PKG/Package.swift" \
    "$MANIFEST" \
    "$META_DIR" \
    "$CONTENT_SOURCE_PATH" \
    "${BUILD_MD_FILES[@]}"
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
  while IFS='=' read -r target content_path; do
    [[ -z "$target" || -z "$content_path" ]] && continue
    local source="${content_path}.swift"
    if [[ ! -f "$POST_PKG/Sources/CustomPages/$source" ]]; then
      echo "error: custom page source missing: Sources/CustomPages/$source" >&2
      exit 1
    fi
    echo "${target}=${content_path}" >> "$MANIFEST"
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
    echo "Registered custom wasm page: ${content_path} (${source})"
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

echo "Building per-page WASM modules into ${CONTENT_OUTPUT}..."
rm -rf "$CONTENT_OUTPUT"
mkdir -p "$CONTENT_OUTPUT"

PAGE_JS_DIR=""
while IFS='=' read -r target content_path; do
  [[ -z "$target" || -z "$content_path" ]] && continue
  echo "  Building ${content_path}..."
  safe_target="${target//\//_}"
  PAGE_BUILD_DIR="$POST_PKG/.build/js-${safe_target}"
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

  dest_dir="$CONTENT_OUTPUT/$(dirname "$content_path")"
  mkdir -p "$dest_dir"
  cp "$PAGE_WASM" "$CONTENT_OUTPUT/${content_path}.wasm"

  meta_src="$META_DIR/${content_path}.meta.json"
  if [[ -f "$meta_src" ]]; then
    cp "$meta_src" "$CONTENT_OUTPUT/${content_path}.meta.json"
  fi

  PAGE_JS_DIR="$PAGE_BUILD_DIR"
done <"$MANIFEST"

if [[ -f "$POST_PKG/custom-pages.manifest" ]]; then
  while IFS='=' read -r _ content_path; do
    [[ -z "$content_path" ]] && continue
    meta_dest="$CONTENT_OUTPUT/${content_path}.meta.json"
    if [[ ! -f "$meta_dest" ]]; then
      mkdir -p "$(dirname "$meta_dest")"
      case "$content_path" in
        Apps/Canvas) printf '{"title":"Canvas"}' >"$meta_dest" ;;
      esac
    fi
  done <"$POST_PKG/custom-pages.manifest"
fi

if [[ -n "$PAGE_JS_DIR" ]]; then
  copy_page_js_runtime "$PAGE_JS_DIR"
fi

PAGE_COUNT=$(find "$CONTENT_OUTPUT" -name '*.wasm' | wc -l | tr -d ' ')
echo "Wrote ${PAGE_COUNT} wasm node(s) to ${CONTENT_OUTPUT} (index path: ${INDEX_PATH})"
echo "Run: swift build && swift run ShapeTreeWeb"
