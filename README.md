# dotfiles

Personal setup for a Fedora Workstation machine and a Mac. Goal: if a
machine dies or I want to start fresh, `git clone` + `./bootstrap.sh` gets
me back to where I am today, with the same tools and config on both OSes
wherever the tool exists on both.

## Layout

```
.
├── bootstrap.sh            # single entrypoint on both OSes, idempotent, run this
├── claude-setup.sh         # Claude Code + its config + plugins; also runs standalone
├── claude-marketplaces.txt # Claude Code plugin marketplaces to add
├── claude-plugins.txt      # Claude Code marketplace plugins to install
├── github-ssh.sh           # git identity + SSH key + gh auth
├── home/                   # SHARED dotfiles, mirrors $HOME, linked on both OSes
│   ├── .zshrc              # sources ~/.config/zsh/os.zsh first
│   ├── .claude/
│   │   ├── CLAUDE.md       # global Claude Code instructions; ~/AGENTS.md links here
│   │   └── settings.json   # global Claude Code settings (theme, TUI mode, ...)
│   ├── .config/
│   │   ├── helix/          # config.toml, languages.toml
│   │   ├── ghostty/        # config.ghostty includes os.ghostty, see its README
│   │   ├── fastfetch/      # config + custom rocket logo
│   │   └── opencode/       # points opencode at the local llama.cpp server
│   ├── Pictures/Wallpapers/ # desktop wallpaper, set by each OS's settings script
│   ├── .local/bin/
│   │   └── llama-router    # launch the local llama.cpp router server (see models/README.md)
│   └── models/             # local GGUF models dir; contents gitignored, see its README
└── os/
    ├── fedora/
    │   ├── bootstrap.sh    # dnf/COPR/Flatpak, GPU drivers, fonts, GNOME, Conky
    │   ├── packages.txt    # dnf package names, one per line
    │   ├── copr.txt        # COPR repos to enable before installing packages
    │   ├── flatpak.txt     # Flatpak app IDs, installed from Flathub
    │   ├── gnome-settings.sh # gsettings tweaks that don't live in a dotfile
    │   └── home/           # Fedora-only dotfiles, linked on Fedora only
    │       ├── .config/zsh/os.zsh         # plugin path, xdg-open/caffeinate aliases, Go SDK
    │       ├── .config/ghostty/os.ghostty # Ctrl+Alt "Cmd" keybindings
    │       ├── .config/conky/             # desktop system monitor widget, see its README
    │       ├── .config/systemd/user/conky.service # autostarts conky on login
    │       └── .claude/skills/dotfiles-sync-check/ # scans shell history for untracked changes
    └── macos/
        ├── bootstrap.sh    # Xcode CLT, Homebrew + Brewfile, podman VM, defaults
        ├── Brewfile        # Homebrew formulae and casks
        ├── macos-defaults.sh # `defaults write` tweaks, the gnome-settings.sh counterpart
        └── home/           # macOS-only dotfiles, linked on macOS only
            ├── .config/zsh/os.zsh         # Homebrew env, plugin path, keg-only LLVM, docker alias
            └── .config/ghostty/os.ghostty # native Cmd keys + Option as Alt
```

`bootstrap.sh` detects the OS, symlinks every file under `home/` and then
`os/<os>/home/` to the same relative path under `$HOME`, runs
`os/<os>/bootstrap.sh` for OS packages and settings, then installs the tools
shared by both (Codex, opencode, llama, Claude Code, GitHub SSH/auth, zsh-z,
fvm, Android SDK). Editing a file here edits your live config too - no
separate "apply" step for dotfile changes, only `bootstrap.sh` needs
re-running when packages or system settings change.

## Fresh machine

Fedora:

```sh
sudo dnf install -y git
git clone <this-repo-url> ~/Code/dotfiles
cd ~/Code/dotfiles
./bootstrap.sh
```

macOS (`git` triggers the Xcode Command Line Tools install on first use):

```sh
git clone <this-repo-url> ~/Code/dotfiles
cd ~/Code/dotfiles
./bootstrap.sh
```

On macOS, log out and back in afterwards for key repeat and appearance to
apply. Allow Ghostty under System Settings > Privacy & Security >
Accessibility for its global quick-terminal key.

`claude-setup.sh` also runs on its own on either OS when only Claude Code is
needed. Project repos that call it (trainmuscle.com's `make dev-setup`)
expect it at `~/Code/dotfiles/claude-setup.sh`, or at `$DOTFILES_DIR`.

## Adding something new

Every change goes to both OSes when the tool exists on both. Only something
that genuinely can't work on one OS (GNOME, Conky, systemd, `defaults`) goes
into a single `os/<os>/` tree.

- New CLI tool or app: add it to `os/fedora/packages.txt` (plus `copr.txt`
  if it needs a COPR repo, or `flatpak.txt` for a GUI app) **and** to
  `os/macos/Brewfile` (`brew` or `cask`). Names often differ between dnf
  and Homebrew. If one OS has no equivalent, say so in a comment in the
  other OS's list.
- Tool installed by a curl installer or npm on both: a step in the
  top-level `bootstrap.sh`. Codex, for example, is installed with
  `npm install -g --prefix "$HOME/.local" @openai/codex`, which puts it in
  `~/.local/bin` on both OSes.
- New dotfile: put it under `home/` at the path it should occupy relative to
  `$HOME`. If part of it differs per OS, keep the shared part in `home/`
  and have it include a per-OS file from `os/<os>/home/`, the way `.zshrc`
  sources `~/.config/zsh/os.zsh` and `config.ghostty` includes
  `os.ghostty`. Each OS must then provide that file, or the include must
  be optional.
- New desktop/system setting: `os/fedora/gnome-settings.sh` and its
  counterpart in `os/macos/macos-defaults.sh`.
- New global Claude Code skill: put it under `home/.claude/skills/`, or
  `os/<os>/home/.claude/skills/` if it only works on one OS.
- New Claude Code plugin: add it to `claude-plugins.txt` (and
  `claude-marketplaces.txt` if it needs a new marketplace first).

Re-run `./bootstrap.sh` after any of these.

## Not tracked here (on purpose)

- `mimeapps.list` / `xdg-terminals.list` - regenerated by the desktop as apps
  get installed, not meaningful to hand-manage.
- `.claude/settings.local.json` - Claude Code's own machine-local settings
  (auto-accumulated permission allowlist), not meant to be shared.
- `~/.gitconfig`'s `[credential]` and `[filter "lfs"]` blocks - written by
  `gh auth setup-git` and GitHub Desktop respectively, both already
  reproduced as a side effect of `github-ssh.sh` and the app lists. Only the
  `user.name`/`user.email`/`core.editor` lines are hand-set (in
  `github-ssh.sh`), so the file itself isn't symlinked from `home/`.
- `~/.claude.json`, `~/.config/gh/*`, `~/.zcompdump`, `~/.var` - session/app
  state, not configuration choices.
- `~/.claude/dotfiles-sync-state.json` - `dotfiles-sync-check`'s own scan
  progress, machine-local by design.
- `~/.config/llama-router/env` - GPU device, MoE CPU-offload split, thread
  count for `llama-router`. Genuinely hardware-specific (varies by GPU
  model/VRAM and which local LLM you're running), so the script reads it if
  present and falls back to generic defaults otherwise - see
  `home/.local/bin/llama-router`'s header comment.
- Anything containing secrets (SSH keys, API tokens, etc.) - never goes in
  this repo.
