#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/NeonDesk.app"
SAVER="$BUILD/NeonDesk.saver"
SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macos14.0"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mkdir -p "$SAVER/Contents/MacOS" "$SAVER/Contents/Resources"

cp "$ROOT/Sources/NeonDesk/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Sources/NeonDeskSaver/Info.plist" "$SAVER/Contents/Info.plist"

CORE=("$ROOT"/Sources/NeonDeskCore/*.swift)
APP_SRC=("$ROOT"/Sources/NeonDesk/*.swift)
SAVER_SRC=("$ROOT"/Sources/NeonDeskSaver/*.swift)

swiftc -O -whole-module-optimization \
  -target "$TARGET" \
  -sdk "$SDK" \
  -framework AppKit \
  -framework Cocoa \
  -framework ServiceManagement \
  -framework IOKit \
  -framework Carbon \
  -framework CoreGraphics \
  -framework QuartzCore \
  -o "$APP/Contents/MacOS/NeonDesk" \
  "${CORE[@]}" \
  "${APP_SRC[@]}"

swiftc -O \
  -target "$TARGET" \
  -sdk "$SDK" \
  -emit-library \
  -Xlinker -bundle \
  -framework ScreenSaver \
  -framework AppKit \
  -framework CoreGraphics \
  -o "$SAVER/Contents/MacOS/NeonDesk" \
  "${CORE[@]}" \
  "${SAVER_SRC[@]}"

if [[ -f "$ROOT/state/AppIcon.icns" ]]; then
  cp "$ROOT/state/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist"
fi

codesign --force --deep -s - "$APP"
codesign --force --deep -s - "$SAVER"

echo "Built $APP"
echo "Built $SAVER"
