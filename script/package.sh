#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIGURATION="${CONFIGURATION:-release}" ./script/build_and_run.sh --package >/dev/null

APP_BUNDLE="$ROOT_DIR/dist/Codex Reset Watcher.app"
ZIP_PATH="$ROOT_DIR/dist/Codex Reset Watcher.zip"

rm -f "$ZIP_PATH"
ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "$APP_BUNDLE"
echo "$ZIP_PATH"
