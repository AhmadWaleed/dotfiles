#!/bin/bash
# Prints current AMD GPU VRAM usage in GiB (one decimal place).
dir="$(dirname "$0")"
. "$dir/gpu-common.sh"

card=$(find_amdgpu_card) || { echo "0.0"; exit 0; }
awk '{printf "%.1f", $1/1073741824}' "$card/mem_info_vram_used" 2>/dev/null || echo "0.0"
