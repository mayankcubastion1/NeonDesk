#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE="$ROOT/state"
APP_DEST="$HOME/Applications/NeonDesk.app"
SAVER_DEST="$HOME/Library/Screen Savers/NeonDesk.saver"

if pgrep -x NeonDesk >/dev/null; then
  killall NeonDesk 2>/dev/null || true
  sleep 0.4
fi

if [[ -x "$APP_DEST/Contents/MacOS/NeonDesk" ]]; then
  "$APP_DEST/Contents/MacOS/NeonDesk" --uninstall-login-item 2>/dev/null || true
fi

rm -rf "$APP_DEST" "$SAVER_DEST"

if [[ -f "$STATE/wallpaper-backup.txt" ]]; then
  while IFS=$'\t' read -r index path; do
    if [[ -n "${path:-}" && -f "$path" ]]; then
      osascript -e "tell application \"System Events\" to set picture of desktop $((index + 1)) to POSIX file \"$path\"" 2>/dev/null || true
    fi
  done < "$STATE/wallpaper-backup.txt"
fi

if [[ ! -s "$STATE/wallpaper-backup.txt" ]]; then
  DEFAULT_WALL="/System/Library/Desktop Pictures/Solid Colors/Black.png"
  if [[ ! -f "$DEFAULT_WALL" ]]; then
    DEFAULT_WALL="$(ls /System/Library/Desktop\ Pictures/*.* 2>/dev/null | head -n 1 || true)"
  fi
  if [[ -n "${DEFAULT_WALL:-}" && -f "$DEFAULT_WALL" ]]; then
    osascript -e "tell application \"System Events\" to set picture of every desktop to POSIX file \"$DEFAULT_WALL\"" 2>/dev/null || true
  fi
fi

if [[ -f "$STATE/dock-backup.txt" ]]; then
  tilesize="$(awk -F= '/tilesize/{print $2}' "$STATE/dock-backup.txt")"
  magnification="$(awk -F= '/magnification/{print $2}' "$STATE/dock-backup.txt")"
  largesize="$(awk -F= '/largesize/{print $2}' "$STATE/dock-backup.txt")"
  if [[ "$tilesize" != "missing" && -n "$tilesize" ]]; then
    defaults write com.apple.dock tilesize -int "$tilesize"
  fi
  if [[ "$magnification" == "missing" ]]; then
    defaults delete com.apple.dock magnification 2>/dev/null || true
  else
    defaults write com.apple.dock magnification -bool "$magnification"
  fi
  if [[ "$largesize" == "missing" ]]; then
    defaults delete com.apple.dock largesize 2>/dev/null || true
  else
    defaults write com.apple.dock largesize -int "$largesize"
  fi
  killall Dock 2>/dev/null || true
fi

echo "NeonDesk removed. Source is still in $ROOT."
