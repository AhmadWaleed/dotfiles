#!/bin/bash
# Toggles Conky between its default state (stays below other windows,
# so it's invisible once the desktop isn't empty) and a temporary
# "always on top" state, for glancing at it on demand. Bound to a GNOME
# custom keyboard shortcut. Run again to put it back below.
set -euo pipefail

win_id=$(wmctrl -l -x | awk '$3 == "Conky.Conky" {print $1; exit}')
if [ -z "$win_id" ]; then
    notify-send "Conky" "Window not found - is the service running?" 2>/dev/null || true
    exit 1
fi

if xprop -id "$win_id" _NET_WM_STATE | grep -q ABOVE; then
    wmctrl -i -r "$win_id" -b remove,above
    wmctrl -i -r "$win_id" -b add,below
else
    wmctrl -i -r "$win_id" -b remove,below
    wmctrl -i -r "$win_id" -b add,above
fi
