#!/usr/bin/env bash
# Copies the built QuikWeb.app into /Applications. SMAppService (the
# "launch at login" mechanism) is most reliable for apps run from a stable
# location like /Applications, so this is the recommended way to install it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT/build/QuikWeb.app"
DEST="/Applications/QuikWeb.app"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "QuikWeb.app hasn't been built yet. Run Scripts/build_app.sh first." >&2
    exit 1
fi

echo "Installing QuikWeb.app to /Applications…"
rm -rf "$DEST"
cp -R "$APP_BUNDLE" "$DEST"

echo "Installed to $DEST"
echo "Launch it with: open \"$DEST\""
