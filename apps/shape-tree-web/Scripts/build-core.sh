#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/../wasm-client"
ASSETS="$ROOT/Sources/ShapeTreeWebAssets"
OUT_JS="$ASSETS/client"
BUILD_DIR="$CLIENT/.build/js"
CORE_SDK="${SWIFT_WASM_CORE_SDK:-swift-6.3.2-RELEASE_wasm-embedded}"
REGEN_JS=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [--regen-js]

  (default)  Rebuild ShapeTreeCore.wasm (gitignored); keep vendored client/*.js.
  --regen-js Also refresh JavaScriptKit / BridgeJS glue in Sources/ShapeTreeWebAssets/client/.
             Run after bumping JavaScriptKit or the wasm SDK.

Requires: Swiftly wasm SDK ($CORE_SDK), wasm-opt (binaryen).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --regen-js) REGEN_JS=true; shift ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "error: unknown argument: $1" >&2
    usage >&2
    exit 1
    ;;
  esac
done

export PATH="${HOME}/.swiftly/bin:${PATH}"

if ! swift sdk list 2>/dev/null | grep -qx "$CORE_SDK"; then
  echo "error: wasm SDK '$CORE_SDK' not installed (see README → Swift WASM)" >&2
  exit 1
fi

if ! command -v wasm-opt >/dev/null; then
  echo "error: wasm-opt not found (brew install binaryen)" >&2
  exit 1
fi

echo "Building ShapeTreeCore with ${CORE_SDK}..."
rm -rf "$BUILD_DIR" "$CLIENT/.build/plugins/PackageToJS/outputs/js.tmp"
(
  cd "$CLIENT"
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
cp "$WASM" "$ASSETS/ShapeTreeCore.wasm"
echo "Wrote ${ASSETS}/ShapeTreeCore.wasm"

if [[ "$REGEN_JS" == true ]]; then
  rm -rf "$OUT_JS"
  mkdir -p "$OUT_JS/platforms"
  cp "$BUILD_DIR/index.js" "$BUILD_DIR/instantiate.js" "$BUILD_DIR/runtime.js" "$OUT_JS/"
  cp "$BUILD_DIR/platforms/browser.js" "$OUT_JS/platforms/"
  if [[ -f "$BUILD_DIR/bridge-js.js" ]]; then
    cp "$BUILD_DIR/bridge-js.js" "$OUT_JS/"
  fi
  JAVASCRIPTKIT_VERSION="$(
    python3 - "$CLIENT/Package.resolved" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
if not path.is_file():
    print("unknown")
    raise SystemExit(0)
data = json.loads(path.read_text())
for pin in data.get("pins", []):
    if pin.get("identity") == "javascriptkit":
        print(pin["state"]["version"])
        break
else:
    print("unknown")
PY
  )"
  cat >"$OUT_JS/VENDOR.txt" <<EOF
# Vendored JavaScriptKit browser glue for ShapeTreeCore.
# Regenerate with: ./Scripts/build-core.sh --regen-js
javascriptkit=${JAVASCRIPTKIT_VERSION}
swift-wasm-sdk=${CORE_SDK}
generated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
  echo "Refreshed vendored client JS in ${OUT_JS}"
else
  if [[ ! -f "$OUT_JS/index.js" || ! -f "$OUT_JS/runtime.js" ]]; then
    echo "error: vendored client JS missing at ${OUT_JS}; run with --regen-js" >&2
    exit 1
  fi
  echo "Kept vendored client JS in ${OUT_JS} (pass --regen-js to refresh)"
fi
