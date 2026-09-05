#!/bin/bash
# Resolves the active network interface (the one used for the default
# route) and bakes it into a generated copy of conky.conf, then launches
# conky against that generated file. Re-run (e.g. via `systemctl --user
# restart conky`) to pick up an interface change.
set -euo pipefail

CONF_DIR="$HOME/.config/conky"
TEMPLATE="$CONF_DIR/conky.conf"
GENERATED="$CONF_DIR/conky.generated.conf"

iface=$(ip route show default 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')
if [ -z "${iface:-}" ]; then
    iface=$(ip -brief link show up 2>/dev/null | awk '$1!="lo"{print $1; exit}')
fi
[ -n "${iface:-}" ] || iface="lo"

sed "s/__NET_IFACE__/$iface/g" "$TEMPLATE" > "$GENERATED"

exec conky -c "$GENERATED"
