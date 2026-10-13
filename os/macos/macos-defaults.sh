#!/usr/bin/env bash
# macOS `defaults` tweaks, the counterpart of os/fedora/gnome-settings.sh.
# Idempotent - safe to re-run. Key repeat, appearance and accent apply after
# the next log out/in.
set -euo pipefail

# Faster key repeat, matching GNOME's 250ms delay / 25ms interval as closely
# as macOS's 15ms units allow (255ms / 30ms).
defaults write -g InitialKeyRepeat -int 17
defaults write -g KeyRepeat -int 2

defaults write -g AppleInterfaceStyle -string Dark
# Graphite, the closest match to GNOME's slate accent.
defaults write -g AppleAccentColor -int -1

# Asks for confirmation in a system dialog the first time only.
current_browsers="$(defaultbrowser)"
if grep -q '^\* chrome$' <<<"$current_browsers"; then
    echo "Chrome is already the default browser"
else
    defaultbrowser chrome
fi

# Desktop background, from home/Pictures/Wallpapers/. First run asks to let
# the terminal control System Events.
WALLPAPER="$HOME/Pictures/Wallpapers/blackhole-3059x1721.png"
osascript -e "tell application \"System Events\" to tell every desktop to set picture to POSIX file \"$WALLPAPER\""
