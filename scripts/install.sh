#!/usr/bin/env bash
# Copy this repo's plugin files into the live Omarchy plugin folder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/io.github.dankestrick.omagravastar"

mkdir -p "$DEST/qml" "$DEST/helpers"
cp -f "$ROOT/manifest.json" "$DEST/manifest.json"
cp -f "$ROOT/qml/"*.qml "$ROOT/qml/"*.js "$DEST/qml/"
cp -f "$ROOT/helpers/omagravastarctl" "$DEST/helpers/omagravastarctl"
chmod +x "$DEST/helpers/omagravastarctl"

echo "Installed to $DEST"
echo "If the service looks stale: omarchy restart shell"
