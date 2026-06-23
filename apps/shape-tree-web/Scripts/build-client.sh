#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/../.." && pwd)"

echo "=== ShapeTree framework (core wasm) ==="
bash "$ROOT/Scripts/build-core.sh"

SITE_DIR="$REPO_ROOT/examples/st-gen-markdown"
if [[ -d "$SITE_DIR" && -f "$SITE_DIR/Package.swift" ]]; then
  echo ""
  echo "=== Example site (demo content) ==="
  (
    cd "$SITE_DIR"
    swift build --product BuildPage || exit 1
    while IFS= read -r -d '' md; do
      "$SITE_DIR/.build/debug/BuildPage" "$md" || exit 1
    done < <(find "$SITE_DIR/content-src" -name '*.md' -type f -print0)
  )
fi

echo ""
echo "Run: cd apps/shape-tree-web && swift build && swift run ShapeTreeWeb"
