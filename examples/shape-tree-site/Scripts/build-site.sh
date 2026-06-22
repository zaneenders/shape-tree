#!/usr/bin/env bash
set -euo pipefail

SITE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
POST_PKG="$SITE_ROOT/wasm-post"
SDK="${SWIFT_WASM_SDK:-swift-6.3.2-RELEASE_wasm-embedded}"

ENV_FILE="$SITE_ROOT/.env"
read_env() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- || true; }
if [[ -f "$ENV_FILE" ]]; then
  CONTENT_SOURCE_PATH="${CONTENT_SOURCE_PATH:-$(read_env CONTENT_SOURCE_PATH)}"
  CONTENT_OUTPUT="${CONTENT_OUTPUT:-$(read_env CONTENT_OUTPUT)}"
  INDEX_PATH="${INDEX_PATH:-$(read_env INDEX_PATH)}"
  INDEX_PATH="${INDEX_PATH:-$(read_env INDEX_SLUG)}"
  LOGIN_SLUG="${LOGIN_SLUG:-$(read_env LOGIN_SLUG)}"
fi
CONTENT_SOURCE_PATH="${CONTENT_SOURCE_PATH:-$SITE_ROOT/content-src}"
CONTENT_OUTPUT="${CONTENT_OUTPUT:-$SITE_ROOT/content}"
INDEX_PATH="${INDEX_PATH:-Home}"
LOGIN_SLUG="${LOGIN_SLUG:-login}"

export PATH="${HOME}/.swiftly/bin:${PATH}"

if ! swift sdk list 2>/dev/null | grep -qx "$SDK"; then
  echo "error: wasm SDK '$SDK' not installed (see examples/shape-tree-site/README.md)" >&2
  exit 1
fi

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

CUSTOM_MANIFEST="-"
if [[ -f "$POST_PKG/custom-pages.manifest" ]]; then
  CUSTOM_MANIFEST="$POST_PKG/custom-pages.manifest"
fi

GENERATOR_ARGS=(
  "$PAGES_DIR"
  "$POST_PKG/Package.swift"
  "$MANIFEST"
  "$META_DIR"
  "$CONTENT_SOURCE_PATH"
  "$CUSTOM_MANIFEST"
)
if [[ ${#BUILD_MD_FILES[@]} -gt 0 ]]; then
  GENERATOR_ARGS+=("${BUILD_MD_FILES[@]}")
fi

"$GENERATOR" "${GENERATOR_ARGS[@]}"

echo "Building per-page WASM modules into ${CONTENT_OUTPUT}..."
rm -rf "$CONTENT_OUTPUT"
mkdir -p "$CONTENT_OUTPUT"

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

PAGE_COUNT=$(find "$CONTENT_OUTPUT" -name '*.wasm' | wc -l | tr -d ' ')
echo "Wrote ${PAGE_COUNT} wasm node(s) to ${CONTENT_OUTPUT} (index path: ${INDEX_PATH})"
