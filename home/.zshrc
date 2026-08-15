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
autoload -Uz compinit && compinit

PROMPT='%F{cyan}%n@%m%f %F{blue}%~%f %# '

source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source "$HOME/.local/share/zsh-z/zsh-z.plugin.zsh"

yolo() {
    claude --dangerously-skip-permissions "$@"
}

# opencode
export PATH=/home/aw/.opencode/bin:$PATH
