#!/usr/bin/env bash
# Git identity + SSH key + GitHub CLI auth, so `git push`/`gh` work right
# after bootstrap. Idempotent - safe to re-run. Only prompts (passphrase,
# browser login) when something is actually missing; requires `gh` (see
# packages.txt) to already be installed.
set -euo pipefail

NAME="Ahmed waleed"
EMAIL="ahmed_waleed1@hotmail.com"
KEY="$HOME/.ssh/id_ed25519"

git config --global user.name "$NAME"
git config --global user.email "$EMAIL"
git config --global core.editor hx

# --- SSH key -----------------------------------------------------------------
if [[ -f "$KEY" ]]; then
    echo "ssh key already exists: $KEY"
else
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY"
fi

# Load into the running agent (GNOME keyring provides one at $SSH_AUTH_SOCK).
FPR="$(ssh-keygen -lf "$KEY.pub" | awk '{print $2}')"
if ssh-add -l 2>/dev/null | grep -q "$FPR"; then
    echo "key already loaded in agent"
else
    ssh-add "$KEY"
fi

# --- known_hosts ---------------------------------------------------------
mkdir -p "$HOME/.ssh" && touch "$HOME/.ssh/known_hosts"
if ssh-keygen -F github.com -f "$HOME/.ssh/known_hosts" >/dev/null; then
    echo "github.com already in known_hosts"
else
    ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
fi
chmod 600 "$HOME/.ssh/known_hosts"

# --- gh auth -----------------------------------------------------------------
if gh auth status -h github.com >/dev/null 2>&1; then
    echo "gh already logged in"
else
    gh auth login -h github.com -p ssh -w
fi
gh auth setup-git -h github.com

# admin:public_key scope is needed once, to let `gh ssh-key add` manage keys.
if gh auth status -h github.com 2>&1 | grep -q admin:public_key; then
    echo "gh token already has admin:public_key"
else
    gh auth refresh -h github.com -s admin:public_key
fi

# --- upload public key to GitHub, if not already there ---------------------
PUBKEY_CONTENT="$(awk '{print $1, $2}' "$KEY.pub")"
if gh api user/keys --jq '.[].key' 2>/dev/null | grep -qF "$PUBKEY_CONTENT"; then
    echo "key already on GitHub account"
else
    gh ssh-key add "$KEY.pub" --title "$(hostname)-$(date +%Y%m%d)"
fi
