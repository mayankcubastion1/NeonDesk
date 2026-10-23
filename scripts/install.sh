#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE="$ROOT/state"
APP_SRC="$ROOT/build/NeonDesk.app"
SAVER_SRC="$ROOT/build/NeonDesk.saver"
APP_DEST="$HOME/Applications/NeonDesk.app"
SAVER_DEST="$HOME/Library/Screen Savers/NeonDesk.saver"

mkdir -p "$STATE" "$HOME/Applications" "$HOME/Library/Screen Savers" "$HOME/Pictures/NeonDesk"

"$ROOT/build.sh"

# Backup dock so uninstall can restore it.
{
  echo "tilesize=$(defaults read com.apple.dock tilesize 2>/dev/null || echo missing)"
  echo "magnification=$(defaults read com.apple.dock magnification 2>/dev/null || echo missing)"
  echo "largesize=$(defaults read com.apple.dock largesize 2>/dev/null || echo missing)"
} > "$STATE/dock-backup.txt"

if [[ ! -f "$STATE/wallpaper-backup.txt" ]]; then
  osascript -e 'tell application "System Events" to get POSIX path of (picture of every desktop as alias)' > "$STATE/wallpaper-osascript.txt" 2>/dev/null || true
fi

osascript -e 'tell application "System Events" to count desktops' > "$STATE/desktop-count.txt" 2>/dev/null || true

if pgrep -x NeonDesk >/dev/null; then
  killall NeonDesk 2>/dev/null || true
  sleep 0.4
fi

rm -rf "$APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"
rm -rf "$SAVER_DEST"
cp -R "$SAVER_SRC" "$SAVER_DEST"

codesign --force --deep -s - "$APP_DEST"
codesign --force --deep -s - "$SAVER_DEST"

"$APP_DEST/Contents/MacOS/NeonDesk" --write-stills

defaults -currentHost write com.apple.screensaver moduleDict -dict \
  moduleName NeonDesk \
  path "$SAVER_DEST" \
  type 0 2>/dev/null || true

defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 64
killall Dock 2>/dev/null || true

open "$APP_DEST"

echo "NeonDesk installed."
echo "Menu bar: Work / Show Off / Off. Shortcut: Control-Option-N."
echo "Uninstall: $ROOT/scripts/uninstall.sh"
