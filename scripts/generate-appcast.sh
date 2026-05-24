#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APPCAST_PATH="${APPCAST_PATH:-$DIST_DIR/appcast.xml}"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-}"
RELEASE_LINK="${RELEASE_LINK:-}"
SPARKLE_PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:-}"
KEY_FILE=""

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

find_generate_appcast() {
  if command -v generate_appcast >/dev/null 2>&1; then
    command -v generate_appcast
    return 0
  fi

  find "$ROOT_DIR" -name generate_appcast -type f 2>/dev/null | head -n 1
}

main() {
  [[ -n "$DOWNLOAD_URL_PREFIX" ]] || fail "DOWNLOAD_URL_PREFIX is required"
  [[ -n "$RELEASE_LINK" ]] || fail "RELEASE_LINK is required"
  [[ -n "$SPARKLE_PRIVATE_KEY" ]] || fail "SPARKLE_PRIVATE_KEY is required"
  [[ -d "$DIST_DIR" ]] || fail "Distribution directory not found: ${DIST_DIR}"
  mkdir -p "$(dirname "$APPCAST_PATH")"

  local generate_appcast

  generate_appcast="$(find_generate_appcast)"
  [[ -n "$generate_appcast" ]] || fail "Could not find generate_appcast. Add Sparkle tooling before generating appcast.xml."

  KEY_FILE="$(mktemp)"
  trap 'rm -f "${KEY_FILE:-}"' EXIT
  printf '%s' "$SPARKLE_PRIVATE_KEY" > "$KEY_FILE"

  curl -fsSL "$RELEASE_LINK/releases/latest/download/appcast.xml" -o "$APPCAST_PATH" 2>/dev/null || true

  "$generate_appcast" \
    --ed-key-file "$KEY_FILE" \
    -o "$APPCAST_PATH" \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX/" \
    --link "$RELEASE_LINK" \
    "$DIST_DIR"
}

main "$@"
