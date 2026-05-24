#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
APP_NAME="${APP_NAME:-RawComp}"
APP_VERSION_SOURCE="${APP_VERSION_SOURCE:-$ROOT_DIR/Sources/RawComp/AppVersion.swift}"
APP_DIR="$OUTPUT_DIR/${APP_NAME}.app"
STAGING_DIR="$OUTPUT_DIR/dmg-root"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

extract_value() {
  local key="$1"
  perl -ne "if (/${key} = \"([^\"]+)\"/) { print \$1; exit }" "$APP_VERSION_SOURCE"
}

main() {
  require_cmd perl
  require_cmd hdiutil
  require_cmd ln

  [[ -d "$APP_DIR" ]] || fail "App bundle not found: ${APP_DIR}"
  [[ -f "$APP_VERSION_SOURCE" ]] || fail "Version source file not found: ${APP_VERSION_SOURCE}"

  local marketing_version
  local dmg_path

  marketing_version="$(extract_value "marketingVersion")"
  [[ -n "$marketing_version" ]] || fail "Could not read marketingVersion from ${APP_VERSION_SOURCE}"

  dmg_path="$OUTPUT_DIR/${APP_NAME}-${marketing_version}.dmg"

  rm -rf "$STAGING_DIR"
  mkdir -p "$STAGING_DIR"
  rm -f "$dmg_path"

  cp -R "$APP_DIR" "$STAGING_DIR/"
  ln -s /Applications "$STAGING_DIR/Applications"

  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -ov \
    "$dmg_path" >/dev/null

  rm -rf "$STAGING_DIR"

  printf 'Packaged dmg: %s\n' "$dmg_path"
}

main "$@"
