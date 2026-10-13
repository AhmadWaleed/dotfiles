# CLAUDE.md

Context for Claude Code sessions working in this repo.

## What this repo is

Reproducibility record for a personal Fedora Workstation machine and a Mac:
every package, COPR repo, Homebrew formula/cask, desktop setting, and
dotfile that was deliberately changed since the OS install. Not a
general-purpose config framework - keep it boring and shell-only (no Nix,
no Stow, no chezmoi, no package manager for the dotfiles themselves).

## Layout

- `home/` - shared dotfiles, mirrors `$HOME`, linked on both OSes.
- `os/fedora/`, `os/macos/` - each has a `bootstrap.sh` (OS packages,
  settings, services), its package list(s) (`packages.txt`/`copr.txt`/
  `flatpak.txt` vs `Brewfile`), its settings script (`gnome-settings.sh` vs
  `macos-defaults.sh`), and a `home/` tree linked on that OS only.
- Top-level `bootstrap.sh` detects the OS, links `home/` then
  `os/<os>/home/`, runs `os/<os>/bootstrap.sh`, then the steps shared by
  both. `claude-setup.sh` and `github-ssh.sh` are shared helpers.
  `claude-setup.sh` must stay at the repo root: other projects call it by
  path.

## Cross-OS rule

Every change lands on both OSes whenever the tool exists on both:

- A package goes in `os/fedora/packages.txt` (or `copr.txt`/`flatpak.txt`)
  **and** `os/macos/Brewfile`. Check the Homebrew name (it often differs,
  e.g. GUI apps are casks); if one OS has no equivalent, leave a comment in
  the other's list saying so.
- A config file goes in `home/`. Only the OS-specific part goes in
  `os/<os>/home/`, pulled in by an include from the shared file (`.zshrc`
  sources `~/.config/zsh/os.zsh`; `config.ghostty` has
  `config-file = ?os.ghostty`). Prefer this over `$OSTYPE` branches inside
  shared files. A path must exist in only one tree - shared or one OS.
- A desktop setting goes in `gnome-settings.sh` and, if macOS has a
  counterpart, `macos-defaults.sh`.
- Something truly single-OS (GNOME, Conky, systemd, `defaults`) lives only
  under that `os/<os>/` tree.

## Conventions

- `home/` and `os/<os>/home/` mirror `$HOME`. A file at
  `home/.config/foo/bar` belongs at `~/.config/foo/bar` and gets symlinked
  there by `bootstrap.sh`. Don't add a templating layer - if a file needs to
  differ per OS, use the include pattern above; if it needs to differ per
  machine, it doesn't belong in this repo yet.
- Package lists are plain lists, comments with `#`. Keep them sorted-ish and
  don't add version pins (the Brewfile's `temurin@25` matches Fedora's
  `java-25` package name, not a pin) - this tracks *what's installed*, not
  exact versions.
- `bootstrap.sh` must stay idempotent end to end, on both OSes. Every step
  should be safe to re-run after a `git pull`. When adding a step, check for
  the already-done state first (see the existing steps for the pattern).
- Anything that runs on macOS (top-level `bootstrap.sh`, `claude-setup.sh`,
  `github-ssh.sh`, everything in `os/macos/`, shared `home/.local/bin/`
  scripts) must work on macOS's bash 3.2 and BSD userland: no `mapfile`,
  associative arrays or `${x,,}`; no `grep -P`, `sed -i`, `readlink -f`,
  `sort -V`, `nproc`, `stat -c` or `date -d`. `os/fedora/` scripts may use
  bash 5 and GNU tools.
- No secrets, tokens, or SSH keys in this repo, ever.

## When asked to add something

1. Figure out which category it is: package → `os/fedora/packages.txt`
   (or `copr.txt`/`flatpak.txt`) and `os/macos/Brewfile`; dotfile →
   `home/...` (or `os/<os>/home/...` if single-OS); desktop setting →
   `os/fedora/gnome-settings.sh` / `os/macos/macos-defaults.sh`; anything
   else (curl-installed tool, etc.) → an idempotent step in the top-level
   `bootstrap.sh` if both OSes get it, else in `os/<os>/bootstrap.sh`.
2. Apply the cross-OS rule above.
3. Actually apply the change to the live system too (or confirm it's
   already applied) - this repo should never describe a state the machine
   isn't actually in. Only the current OS can be applied and tested from
   here: test the other OS's side as far as possible (bash 3.2 via the
   `docker.io/library/bash:3.2` image, `brew` names via
   `https://formulae.brew.sh/api/{formula,cask}/<name>.json`), then tell
   the user exactly what to run on the other machine to confirm it.
4. Update `README.md`'s layout diagram if a new top-level file/dir is added.

## App-specific gotchas

- **Conky** (`os/fedora/home/.config/conky/`, Fedora-only): `conky.conf` is
  the source file; the live `~/.config/conky/conky.generated.conf` is a
  derived copy with `__NET_IFACE__` substituted in by
  `scripts/launch-conky.sh` at every start - never edit the generated one,
  and don't add it to this repo (it's gitignored). Its window normally stays
  below other windows by design; Super+Shift+C (`gnome-settings.sh`'s only
  custom keybinding so far, and `scripts/toggle-conky.sh`) pins it above
  them temporarily. See its `README.md` for the user-facing guide.
- **Ghostty**: Fedora binds Ctrl+Alt as a "Cmd" stand-in (GNOME owns
  Super); macOS keeps Ghostty's native Cmd bindings. Keybindings therefore
  go in `os/<os>/home/.config/ghostty/os.ghostty`, not the shared
  `config.ghostty`. Ghostty accepts the other OS's platform keys
  (`macos-*`, `gtk-*`) without error, so `ghostty +validate-config` on
  Fedora also checks the macOS combination.
- **dotfiles-sync-check** skill (`os/fedora/home/.claude/skills/`) scans
  Fedora only (dnf/COPR/Flatpak/gsettings history, `home/` and
  `os/fedora/home/` drift). Its paths are in `scan_history.py`'s
  `HOME_TREES`/`GNOME_SETTINGS`; keep them and the eval fixtures in sync if
  the layout changes.
