# macOS-only shell setup, sourced first by ~/.zshrc.

# Homebrew: /opt/homebrew on Apple Silicon, /usr/local on Intel.
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x $brew_bin ]]; then
        eval "$("$brew_bin" shellenv)"
        break
    fi
done
unset brew_bin

FPATH="$HOMEBREW_PREFIX/share/zsh/site-functions:$FPATH"
source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

# Keg-only LLVM (clangd, clang-format, clang-tidy) and LLDB (lldb-dap), after
# Apple's toolchain so Xcode's clang stays the default compiler.
export PATH="$PATH:$HOMEBREW_PREFIX/opt/llvm/bin:$HOMEBREW_PREFIX/opt/lldb/bin"

# Fedora's podman-docker provides a `docker` command; this is the Mac stand-in.
alias docker=podman
