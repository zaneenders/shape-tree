#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK=x86_64-swift-linux-musl

echo "=== Building ShapeTreeWeb WASM client ==="
cd "$ROOT/apps/shape-tree-web"
if [[ -f Scripts/build-client.sh ]]; then
  bash Scripts/build-client.sh
fi

echo "=== Building ShapeTreeWeb (Linux) ==="
swift build -c release --swift-sdk "$SDK" --product ShapeTreeWeb

echo "=== Building ShapeTree API (Linux) ==="
cd "$ROOT/apps/shape-tree-api"
swift build -c release --swift-sdk "$SDK" --product ShapeTree

echo ""
echo "Binaries built. Next steps:"
echo "  docker compose build"
echo "  docker compose up -d"
