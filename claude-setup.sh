#!/usr/bin/env bash
# Claude Code setup shared by every machine, Fedora or macOS: installs Claude
# Code, links home/.claude/ into ~/.claude, and adds the marketplaces and
# plugins from claude-marketplaces.txt and claude-plugins.txt. bootstrap.sh
# runs it on Fedora; on macOS it is the only part of this repo to run.
#
# Idempotent - safe to re-run. Written for bash 3.2, the version macOS ships.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_DIR"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
entries() { grep -vE '^[[:space:]]*(#|$)' "$1"; }

step "Installing Claude Code"
if command -v claude >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/claude" ]]; then
    echo "already installed"
else
    curl -fsSL https://claude.ai/install.sh | bash
fi
export PATH="$PATH:$HOME/.local/bin"

step "Linking Claude Code config into ~/.claude"
find "$DOTFILES_DIR/home/.claude" -type f | while IFS= read -r src; do
    rel="${src#"$DOTFILES_DIR"/home/}"
    # dotfiles-sync-check scans dnf, COPR and gsettings: Fedora only.
    if [[ "$(uname -s)" != Linux && "$rel" == .claude/skills/dotfiles-sync-check/* ]]; then
        continue
    fi
    dest="$HOME/$rel"
    mkdir -p "$(dirname "$dest")"
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        echo "backing up existing $dest -> $dest.bak"
        mv "$dest" "$dest.bak"
    fi
    ln -sfn "$src" "$dest"
    echo "linked $dest"
done
ln -sfn .claude/CLAUDE.md "$HOME/AGENTS.md"

step "Adding Claude Code marketplaces"
# </dev/null keeps claude from reading the rest of the list off stdin.
entries claude-marketplaces.txt | while IFS= read -r m; do
    claude plugin marketplace add "$m" </dev/null
done

step "Installing Claude Code plugins"
entries claude-plugins.txt | while IFS= read -r p; do
    claude plugin install -y "$p" </dev/null
done
