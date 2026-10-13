#!/usr/bin/env bash
# macOS half of the setup: Xcode Command Line Tools, Homebrew and the
# Brewfile, podman VM, system defaults. Run by the top-level bootstrap.sh
# after dotfiles are linked, before the shared tools.
#
# Safe to re-run: every step is idempotent. Written for bash 3.2, the version
# macOS ships.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

step "Installing Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
    echo "already installed"
else
    xcode-select --install
    echo "Finish the Command Line Tools installer dialog, then re-run ./bootstrap.sh" >&2
    exit 1
fi

step "Installing Homebrew"
# /opt/homebrew on Apple Silicon, /usr/local on Intel.
find_brew() {
    local candidate
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return
        fi
    done
}
if [[ -n "$(find_brew)" ]]; then
    echo "already installed"
else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$("$(find_brew)" shellenv)"

step "Installing Brewfile packages"
brew update
brew bundle --file=Brewfile

step "Setting default shell to zsh"
if [[ "$SHELL" != /bin/zsh ]]; then
    chsh -s /bin/zsh
else
    echo "already zsh"
fi

step "Creating podman VM"
# Containers need a Linux VM on macOS; Fedora runs them natively.
if podman machine inspect >/dev/null 2>&1; then
    echo "already created"
else
    podman machine init
fi

step "Applying macOS defaults"
./macos-defaults.sh
