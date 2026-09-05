#!/usr/bin/env bash
# GNOME (dconf/gsettings) tweaks that don't live in any dotfile.
# Idempotent - safe to re-run.
set -euo pipefail

# Faster key repeat than the GNOME default.
gsettings set org.gnome.desktop.peripherals.keyboard delay 250
gsettings set org.gnome.desktop.peripherals.keyboard repeat-interval 25

gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface accent-color slate

xdg-settings set default-web-browser com.google.Chrome.desktop

# Super+Shift+C: temporarily pin Conky above other windows (it normally
# stays below/hidden once the desktop isn't empty), toggled by
# ~/.config/conky/scripts/toggle-conky.sh. Only custom keybinding so far -
# if a second one is ever added, this needs to append to the array instead
# of replacing it.
KEYBIND_SCHEMA=org.gnome.settings-daemon.plugins.media-keys
KEYBIND_PATH=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/
gsettings set $KEYBIND_SCHEMA custom-keybindings "['$KEYBIND_PATH']"
gsettings set $KEYBIND_SCHEMA.custom-keybinding:$KEYBIND_PATH name 'Toggle Conky'
gsettings set $KEYBIND_SCHEMA.custom-keybinding:$KEYBIND_PATH command "$HOME/.config/conky/scripts/toggle-conky.sh"
gsettings set $KEYBIND_SCHEMA.custom-keybinding:$KEYBIND_PATH binding '<Super><Shift>c'
