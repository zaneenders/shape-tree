#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Pick the Swift static-Linux SDK matching the host arch so the resulting
# binary runs natively on the matching Docker image (arm64 Mac -> arm64 Linux,
# Intel Mac -> amd64 Linux). Avoids QEMU emulation, which currently spins
# inside swift-otel's HTTP client init.
HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
  arm64|aarch64) SDK="aarch64-swift-linux-musl" ;;
  x86_64)        SDK="x86_64-swift-linux-musl" ;;
  *)
    echo "Unsupported host arch: $HOST_ARCH" >&2
    exit 1
    ;;
esac

if ! swift sdk list 2>/dev/null | grep -q "static-linux"; then
  echo "Static-Linux Swift SDK is not installed." >&2
  echo "Install with: swift sdk install <url-to-static-linux-sdk>" >&2
  echo "  (see https://www.swift.org/install/linux/tarball/ for the artifact bundle)" >&2
  exit 1
fi

echo "=== Host arch: $HOST_ARCH — using SDK: $SDK ==="

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

cd "$ROOT"
# The Dockerfiles auto-select the binary matching the build arch via BuildKit's
# TARGETARCH (defaults to the host arch). No per-arch build args needed.
echo "=== docker compose build (arch: $HOST_ARCH) ==="
docker compose build

echo ""
echo "Built. Next:  docker compose up -d"
