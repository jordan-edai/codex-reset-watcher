#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PRODUCT_NAME="CodexResetWatcher"
APP_NAME="Codex Reset Watcher"
BUNDLE_ID="com.jordanedai.codex-reset-watcher"
VERSION="0.4.2"
BUILD_NUMBER="1"
MIN_SYSTEM_VERSION="14.0"
CONFIGURATION="${CONFIGURATION:-debug}"
SCRATCH_PATH="${SWIFTPM_SCRATCH_PATH:-/tmp/codex-reset-watcher-build}"
SWIFT_BUILD_JOBS="${SWIFT_BUILD_JOBS:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$PRODUCT_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Assets/AppIcon.icns"
HEADER_ARTWORK="$ROOT_DIR/Assets/UsageHeader.png"

pkill -x "$PRODUCT_NAME" >/dev/null 2>&1 || true

if [[ "$CONFIGURATION" == "release" ]]; then
  RELEASE_BUILD_ARGS=(
    --scratch-path "$SCRATCH_PATH"
    --jobs "$SWIFT_BUILD_JOBS"
    -c release
    --arch arm64
    --arch x86_64
  )
  swift build "${RELEASE_BUILD_ARGS[@]}"
  BUILD_BIN_PATH="$(swift build "${RELEASE_BUILD_ARGS[@]}" --show-bin-path)"
  BUILD_BINARY="$BUILD_BIN_PATH/$PRODUCT_NAME"
else
  swift build --scratch-path "$SCRATCH_PATH" --jobs "$SWIFT_BUILD_JOBS"
  BUILD_BINARY="$SCRATCH_PATH/debug/$PRODUCT_NAME"
fi

if [[ ! -x "$BUILD_BINARY" ]]; then
  echo "Built executable not found: $BUILD_BINARY" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
if [[ "$CONFIGURATION" == "release" ]]; then
  /usr/bin/strip -S -x "$APP_BINARY"
  RELEASE_ARCHS="$(/usr/bin/lipo -archs "$APP_BINARY")"
  for REQUIRED_ARCH in arm64 x86_64; do
    if [[ " $RELEASE_ARCHS " != *" $REQUIRED_ARCH "* ]]; then
      echo "Release executable is missing $REQUIRED_ARCH: $RELEASE_ARCHS" >&2
      exit 1
    fi
  done
fi
if [[ -f "$APP_ICON" ]]; then
  cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
fi
if [[ -f "$HEADER_ARTWORK" ]]; then
  cp "$HEADER_ARTWORK" "$APP_RESOURCES/UsageHeader.png"
fi

/usr/bin/plutil -create xml1 "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleExecutable -string "$PRODUCT_NAME" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleIdentifier -string "$BUNDLE_ID" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleIconFile -string "AppIcon" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleName -string "$APP_NAME" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleDisplayName -string "$APP_NAME" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundlePackageType -string "APPL" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleShortVersionString -string "$VERSION" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleVersion -string "$BUILD_NUMBER" "$INFO_PLIST"
/usr/bin/plutil -insert LSApplicationCategoryType -string "public.app-category.developer-tools" "$INFO_PLIST"
/usr/bin/plutil -insert LSMinimumSystemVersion -string "$MIN_SYSTEM_VERSION" "$INFO_PLIST"
/usr/bin/plutil -insert NSPrincipalClass -string "NSApplication" "$INFO_PLIST"
/usr/bin/plutil -insert NSHumanReadableCopyright -string "Copyright © 2026 Jordan Wilson. Released under the MIT License." "$INFO_PLIST"

/usr/bin/codesign --force --sign - "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PRODUCT_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$PRODUCT_NAME" >/dev/null
    ;;
  --package|package)
    echo "$APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package]" >&2
    exit 2
    ;;
esac
