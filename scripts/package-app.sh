#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/.build/archive/RawComp.xcarchive}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build/archive-derived}"
APP_NAME="${APP_NAME:-RawComp}"
APP_VERSION_SOURCE="${APP_VERSION_SOURCE:-$ROOT_DIR/Sources/RawComp/AppVersion.swift}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
SPARKLE_PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:-}"
APP_DIR="$OUTPUT_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
EXECUTABLE_PATH="$ARCHIVE_PATH/Products/usr/local/bin/$APP_NAME"
RESOURCE_BUNDLE_PATH="$DERIVED_DATA_PATH/Build/Intermediates.noindex/ArchiveIntermediates/$APP_NAME/IntermediateBuildFilesPath/UninstalledProducts/macosx/${APP_NAME}_${APP_NAME}.bundle"
SPARKLE_XCFRAMEWORK_DIR="$DERIVED_DATA_PATH/SourcePackages/artifacts/sparkle/Sparkle/Sparkle.xcframework"
PLIST_PATH="$CONTENTS_DIR/Info.plist"
ICON_SOURCE="$ROOT_DIR/Sources/$APP_NAME/Resources/RawCompIcon.png"
ICON_TARGET="$RESOURCES_DIR/RawCompIcon.png"
ICONSET_DIR="$OUTPUT_DIR/RawComp.iconset"
ICNS_PATH="$RESOURCES_DIR/RawComp.icns"

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

derive_public_ed_key() {
  /usr/bin/env swift - "$SPARKLE_PRIVATE_KEY" <<'SWIFT'
import CryptoKit
import Foundation

guard CommandLine.arguments.count == 2,
      let privateKeyData = Data(base64Encoded: CommandLine.arguments[1]),
      let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
else {
    exit(1)
}

print(privateKey.publicKey.rawRepresentation.base64EncodedString())
SWIFT
}

write_info_plist() {
  local marketing_version="$1"
  local build_number="$2"

  cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>RawComp</string>
  <key>CFBundleIdentifier</key>
  <string>com.rawcomp.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${marketing_version}</string>
  <key>CFBundleVersion</key>
  <string>${build_number}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
EOF

  if [[ -n "$SPARKLE_FEED_URL" ]]; then
    cat >> "$PLIST_PATH" <<EOF
  <key>SUFeedURL</key>
  <string>${SPARKLE_FEED_URL}</string>
EOF
  fi

  if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    cat >> "$PLIST_PATH" <<EOF
  <key>SUPublicEDKey</key>
  <string>${SPARKLE_PUBLIC_ED_KEY}</string>
EOF
  fi

  cat >> "$PLIST_PATH" <<EOF
</dict>
</plist>
EOF
}

create_icns() {
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
  rm -rf "$ICONSET_DIR"
}

resolve_sparkle_framework_path() {
  local candidate

  for candidate in \
    "$SPARKLE_XCFRAMEWORK_DIR/macos-arm64_x86_64/Sparkle.framework" \
    "$(find "$DERIVED_DATA_PATH/SourcePackages/artifacts" -path '*/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework' -type d 2>/dev/null | head -n 1)"; do
    if [[ -n "$candidate" && -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

copy_sparkle_framework() {
  local sparkle_framework_path=""

  sparkle_framework_path="$(resolve_sparkle_framework_path || true)"
  if [[ -z "$sparkle_framework_path" ]]; then
    return
  fi

  mkdir -p "$FRAMEWORKS_DIR"
  ditto "$sparkle_framework_path" "$FRAMEWORKS_DIR/Sparkle.framework"
}

main() {
  require_cmd perl
  require_cmd ditto
  require_cmd sips
  require_cmd iconutil
  require_cmd install_name_tool
  require_cmd codesign

  [[ -f "$EXECUTABLE_PATH" ]] || fail "Archived executable not found: ${EXECUTABLE_PATH}"
  [[ -d "$RESOURCE_BUNDLE_PATH" ]] || fail "Resource bundle not found: ${RESOURCE_BUNDLE_PATH}"
  [[ -f "$APP_VERSION_SOURCE" ]] || fail "Version source file not found: ${APP_VERSION_SOURCE}"
  [[ -f "$ICON_SOURCE" ]] || fail "App icon source not found: ${ICON_SOURCE}"
  if [[ -n "$SPARKLE_FEED_URL" && -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    if [[ -n "$SPARKLE_PRIVATE_KEY" ]]; then
      SPARKLE_PUBLIC_ED_KEY="$(derive_public_ed_key)" || fail "Could not derive SUPublicEDKey from SPARKLE_PRIVATE_KEY"
    else
      fail "SPARKLE_PUBLIC_ED_KEY or SPARKLE_PRIVATE_KEY is required when SPARKLE_FEED_URL is set"
    fi
  fi

  local marketing_version
  local build_number

  marketing_version="$(extract_value "marketingVersion")"
  build_number="$(extract_value "buildNumber")"

  [[ -n "$marketing_version" ]] || fail "Could not read marketingVersion from ${APP_VERSION_SOURCE}"
  [[ -n "$build_number" ]] || fail "Could not read buildNumber from ${APP_VERSION_SOURCE}"

  rm -rf "$APP_DIR"
  mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

  ditto "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
  chmod +x "$MACOS_DIR/$APP_NAME"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME"
  ditto "$RESOURCE_BUNDLE_PATH" "$RESOURCES_DIR/$(basename "$RESOURCE_BUNDLE_PATH")"
  ditto "$ICON_SOURCE" "$ICON_TARGET"
  copy_sparkle_framework
  create_icns
  write_info_plist "$marketing_version" "$build_number"
  codesign --force --deep --sign - "$APP_DIR" >/dev/null

  printf 'Packaged app: %s\n' "$APP_DIR"
}

main "$@"
