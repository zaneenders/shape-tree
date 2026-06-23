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
SITE_DIR="$ROOT/examples/st-gen-markdown"
if [[ -d "$SITE_DIR" && -f "$SITE_DIR/Package.swift" ]]; then
  (
    cd "$SITE_DIR"
    # Build the BuildPage tool once, then use it for every markdown page.
    # login.md is skipped by BuildPage (login UI lives in ShapeTreeCore).
    swift build --product BuildPage || exit 1
    BUILD_PAGE="$SITE_DIR/.build/debug/BuildPage"

    CONTENT_SRC="$ROOT/examples/content-src"
    while IFS= read -r -d '' md; do
      echo "  BuildPage ${md#$CONTENT_SRC/}"
      "$BUILD_PAGE" "$md" || exit 1
    done < <(find "$CONTENT_SRC" -name '*.md' -type f -print0)
  )
fi

echo "=== Building Canvas (custom wasm page) ==="
CANVAS_DIR="$ROOT/examples/st-canvas-demo"
if [[ -d "$CANVAS_DIR" && -f "$CANVAS_DIR/scripts/build.sh" ]]; then
  bash "$CANVAS_DIR/scripts/build.sh"
  # Copy canvas output into the site content tree.
  if [[ -d "$CANVAS_DIR/dist" ]]; then
    cp -R "$CANVAS_DIR/dist/." "$SITE_DIR/content/"
  fi
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
