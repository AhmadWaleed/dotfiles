#!/bin/bash
# Prints current AMD GPU utilisation as a bare percentage (0-100).
dir="$(dirname "$0")"
. "$dir/gpu-common.sh"

card=$(find_amdgpu_card) || { echo 0; exit 0; }
cat "$card/gpu_busy_percent" 2>/dev/null || echo 0
