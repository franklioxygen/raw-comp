#!/usr/bin/env bash
# Build RawComp and launch as a real .app bundle (fixes missing CFBundleIdentifier in Xcode console).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="RawComp"
APP="$ROOT/dist/${APP_NAME}-Debug.app"
BIN="$ROOT/.build/debug/${APP_NAME}"
PLIST_SRC="$ROOT/Sources/RawComp/Info.plist"

cd "$ROOT"
swift build -c debug

RESOURCE_BUNDLE="$(find "$ROOT/.build/debug" -name "${APP_NAME}_${APP_NAME}.bundle" -print -quit 2>/dev/null || true)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$PLIST_SRC" "$APP/Contents/Info.plist"

if [[ -n "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
fi

# Sparkle (SwiftPM debug link path)
SPARKLE_FW="$(find "$ROOT/.build" -name 'Sparkle.framework' -print -quit 2>/dev/null || true)"
if [[ -n "$SPARKLE_FW" ]]; then
  mkdir -p "$APP/Contents/Frameworks"
  rsync -a "$SPARKLE_FW" "$APP/Contents/Frameworks/"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/$APP_NAME" 2>/dev/null || true
fi

echo "Launching $APP"
open "$APP"
