#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIGURATION="${CONFIGURATION:-release}" ./script/build_and_run.sh --package >/dev/null

APP_BUNDLE="$ROOT_DIR/dist/Codex Reset Watcher.app"
ZIP_PATH="$ROOT_DIR/dist/Codex Reset Watcher.zip"

VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$APP_BUNDLE/Contents/Info.plist")"
VERSIONED_ZIP_PATH="$ROOT_DIR/dist/Codex.Reset.Watcher.v$VERSION.zip"

rm -f "$ZIP_PATH" "$ROOT_DIR"/dist/Codex.Reset.Watcher.v*.zip
ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
cp "$ZIP_PATH" "$VERSIONED_ZIP_PATH"

echo "$APP_BUNDLE"
echo "$ZIP_PATH"
echo "$VERSIONED_ZIP_PATH"
