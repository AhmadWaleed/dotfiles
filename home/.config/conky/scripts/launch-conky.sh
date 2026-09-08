#!/bin/bash
# Resolves the active network interface (the one used for the default
# route) and bakes it into a generated copy of conky.conf, then launches
# conky against that generated file. Re-run (e.g. via `systemctl --user
# restart conky`) to pick up an interface change.
set -euo pipefail

CONF_DIR="$HOME/.config/conky"
TEMPLATE="$CONF_DIR/conky.conf"
GENERATED="$CONF_DIR/conky.generated.conf"

# Wait for the window manager to actually be ready, not just the X socket
# to exist - _NET_SUPPORTING_WM_CHECK is only set once Mutter has finished
# initializing. Launching before this can leave conky's window created but
# never actually shown until manually restarted.
for _ in $(seq 1 60); do
    xprop -root _NET_SUPPORTING_WM_CHECK >/dev/null 2>&1 && break
    sleep 0.5
done

iface=$(ip route show default 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')
if [ -z "${iface:-}" ]; then
    iface=$(ip -brief link show up 2>/dev/null | awk '$1!="lo"{print $1; exit}')
fi
[ -n "${iface:-}" ] || iface="lo"

sed "s/__NET_IFACE__/$iface/g" "$TEMPLATE" > "$GENERATED"

exec conky -c "$GENERATED"
