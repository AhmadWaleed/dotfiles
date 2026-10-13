# Conky config

Minimal transparent system monitor, docked top-right, styled after
[CaffeineOnIce's gist](https://gist.github.com/CaffeineOnIce/4da72d18e20c9869895b31540e46b242)
(IBM Plex Mono, grey/white text, thin pastel graphs). Adapted for this
machine's AMD hardware (`k10temp` CPU temp, `amdgpu` GPU stats) and extended
with live RAM and GPU usage graphs alongside the CPU one.

## What it shows

Grouped into sections split by thin divider lines, one font size, with the
headline number of each row right-aligned:

- System - Fedora version, uptime, kernel
- Compute - CPU (temp, freq, %, graph), RAM (used/total, %, graph), GPU
  (temp, %, graph), VRAM (used/total, %, bar)
- Storage - root/home usage bars side by side, disk read/write + I/O graph
- Network - interface, IP, up/down speeds and graphs for whichever interface
  currently holds the default route
- Claude - plan, 5-hour session and weekly usage bars side by side, reset times
- Codex - plan, session and weekly usage bars side by side, reset times
- Battery - charge state, %, bar
- Processes - top 5 by CPU with CPU% and MEM% columns

Everything must fit the screen height (the window isn't scrollable), so check
the bottom rows are still visible after adding anything.

## Start / stop

Runs as a user systemd service, autostarts on login:

```sh
systemctl --user status  conky
systemctl --user stop    conky
systemctl --user restart conky   # also re-detects the active network interface
systemctl --user disable conky   # turn off autostart
```

## Showing it over other windows

By design it stays *below* other windows (`own_window_hints = 'below'`), so
once the desktop isn't empty it's hidden behind whatever you're using -
that's the intended default, not a bug.

Press **Super+Shift+C** to pin it on top temporarily; press it again to put
it back below. This runs `scripts/toggle-conky.sh`, which flips the window
between `_NET_WM_STATE_BELOW` and `_NET_WM_STATE_ABOVE` via `wmctrl` - it
doesn't restart conky, so no data/graph history is lost.

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
- `scripts/claude-usage.py` - Claude usage readouts, inspired by
  [claude-usage-conky](https://github.com/remotedots/claude-usage-conky).
  Uses Claude Code's OAuth token (`~/.claude/.credentials.json`) to query
  `api.anthropic.com/api/oauth/usage` (the endpoint behind `/usage`; costs
  no tokens). All calls share a cache in `$XDG_RUNTIME_DIR`, so the API is hit
  at most once every 5 minutes (it's rate-limited). If the fetch fails (for
  example the token expired because Claude Code hasn't run in a while), the
  last good values stay up, and a window whose reset time has passed shows 0%.

- `scripts/codex-usage.py` - Codex usage readouts through the local CLI's
  [account/rateLimits/read](https://developers.openai.com/codex/app-server)
  interface. Requires `codex` signed in with ChatGPT. Refreshes at most once
  every five minutes, sharing a cache in `$XDG_RUNTIME_DIR`. Failed refreshes
  retain the last good values; expired windows show 0%. No model turn runs.

## Known limitations (this hardware)

- No per-core CPU temperatures: this AMD platform's `k10temp` only exposes a
  single package/die temp (`Tctl`), unlike Intel's `coretemp` which the
  original gist's design assumed. The CPU temp line shows the overall value.
- The GPU scripts are AMD/`amdgpu`-specific (this machine's integrated
  Radeon 740M). Porting to NVIDIA/Intel would mean swapping their sysfs
  paths/tools in `scripts/gpu-*.sh`.
