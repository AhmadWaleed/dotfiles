#!/bin/bash
# Prints AMD GPU VRAM usage as a bare percentage (0-100), for the graph.
dir="$(dirname "$0")"
. "$dir/gpu-common.sh"

card=$(find_amdgpu_card) || { echo 0; exit 0; }
used=$(cat "$card/mem_info_vram_used" 2>/dev/null || echo 0)
total=$(cat "$card/mem_info_vram_total" 2>/dev/null || echo 1)
awk -v u="$used" -v t="$total" 'BEGIN { if (t > 0) printf "%d", (u / t) * 100; else print 0 }'
