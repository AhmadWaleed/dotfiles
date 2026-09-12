if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

export EDITOR="hx"
export VISUAL="hx"

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS

setopt AUTO_CD
setopt CORRECT

PROMPT='%F{cyan}%n@%m%f %F{blue}%~%f %# '

source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source "$HOME/.local/share/zsh-z/zsh-z.plugin.zsh"

autoload -Uz compinit && compinit

yolo() {
    claude --dangerously-skip-permissions "$@"
}

# Mimic Mac caffeinate -dimsu
alias caffeinate='systemd-inhibit --what=idle:sleep --mode=block sleep infinity'
alias open='xdg-open'

# opencode
export PATH=/home/aw/.opencode/bin:$PATH

# Flutter (fvm) + Android SDK
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$HOME/fvm/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH

# Show system info on new terminal
fastfetch
export PATH=$PATH:/home/aw/.local/go-sdk/go/bin:/home/aw/go/bin
