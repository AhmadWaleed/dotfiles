# Fedora-only shell setup, sourced first by ~/.zshrc.

source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Mimic Mac caffeinate -dimsu
alias caffeinate='systemd-inhibit --what=idle:sleep --mode=block sleep infinity'
alias open='xdg-open'

# Go SDK, unpacked by hand from the go.dev tarball (macOS uses Homebrew's go).
export PATH="$PATH:$HOME/.local/go-sdk/go/bin"
