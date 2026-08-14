---
name: dotfiles-sync-check
description: Check whether recent shell history contains system changes (package installs, COPR/Flatpak additions, shell/gsettings/git changes, curl-installed tools) that aren't yet reflected in the user's ~/Code/dotfiles repo, then propose adding the missing ones. Use this whenever the user asks to check/sync/update their dotfiles, asks "did we miss anything" or "did we track that" after installing something, or after any session where dnf/flatpak/gsettings/chsh/curl-install commands were run. Also the target of periodic/scheduled dotfiles-sync routines - always run the scan even if it seems like nothing recent happened, since the point is catching things the user forgot to mention.
---

# Dotfiles sync check

Finds shell-history commands that changed the system but were never added to
the dotfiles repo, and gets the user's sign-off before adding them. Built to
run often (interactively or on a schedule) without becoming noise: it only
ever asks about things that are both new and unresolved.

## Why this shape

A naive version of this re-reads all of history every time and asks about
everything again. That's annoying enough that the user stops trusting it and
starts declining without reading. The fix is state: `scripts/scan_history.py`
remembers, per history file, how far it's already scanned, plus which
commands were explicitly added (`tracked`) or explicitly declined
(`dismissed`). A rerun only surfaces commands that are new since the last
scan *and* not already resolved either way. Nothing is ever silently dropped
forever except by the user's own "no."

## Steps

1. **Find the dotfiles repo.** Default to `~/Code/dotfiles`. If it's not
   there, ask the user where it lives (don't guess further).

2. **Run the scanner:**
   ```
   python3 <skill-dir>/scripts/scan_history.py scan --dotfiles-dir ~/Code/dotfiles
   ```
   State defaults to `~/.claude/dotfiles-sync-state.json` (machine-local,
   not part of the dotfiles repo - it's scan progress, not configuration).
   This returns a `candidates` list, each with `id`, `category`, `command`,
   `target_file`, `source`. Everything already matched in the dotfiles repo,
   or previously tracked/dismissed, is filtered out already - don't re-derive
   that yourself.

3. **If `candidates` is empty:** say so briefly and stop. This is the common
   case for a periodic/scheduled run - don't manufacture something to report.

4. **If there are candidates, confirm with the user before touching anything.**
   Group them by `target_file`, show the actual command for each so the user
   can tell what it was, and ask which to add (multi-select is natural here -
   see `AskUserQuestion` if available). Expect false positives: shell-history
   parsing can't tell a successful install from a failed one, or a real
   command from a mistyped fragment - that's exactly why this step exists
   rather than auto-applying.

5. **For confirmed items, edit the real dotfiles file** - append the package
   name to `packages.txt`/`flatpak.txt`/`copr.txt`, or add the equivalent
   line to `gnome-settings.sh`/`github-ssh.sh`/`bootstrap.sh`, matching the
   style already in that file (see the repo's own `CLAUDE.md` for its
   conventions). Then commit and push, same as any other dotfiles change in
   this repo.

6. **Record the outcome** so it doesn't get asked again:
   ```
   python3 <skill-dir>/scripts/scan_history.py resolve \
     --tracked <id> <id> ... \
     --dismissed <id> <id> ...
   ```
   Every candidate the user saw goes into exactly one of these two lists -
   added ones into `--tracked`, declined ones into `--dismissed`. Don't leave
   something the user just answered about as neither; that's what causes the
   nagging this skill exists to avoid.

## Limitations worth knowing

- Detection is regex-based over `dnf install`, `dnf copr enable`,
  `flatpak install`, `chsh`, `curl ... | bash`, `gsettings set`,
  `git config --global`, `ssh-keygen`, `systemctl enable`, and global
  `npm`/`pip`/`cargo` installs. Anything else (manual file edits, GUI
  settings changes) won't be caught by history scanning - that's a
  structurally different problem, not a gap to patch in this script.
- The "already tracked" check is a substring match against the repo's
  top-level files, keyed off identifiers the script extracts per category
  (package name, gsettings key, URL, ...). It errs toward showing an item
  the user already handled rather than hiding one they didn't.
