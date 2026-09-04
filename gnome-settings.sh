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
