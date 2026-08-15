---
name: dotfiles-sync-check
description: Check whether the user's ~/Code/dotfiles repo is missing anything it's supposed to track - new packages/COPR/Flatpak/shell/gsettings/git changes found in shell history, tracked config files (under home/) that were edited live but never copied back, brand-new files sitting next to files that are already tracked (e.g. a new config file added to an app whose directory is already partly tracked), and gnome-settings.sh values that no longer match the live system. Shows a diff of exactly what would be added/removed before touching anything. Use this whenever the user asks to check/sync/update their dotfiles, asks "did we miss anything" or "is this in my dotfiles yet", or after any session where they installed something, edited a tracked config file, added a new config file, or changed a GNOME setting. Also the target of periodic/scheduled dotfiles-sync routines - always run the scan even if nothing seems to have happened, since the point is catching things the user forgot to mention.
---

# Dotfiles sync check

Finds everything the dotfiles repo is supposed to track but doesn't yet, and
gets the user's sign-off - with a real diff, not just a description - before
changing anything. Built to run often (interactively or on a schedule)
without becoming noise: it only ever asks about things that are both new and
unresolved.

## What it looks for

`scripts/scan_history.py scan` covers four sources, each producing
candidates with the same shape (`id`, `kind`, `summary`, `diff`, `apply`):

1. **history** - shell-history commands (`dnf install`, `flatpak install`,
   `chsh`, `gsettings set`, `git config --global`, `ssh-keygen`,
   `systemctl enable`, curl-installers, global npm/pip/cargo installs) not
   yet reflected in the matching tracking file.
2. **file** - a file under the repo's `home/` has a live counterpart
   (`~/<same relative path>`) whose content has diverged - i.e. someone
   edited the live file directly and never copied it back.
3. **newfile** - a brand-new file sitting live next to files that are
   already tracked (e.g. `~/.config/helix/languages.toml` appearing next to
   an already-tracked `~/.config/helix/config.toml`). Only checks
   directories that already have at least one tracked file in them, not the
   whole home directory - see the limitation below.
4. **gsettings** - a `gsettings set` line in `gnome-settings.sh` whose live
   value (via `gsettings get`) no longer matches what the script says.

## Why this shape

A naive version re-checks everything every time and asks about it again.
That's annoying enough that the user stops trusting it and starts declining
without reading. The fix is state: the script remembers, per history file,
how far it's scanned, plus which candidate ids were explicitly applied
(`tracked`) or explicitly declined (`dismissed`). Drift ids include a hash of
the new content, so if something drifts again with genuinely different
content after being dismissed once, it still gets surfaced - dismissing
isn't a permanent mute on the file or setting, just on that specific past
diff. Nothing is ever silently dropped forever except by the user's own
explicit decline.

## Steps

1. **Find the dotfiles repo.** Default to `~/Code/dotfiles`. If it's not
   there, ask the user where it lives (don't guess further).

2. **Run the scanner:**
   ```
   python3 <skill-dir>/scripts/scan_history.py scan --dotfiles-dir ~/Code/dotfiles
   ```
   State defaults to `~/.claude/dotfiles-sync-state.json` (machine-local,
   not part of the dotfiles repo - it's scan progress, not configuration).
   Everything already matched, or previously tracked/dismissed, is filtered
   out already - don't re-derive that yourself.

3. **If `candidates` is empty:** say so briefly and stop. This is the common
   case for a periodic/scheduled run - don't manufacture something to report.

4. **If there are candidates, reveal them in two stages - never dump the
   diff before the user has asked to see it:**

   **Stage 1 - just the headline.** Tell the user how many pending changes
   there are and list each one's `summary` (one line each, no diff yet).
   Then ask:
   > N dotfiles updates found. What would you like to do?
   - **Show diff** - reveal stage 2 below.
   - **Ignore** - decline these permanently (until they drift again with
     different content). Goes straight to step 6 with `--dismissed`.
   - **Not now** - defer without deciding. Nothing recorded either way; the
     same candidates come back next scan.

   **Stage 2 - only after "Show diff".** Print each candidate's `diff`
   verbatim (it's already a real unified/line diff - added lines prefixed
   `+`, removed `-`, don't reformat it) grouped under its `summary`. Then
   ask:
   > Apply these changes to the dotfiles repo?
   - **Apply** - proceed to step 5.
   - **Ignore** - decline permanently, same as above.
   - **Not now** - defer, same as above.

   If the user asks for something in between (e.g. "apply the first one,
   skip the rest"), honor that directly - the two-stage flow above is the
   default shape for the common case, not a rigid form to fight the user's
   actual request.

5. **For everything the user chose to apply, use the candidate's `apply`
   hint** - it already says exactly what to do:
   - `append_line`: append `line` to `file`.
   - `copy_file`: copy `src` (the live file) over `dest` (the repo file).
   - `replace_line`: replace `old_line` with `new_line` in `file`.

   Then commit and push, same as any other dotfiles change in this repo -
   see the repo's own `CLAUDE.md` for its conventions.

6. **Record the outcome** so nothing gets asked about twice:
   ```
   python3 <skill-dir>/scripts/scan_history.py resolve \
     --tracked <id> <id> ... \
     --dismissed <id> <id> ...
   ```
   Every candidate the user made a real decision about (Apply or Ignore)
   goes into exactly one list. Candidates left at "Not now" go into neither -
   that's what makes them come back.

## Limitations worth knowing

- History detection is regex-based over a fixed command list (see
  `scripts/scan_history.py`'s `HISTORY_PATTERNS`). It can't tell a
  successful install from a failed one, or a real command from a mistyped
  fragment - that's exactly why confirmation exists rather than
  auto-applying.
- File-drift detection only compares files already present under `home/` in
  the repo - it won't notice a config file that should be tracked but never
  has been. That's what newfile detection covers *if* a sibling in the same
  directory is already tracked (e.g. a second file appearing in an
  already-tracked app's config dir). A tool with *zero* files tracked
  anywhere yet - a brand new app with no existing anchor point at all, e.g.
  a first-time install with its own fresh `~/.config/<app>/` - still isn't
  caught by anything here. That remains a "decide this is worth tracking"
  judgment call for a human, not something scanning can answer.
- newfile detection deliberately never touches the bare home directory
  itself (only subdirectories that already contain a tracked file) - home
  directories have far too much unrelated stuff (Downloads, caches, app
  state) directly in them to make top-level scanning useful signal instead
  of noise. It also skips anything over 1MB (config files worth tracking
  are small text; anything bigger is almost certainly a binary, and
  suggesting to commit a downloaded binary into the repo is actively wrong).
- gsettings-drift only covers keys already present in `gnome-settings.sh` -
  same reasoning as file-drift.
- "Already tracked" (for history candidates) is a substring match against
  the repo's top-level files. It errs toward showing an item the user
  already handled rather than hiding one they didn't.
