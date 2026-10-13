#!/bin/bash
# Shared helper for the AMD (amdgpu) GPU scripts.
# Locates the DRM device directory driven by amdgpu without hardcoding
# a card number, since that can shift across reboots/hardware changes.

find_amdgpu_card() {
    for d in /sys/class/drm/card*/device; do
        [ -L "$d/driver" ] || continue
        if [ "$(basename "$(readlink -f "$d/driver")")" = "amdgpu" ]; then
            echo "$d"
            return 0
        fi
    done
    return 1
}
