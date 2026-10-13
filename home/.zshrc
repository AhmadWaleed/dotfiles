# Drop duplicate PATH entries, e.g. from nested shells re-running this file.
typeset -U path PATH

# OS-specific setup (Homebrew, plugin paths, aliases), from os/<os>/home/.
[[ -r ~/.config/zsh/os.zsh ]] && source ~/.config/zsh/os.zsh

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

source "$HOME/.local/share/zsh-z/zsh-z.plugin.zsh"

autoload -Uz compinit && compinit

yolo() {
    case "$1" in
        codex)
            shift
            codex --dangerously-bypass-approvals-and-sandbox "$@"
            ;;
        claude)
            shift
            claude --dangerously-skip-permissions "$@"
            ;;
        *)
            claude --dangerously-skip-permissions "$@"
            ;;
    esac
}

# opencode
export PATH=$HOME/.opencode/bin:$PATH

# Flutter (fvm) + Android SDK
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$HOME/fvm/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH

# Go-installed binaries
export PATH=$PATH:$HOME/go/bin

# Show system info on new terminal
fastfetch
