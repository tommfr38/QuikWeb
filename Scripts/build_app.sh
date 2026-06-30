#!/usr/bin/env bash
# Builds QuikWeb.app from source: regenerates icons from Icons/*.svg, builds
# the SPM release binary, assembles a real .app bundle by hand (no Xcode
# project involved), and ad-hoc codesigns it for local use.
set -euo pipefail

APP_NAME="QuikWeb"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT/build/${APP_NAME}.app"

cd "$ROOT"

echo "==> Generating icons from SVG sources"
swift Scripts/GenerateIcons.swift

echo "==> Building release binary"
swift build -c release --package-path "$ROOT"
BIN_DIR="$(swift build -c release --package-path "$ROOT" --show-bin-path)"
BIN_PATH="$BIN_DIR/${APP_NAME}"

echo "==> Assembling AppIcon.icns"
ICONSET="$ROOT/build/GeneratedResources/AppIcon.iconset"
ICNS_PATH="$ROOT/build/GeneratedResources/AppIcon.icns"
iconutil -c icns "$ICONSET" -o "$ICNS_PATH"

echo "==> Assembling app bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ICNS_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$ROOT/build/GeneratedResources/"*.png "$APP_BUNDLE/Contents/Resources/"

echo "==> Code signing (ad-hoc)"
codesign --force --sign - "$APP_BUNDLE"

echo "==> Clearing quarantine attribute for local testing"
xattr -cr "$APP_BUNDLE" || true

echo "==> Verifying"
plutil -lint "$APP_BUNDLE/Contents/Info.plist"
codesign --verify --verbose "$APP_BUNDLE"

echo ""
echo "Built: $APP_BUNDLE"
echo "Run it with: open \"$APP_BUNDLE\""
echo "Install it with: Scripts/install.sh"
