#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/../.." && pwd)"

echo "=== ShapeTree framework (core wasm) ==="
bash "$ROOT/Scripts/build-core.sh"

if [[ -f "$REPO_ROOT/examples/shape-tree-site/Scripts/build-site.sh" ]]; then
  echo ""
  echo "=== Example site (demo content) ==="
  bash "$REPO_ROOT/examples/shape-tree-site/Scripts/build-site.sh"
fi

echo ""
echo "Run: cd apps/shape-tree-web && swift build && swift run ShapeTreeWeb"
