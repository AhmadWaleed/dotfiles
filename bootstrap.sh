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

step "Done"
echo "Restart your terminal (or log out/in) for the shell and GNOME changes to fully apply."
