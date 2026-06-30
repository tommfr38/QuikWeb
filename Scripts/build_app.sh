#!/usr/bin/env bash
# Builds QuikWeb.app from source: regenerates icons from Icons/*.svg, builds
# the SPM release binary, assembles a real .app bundle by hand (no Xcode
# project involved), and ad-hoc codesigns it for local use.
#
# Set QUIKWEB_UNIVERSAL=1 to produce a universal (arm64 + x86_64) binary so
# the bundle runs on both Apple Silicon and Intel Macs (used by the installer).
set -euo pipefail

APP_NAME="QuikWeb"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT/build/${APP_NAME}.app"

cd "$ROOT"

# QuikWeb has zero third-party RUNTIME dependencies (only system frameworks),
# so an end user needs nothing but macOS. BUILDING it needs the Swift
# toolchain that ships with the Xcode Command Line Tools.
echo "==> Checking build dependencies"
missing=0
for tool in swift iconutil codesign plutil; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "  MISSING: $tool"
        missing=1
    fi
done
if [ "$missing" -ne 0 ]; then
    echo ""
    echo "The Xcode Command Line Tools are required to build QuikWeb."
    echo "Install them with:  xcode-select --install"
    echo "Then re-run this script."
    exit 1
fi
echo "  ok"

ARCH_FLAGS=""
if [ "${QUIKWEB_UNIVERSAL:-0}" = "1" ]; then
    ARCH_FLAGS="--arch arm64 --arch x86_64"
    echo "==> Universal build requested (arm64 + x86_64)"
fi

echo "==> Generating icons from SVG sources"
swift Scripts/GenerateIcons.swift

echo "==> Building release binary"
swift build -c release $ARCH_FLAGS --package-path "$ROOT"
BIN_DIR="$(swift build -c release $ARCH_FLAGS --package-path "$ROOT" --show-bin-path)"
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
lipo -info "$APP_BUNDLE/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

echo ""
echo "Built: $APP_BUNDLE"
echo "Run it with: open \"$APP_BUNDLE\""
echo "Install it with: Scripts/install.sh"
