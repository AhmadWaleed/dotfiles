# CLAUDE.md

Context for Claude Code sessions working in this repo.

## What this repo is

Reproducibility record for a personal Fedora Workstation machine: every
package, COPR repo, GNOME setting, and dotfile that was deliberately changed
since the OS install. Not a general-purpose config framework - keep it
boring and shell-only (no Nix, no Stow, no package manager for the dotfiles
themselves).

## Conventions

- `home/` mirrors `$HOME`. A file at `home/.config/foo/bar` belongs at
  `~/.config/foo/bar` and gets symlinked there by `bootstrap.sh`. Don't add
  a templating layer - if a file needs to differ per-machine, that's a sign
  it doesn't belong in this repo yet.
- `packages.txt` / `copr.txt` are plain newline lists, comments with `#`.
  Keep them sorted-ish and don't add version pins - this tracks *what's
  installed*, not exact versions.
- `bootstrap.sh` must stay idempotent end to end. Every step should be safe
  to re-run after a `git pull`. When adding a step, check for the
  already-done state first (see the existing steps for the pattern).
- No secrets, tokens, or SSH keys in this repo, ever.

## When asked to add something

1. Figure out which category it is: package → `packages.txt`/`copr.txt`,
   dotfile → `home/...`, GNOME/gsettings tweak → `gnome-settings.sh`,
   anything else (font, curl-installed tool, etc.) → a new idempotent step
   appended to `bootstrap.sh`.
2. Actually apply the change to the live system too (or confirm it's
   already applied) - this repo should never describe a state the machine
   isn't actually in.
3. Update `README.md`'s layout diagram if a new top-level file/dir is added.

## App-specific gotchas

- **Conky** (`home/.config/conky/`): `conky.conf` is the source file; the
  live `~/.config/conky/conky.generated.conf` is a derived copy with
  `__NET_IFACE__` substituted in by `scripts/launch-conky.sh` at every
  start - never edit the generated one, and don't add it to this repo (it's
  gitignored). Its window normally stays below other windows by design;
  Super+Shift+C (`gnome-settings.sh`'s only custom keybinding so far, and
  `scripts/toggle-conky.sh`) pins it above them temporarily. See
  `home/.config/conky/README.md` for the user-facing guide.
