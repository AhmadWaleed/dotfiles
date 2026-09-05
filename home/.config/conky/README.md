# Conky config

Minimal transparent system monitor, docked top-right, styled after
[CaffeineOnIce's gist](https://gist.github.com/CaffeineOnIce/4da72d18e20c9869895b31540e46b242)
(IBM Plex Mono, grey/white text, thin pastel graphs). Adapted for this
machine's AMD hardware (`k10temp` CPU temp, `amdgpu` GPU stats) and extended
with live RAM and GPU usage graphs alongside the CPU one.

## What it shows

CPU (%, graph, freq, temp) - RAM (used/total, graph) - GPU (%, graph, temp,
VRAM used/total, VRAM graph) - root/home disk usage bars + disk I/O graph -
network up/down speed + graphs for whichever interface currently holds the
default route - battery % + charge state - top 5 processes.

## Start / stop

Runs as a user systemd service, autostarts on login:

```sh
systemctl --user status  conky
systemctl --user stop    conky
systemctl --user restart conky   # also re-detects the active network interface
systemctl --user disable conky   # turn off autostart
```

## Files

- `conky.conf` - the actual config, edit this. **Not** `conky.generated.conf`
  (gitignored) - that's a copy of `conky.conf` with `__NET_IFACE__` replaced
  by the live default-route interface, rewritten by `scripts/launch-conky.sh`
  on every start. Edits go in `conky.conf`; restart the service to see them.
- `scripts/launch-conky.sh` - resolves the active interface and execs conky.
  This is what the systemd unit actually runs.
- `scripts/gpu-*.sh` - GPU usage/VRAM readouts via `amdgpu`'s sysfs
  (`gpu_busy_percent`, `mem_info_vram_*`); GPU temp itself comes from conky's
  native `${hwmon amdgpu temp 1}`, no script needed for that.

## Known limitations (this hardware)

- No per-core CPU temperatures: this AMD platform's `k10temp` only exposes a
  single package/die temp (`Tctl`), unlike Intel's `coretemp` which the
  original gist's design assumed. The CPU temp line shows the overall value.
- The GPU scripts are AMD/`amdgpu`-specific (this machine's integrated
  Radeon 740M). Porting to NVIDIA/Intel would mean swapping their sysfs
  paths/tools in `scripts/gpu-*.sh`.
