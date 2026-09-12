#!/usr/bin/env bash
# Reproduce this machine's setup on a fresh Fedora Workstation install.
#
# Usage:
#   git clone <repo-url> ~/Code/dotfiles
#   cd ~/Code/dotfiles && ./bootstrap.sh
#
# Safe to re-run: every step is idempotent.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

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

step "Installing Claude Code"
if command -v claude >/dev/null 2>&1; then
    echo "already installed"
else
    curl -fsSL https://claude.ai/install.sh | bash
fi

step "Installing Codex CLI"
if command -v codex >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/codex" ]]; then
    echo "already installed"
else
    npm install -g --prefix "$HOME/.local" @openai/codex
fi

step "Installing opencode"
if [[ -x "$HOME/.opencode/bin/opencode" ]]; then
    echo "already installed"
else
    oc_version="$(curl -sL -o /dev/null -w '%{url_effective}' \
        https://github.com/anomalyco/opencode/releases/latest | sed 's#.*/v##')"
    curl -fsSL https://opencode.ai/install | bash -s -- --version "$oc_version"
fi

step "Installing llama"
if [[ -x "$HOME/.local/bin/llama" ]]; then
    echo "already installed"
else
    curl -LsSf https://llama.app/install.sh | sh
fi

step "Adding Claude Code marketplaces"
mapfile -t marketplaces < <(grep -vE '^\s*#|^\s*$' claude-marketplaces.txt)
for m in "${marketplaces[@]}"; do
    claude plugin marketplace add "$m"
done

step "Installing Claude Code plugins"
mapfile -t plugins < <(grep -vE '^\s*#|^\s*$' claude-plugins.txt)
for p in "${plugins[@]}"; do
    claude plugin install -y "$p"
done

step "Setting up SSH key and GitHub CLI auth"
./github-ssh.sh

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

step "Installing zsh-z"
ZSH_Z_DIR="$HOME/.local/share/zsh-z"
if [[ -d "$ZSH_Z_DIR/.git" ]]; then
    git -C "$ZSH_Z_DIR" pull --ff-only
else
    git clone --depth 1 https://github.com/agkozak/zsh-z.git "$ZSH_Z_DIR"
fi

step "Installing fvm"
# Flutter SDKs are per-project (.fvmrc), fetched on demand by fvm.
if [[ -x "$HOME/fvm/bin/fvm" ]]; then
    echo "already installed"
else
    curl -fsSL https://fvm.app/install.sh | bash
fi

step "Installing Android SDK"
# CLI tools only, no Android Studio. Emulator images/AVDs are per-project.
ANDROID_HOME="$HOME/Android/Sdk"
ANDROID_CLI="$ANDROID_HOME/cmdline-tools/latest/bin/android"
if [[ -x "$ANDROID_CLI" ]]; then
    echo "cmdline-tools already installed"
else
    tools_zip="$(curl -fsSL https://dl.google.com/android/repository/repository2-3.xml \
        | grep -oE 'commandlinetools-linux-[0-9]+_latest\.zip' | sort -V | tail -1)"
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/tools.zip" "https://dl.google.com/android/repository/$tools_zip"
    unzip -q "$tmp/tools.zip" -d "$tmp"
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    mv "$tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
    rm -rf "$tmp"
fi
"$ANDROID_CLI" --no-metrics --sdk="$ANDROID_HOME" sdk install platform-tools emulator

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

step "Applying GNOME settings"
./gnome-settings.sh

step "Linking dotfiles into \$HOME"
while IFS= read -r -d '' src; do
    rel="${src#"$DOTFILES_DIR"/home/}"
    dest="$HOME/$rel"
    mkdir -p "$(dirname "$dest")"
    if [[ -L "$dest" ]]; then
        ln -sf "$src" "$dest"
    elif [[ -e "$dest" ]]; then
        echo "backing up existing $dest -> $dest.bak"
        mv "$dest" "$dest.bak"
        ln -s "$src" "$dest"
    else
        ln -s "$src" "$dest"
    fi
    echo "linked $dest -> $src"
done < <(find "$DOTFILES_DIR/home" -type f -print0)

ln -sf .claude/CLAUDE.md "$HOME/AGENTS.md"

step "Enabling Conky autostart"
systemctl --user daemon-reload
systemctl --user enable --now conky.service

step "Done"
echo "Restart your terminal (or log out/in) for the shell and GNOME changes to fully apply."
