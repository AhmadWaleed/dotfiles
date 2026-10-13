#!/usr/bin/env bash
# Fedora Workstation half of the setup: dnf/COPR/Flatpak packages, GPU
# drivers, fonts, GNOME extensions and settings, Conky autostart. Run by the
# top-level bootstrap.sh after dotfiles are linked, before the shared tools.
#
# Safe to re-run: every step is idempotent.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

step "Upgrading system packages"
sudo dnf upgrade -y

step "Enabling COPR repos"
while IFS= read -r repo; do
    [[ -z "$repo" || "$repo" == \#* ]] && continue
    sudo dnf copr enable -y "$repo"
done < copr.txt

step "Installing packages"
mapfile -t pkgs < <(grep -vE '^\s*#|^\s*$' packages.txt)
sudo dnf install -y "${pkgs[@]}"

step "Installing GPU drivers"
gpu_info="$(lspci -nnk | grep -Ei 'vga compatible controller|3d controller' || true)"
if grep -qi 'nvidia' <<<"$gpu_info"; then
    echo "NVIDIA GPU detected"
    if rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
        echo "RPM Fusion already enabled"
    else
        fedora_ver="$(rpm -E %fedora)"
        sudo dnf install -y \
            "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
            "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"
    fi
    sudo dnf install -y akmod-nvidia
    echo "akmod-nvidia installed - reboot required for the kernel module to build and load"
elif grep -qi 'amd\|ati' <<<"$gpu_info"; then
    echo "AMD GPU detected - Fedora's default Mesa/amdgpu driver already covers this, nothing to install"
elif grep -qi 'intel' <<<"$gpu_info"; then
    echo "Intel GPU detected - Fedora's default Mesa/i915 driver already covers this, nothing to install"
else
    echo "No recognized GPU vendor detected, skipping"
fi

step "Installing Flatpak apps"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
mapfile -t flatpaks < <(grep -vE '^\s*#|^\s*$' flatpak.txt)
flatpak install -y --system flathub "${flatpaks[@]}"

step "Setting default shell to zsh"
if [[ "$SHELL" != "/usr/bin/zsh" ]]; then
    chsh -s /usr/bin/zsh "$USER"
else
    echo "already zsh"
fi

step "Installing mononoki font"
FONT_DIR="$HOME/.local/share/fonts/mononoki"
if [[ -f "$FONT_DIR/mononoki-Regular.ttf" ]]; then
    echo "already installed"
else
    mkdir -p "$FONT_DIR"
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/mononoki.zip" \
        "https://github.com/madmalik/mononoki/releases/latest/download/mononoki.zip"
    unzip -q "$tmp/mononoki.zip" -d "$tmp"
    find "$tmp" -name '*.ttf' -exec cp {} "$FONT_DIR/" \;
    rm -rf "$tmp"
    fc-cache -f "$FONT_DIR"
fi

# Installs a GNOME extension from extensions.gnome.org and enables it.
# If no build targets this GNOME version, installs the newest build and adds
# this version to its metadata (Shell refuses to load it otherwise).
install_gnome_extension() {
    local uuid="$1"
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
    local shell_ver
    shell_ver="$(gnome-shell --version | grep -oP '\d+' | head -1)"
    if [[ -d "$ext_dir" ]]; then
        echo "already installed"
    else
        local version_pk tmp
        version_pk="$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=${uuid}" | python3 -c '
import json, sys
versions = json.load(sys.stdin)["shell_version_map"]
match = versions.get(sys.argv[1]) or max(versions.values(), key=lambda v: v["version"])
print(match["pk"])' "$shell_ver")"
        tmp="$(mktemp -d)"
        curl -fsSL -o "$tmp/ext.zip" \
            "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=${version_pk}"
        gnome-extensions install --force "$tmp/ext.zip"
        rm -rf "$tmp"
    fi
    python3 - "$ext_dir/metadata.json" "$shell_ver" <<'EOF'
import json, sys
path, ver = sys.argv[1], sys.argv[2]
meta = json.load(open(path))
if ver not in meta["shell-version"]:
    meta["shell-version"].append(ver)
    json.dump(meta, open(path, "w"), indent=2)
    print(f"marked compatible with GNOME {ver}")
EOF
    # A running Wayland session only sees newly installed extensions after
    # re-login, so enable via gsettings; it activates on next login.
    gnome-extensions enable "$uuid" 2>/dev/null || python3 - "$uuid" <<'EOF'
import ast, subprocess, sys
cur = subprocess.run(["gsettings", "get", "org.gnome.shell", "enabled-extensions"],
                     capture_output=True, text=True, check=True).stdout
enabled = ast.literal_eval(cur.removeprefix("@as ").strip())
if sys.argv[1] not in enabled:
    enabled.append(sys.argv[1])
    subprocess.run(["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(enabled)], check=True)
print("enabled; log out/in to load it")
EOF
}

step "Installing Internet Speed Meter GNOME extension"
# https://github.com/foss-desk/internet-speed-meter - not packaged for Fedora.
install_gnome_extension "speed-meter@mojahid.lunecode.com"

step "Installing Claude Code Usage GNOME extension"
# https://github.com/Haletran/claude-usage-extension - panel indicator for
# Claude plan usage, reads the Claude Code OAuth token.
install_gnome_extension "claude-code-usage@haletran.com"

step "Installing Codex Usage Indicator GNOME extension"
# https://github.com/stonega/codex-usage-indicator - panel indicator for
# Codex plan usage, reads the local Codex CLI authentication.
install_gnome_extension "codex-usage-indicator@stone.dev"

step "Applying GNOME settings"
./gnome-settings.sh

step "Enabling Conky autostart"
systemctl --user daemon-reload
systemctl --user enable --now conky.service
