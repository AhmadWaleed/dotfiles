#!/usr/bin/env bash
# Reproduce this machine's setup on a fresh Fedora Workstation or macOS
# install: links dotfiles, runs os/<os>/bootstrap.sh for OS packages and
# settings, then installs the tools shared by both.
#
# Usage:
#   git clone <repo-url> ~/Code/dotfiles
#   cd ~/Code/dotfiles && ./bootstrap.sh
#
# Safe to re-run: every step is idempotent. Runs on macOS's bash 3.2, so no
# bash 4+ features or GNU-only flags here.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"
export DOTFILES_DIR

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

case "$(uname -s)" in
    Darwin) OS=macos ;;
    Linux)
        if [[ -f /etc/fedora-release ]]; then
            OS=fedora
        else
            echo "Unsupported Linux distro: only Fedora has an os/ setup" >&2
            exit 1
        fi
        ;;
    *)
        echo "Unsupported OS: $(uname -s)" >&2
        exit 1
        ;;
esac
OS_DIR="$DOTFILES_DIR/os/$OS"

# Symlinks every file under $1 to the same relative path under $HOME,
# backing up any real file already there.
link_tree() {
    local root="$1" src rel dest
    while IFS= read -r -d '' src; do
        rel="${src#"$root"/}"
        dest="$HOME/$rel"
        mkdir -p "$(dirname "$dest")"
        if [[ -e "$dest" && ! -L "$dest" ]]; then
            echo "backing up existing $dest -> $dest.bak"
            mv "$dest" "$dest.bak"
        fi
        ln -sfn "$src" "$dest"
        echo "linked $dest"
    done < <(find "$root" -type f -print0)
}

step "Linking shared dotfiles into \$HOME"
link_tree "$DOTFILES_DIR/home"
ln -sfn .claude/CLAUDE.md "$HOME/AGENTS.md"

step "Linking $OS dotfiles into \$HOME"
link_tree "$OS_DIR/home"

"$OS_DIR/bootstrap.sh"

if [[ "$OS" == macos ]]; then
    # Homebrew isn't on a fresh Mac's PATH; the steps below need its node and gh.
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$brew_bin" ]]; then
            eval "$("$brew_bin" shellenv)"
            break
        fi
    done
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

# Claude Code, its config links and plugins.
./claude-setup.sh

step "Setting up SSH key and GitHub CLI auth"
./github-ssh.sh

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
# Same path on both OSes so .zshrc can share ANDROID_HOME.
ANDROID_HOME="$HOME/Android/Sdk"
ANDROID_CLI="$ANDROID_HOME/cmdline-tools/latest/bin/android"
if [[ -x "$ANDROID_CLI" ]]; then
    echo "cmdline-tools already installed"
else
    if [[ "$OS" == macos ]]; then tools_os=mac; else tools_os=linux; fi
    tools_zip="$(curl -fsSL https://dl.google.com/android/repository/repository2-3.xml \
        | grep -oE "commandlinetools-${tools_os}-[0-9]+_latest\.zip" | sort -t- -k3 -n | tail -1)"
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/tools.zip" "https://dl.google.com/android/repository/$tools_zip"
    unzip -q "$tmp/tools.zip" -d "$tmp"
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    mv "$tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
    rm -rf "$tmp"
fi
"$ANDROID_CLI" --no-metrics --sdk="$ANDROID_HOME" sdk install platform-tools emulator

step "Done"
echo "Restart your terminal (or log out/in) for the shell and desktop changes to fully apply."
