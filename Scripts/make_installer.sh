#!/usr/bin/env bash
# Builds a double-click macOS installer (QuikWeb-Installer.pkg) for QuikWeb.
#
# The package is fully self-contained: QuikWeb has no third-party runtime
# dependencies (only Apple system frameworks), so the end user needs nothing
# but macOS 13+. The installer:
#   • installs QuikWeb.app into /Applications,
#   • clears the quarantine flag so it launches without the Gatekeeper prompt,
#   • launches QuikWeb right after installing.
#
# The app inside is built universal (arm64 + x86_64) so the installer works on
# both Apple Silicon and Intel Macs.
set -euo pipefail

APP_NAME="QuikWeb"
BUNDLE_ID="com.tomi.quikweb"
VERSION="1.0.0"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"

STAGE_DIR="$BUILD_DIR/pkg_root"          # payload root -> maps to /Applications
SCRIPTS_DIR="$BUILD_DIR/pkg_scripts"     # postinstall lives here
COMPONENT_PKG="$BUILD_DIR/${APP_NAME}-component.pkg"
DIST_XML="$BUILD_DIR/distribution.xml"
INSTALLER_PKG="$BUILD_DIR/${APP_NAME}-Installer.pkg"

cd "$ROOT"

echo "==> Checking installer dependencies"
for tool in pkgbuild productbuild pkgutil; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "  MISSING: $tool (ships with the Xcode Command Line Tools)"
        echo "  Install them with:  xcode-select --install"
        exit 1
    fi
done
echo "  ok"

# 1. Build a fresh, universal app bundle.
echo "==> Building universal app bundle"
QUIKWEB_UNIVERSAL=1 "$ROOT/Scripts/build_app.sh"

# 2. Stage the payload: a directory whose contents map onto /Applications.
echo "==> Staging payload"
rm -rf "$STAGE_DIR" "$SCRIPTS_DIR"
mkdir -p "$STAGE_DIR" "$SCRIPTS_DIR"
cp -R "$APP_BUNDLE" "$STAGE_DIR/${APP_NAME}.app"

# 3. postinstall: clear quarantine + launch as the logged-in user.
#    (Installer scripts run as root, so we hop into the console user's GUI
#    session to actually open the app.)
cat > "$SCRIPTS_DIR/postinstall" <<'POSTINSTALL'
#!/bin/bash
APP="/Applications/QuikWeb.app"

# Remove the quarantine flag the download/installer may have set, so the app
# opens without "unidentified developer" friction.
/usr/bin/xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

# Launch QuikWeb in the logged-in user's GUI session.
CONSOLE_USER="$(/usr/bin/stat -f%Su /dev/console)"
if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ]; then
    CONSOLE_UID="$(/usr/bin/id -u "$CONSOLE_USER")"
    /bin/launchctl asuser "$CONSOLE_UID" /usr/bin/open "$APP" || true
fi

exit 0
POSTINSTALL
chmod +x "$SCRIPTS_DIR/postinstall"

# 4. Build the component package (payload + scripts -> /Applications).
echo "==> Building component package"
pkgbuild \
    --root "$STAGE_DIR" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --install-location "/Applications" \
    --scripts "$SCRIPTS_DIR" \
    "$COMPONENT_PKG"

# 5. Wrap it in a product archive with a real title + macOS version gate.
echo "==> Building installer package"
cat > "$DIST_XML" <<DISTRIBUTION
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>${APP_NAME}</title>
    <organization>com.tomi</organization>
    <options customize="never" require-scripts="true" hostArchitectures="arm64,x86_64"/>
    <volume-check>
        <allowed-os-versions>
            <os-version min="13.0"/>
        </allowed-os-versions>
    </volume-check>
    <choices-outline>
        <line choice="default">
            <line choice="${BUNDLE_ID}"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="${BUNDLE_ID}" visible="false">
        <pkg-ref id="${BUNDLE_ID}"/>
    </choice>
    <pkg-ref id="${BUNDLE_ID}" version="${VERSION}" onConclusion="none">${APP_NAME}-component.pkg</pkg-ref>
</installer-gui-script>
DISTRIBUTION

productbuild \
    --distribution "$DIST_XML" \
    --package-path "$BUILD_DIR" \
    "$INSTALLER_PKG"

# 6. Clean up intermediates.
rm -rf "$STAGE_DIR" "$SCRIPTS_DIR" "$COMPONENT_PKG" "$DIST_XML"

echo ""
echo "==> Verifying installer"
pkgutil --check-signature "$INSTALLER_PKG" 2>&1 | head -n 3 || true
echo "Payload (first entries):"
pkgutil --payload-files "$INSTALLER_PKG" | head -n 8

echo ""
echo "Built installer: $INSTALLER_PKG"
echo "Double-click it to install QuikWeb (it's unsigned, so the first time you"
echo "may need to right-click the .pkg -> Open, or run:"
echo "  sudo installer -pkg \"$INSTALLER_PKG\" -target /"
