#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-}"
RELEASE_LINK="${RELEASE_LINK:-}"
SPARKLE_PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:-}"

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

  local generate_appcast
  local key_file

  generate_appcast="$(find_generate_appcast)"
  [[ -n "$generate_appcast" ]] || fail "Could not find generate_appcast. Add Sparkle tooling before generating appcast.xml."

  key_file="$(mktemp)"
  trap 'rm -f "$key_file"' EXIT
  printf '%s' "$SPARKLE_PRIVATE_KEY" > "$key_file"

  curl -fsSL "$RELEASE_LINK/releases/latest/download/appcast.xml" -o "$DIST_DIR/appcast.xml" 2>/dev/null || true

  "$generate_appcast" \
    --ed-key-file "$key_file" \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX/" \
    --link "$RELEASE_LINK" \
    "$DIST_DIR"
}

main "$@"
