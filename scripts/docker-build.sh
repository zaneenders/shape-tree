#!/usr/bin/env bash
set -euo pipefail

# Build configuration: "debug" or "release"
BUILD_CONFIG="debug"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Pick the Swift static-Linux SDK matching the host arch so the resulting
# binary runs natively on the matching Docker image (arm64 Mac -> arm64 Linux,
# Intel Mac -> amd64 Linux). Avoids QEMU emulation, which currently spins
# inside swift-otel's HTTP client init.
HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
arm64 | aarch64) SDK="aarch64-swift-linux-musl" ;;
x86_64) SDK="x86_64-swift-linux-musl" ;;
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

echo "=== Building ShapeTreeWeb WASM client (core) ==="
cd "$ROOT/apps/shape-tree-web"
if [[ -f Scripts/build-core.sh ]]; then
  bash Scripts/build-core.sh
fi

echo "=== Building example site content ==="
if [[ -f "$ROOT/examples/shape-tree-site/Scripts/build-site.sh" ]]; then
  bash "$ROOT/examples/shape-tree-site/Scripts/build-site.sh"
fi

echo "=== Building ShapeTreeWeb (Linux) ==="
swift build -c "$BUILD_CONFIG" --swift-sdk "$SDK" --product ShapeTreeWeb

echo "=== Building ShapeTree API (Linux) ==="
cd "$ROOT/apps/shape-tree-api"
swift build -c "$BUILD_CONFIG" --swift-sdk "$SDK" --product ShapeTree

cd "$ROOT"
# The Dockerfiles auto-select the binary matching the build arch via BuildKit's
# TARGETARCH (defaults to the host arch). No per-arch build args needed.
echo "=== docker compose build (arch: $HOST_ARCH, config: $BUILD_CONFIG) ==="
docker compose build --build-arg "BUILD_CONFIG=$BUILD_CONFIG"

if [[ "${1:-}" == "up" ]]; then
  exec docker compose up "${@:2}"
fi

echo ""
echo "Built. Next:  ./scripts/docker-build.sh up"
