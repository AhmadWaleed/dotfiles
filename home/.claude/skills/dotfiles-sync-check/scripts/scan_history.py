#!/usr/bin/env python3
"""Deterministic half of dotfiles-sync-check: find everything the dotfiles
repo is supposed to track but doesn't yet, in three ways:

  1. history  - shell-history commands (dnf/flatpak/gsettings/...) not yet
                reflected in the repo's tracking files.
  2. file     - tracked files under home/ whose live copy has diverged
                (manual edits that never got copied back).
  3. gsettings - gnome-settings.sh lines whose live value no longer matches.

Each candidate carries a one-line `summary` (for the first, no-diff mention)
and a full `diff` (only shown if the user asks to see it), plus an `apply`
hint describing exactly what applying it would do.

State (state --state) remembers scan progress plus which candidate ids were
resolved (`tracked` = applied, `dismissed` = explicitly declined) so repeat
scans only surface what's new and unresolved. Drift candidate ids include a
hash of the new content, so a genuinely different future drift on the same
file/setting still gets surfaced even if an earlier one was dismissed.

Usage:
  scan_history.py scan --dotfiles-dir DIR [--state PATH] [--history PATH ...]
  scan_history.py resolve --tracked ID [ID ...] --dismissed ID [ID ...] [--state PATH]
"""
import argparse
import difflib
import hashlib
import json
import re
import subprocess
from pathlib import Path

DEFAULT_STATE = Path.home() / ".claude" / "dotfiles-sync-state.json"
HISTORY_FILES = [Path.home() / ".zsh_history", Path.home() / ".bash_history"]

# (category, regex, dotfiles file the category normally lands in)
HISTORY_PATTERNS = [
    ("dnf_install", r"^(sudo\s+)?dnf\s+install\s+", "packages.txt"),
    ("dnf_copr", r"^(sudo\s+)?dnf\s+copr\s+enable\s+", "copr.txt"),
    ("flatpak_install", r"^(sudo\s+)?flatpak\s+install\s+", "flatpak.txt"),
    ("chsh", r"^chsh\s+", "bootstrap.sh"),
    ("curl_install", r"curl\s+.*\|\s*(bash|sh)\b", "bootstrap.sh"),
    ("gsettings", r"^gsettings\s+set\s+", "gnome-settings.sh"),
    ("git_config_global", r"^git\s+config\s+--global\s+", "github-ssh.sh"),
    ("ssh_keygen", r"^ssh-keygen\s+", "github-ssh.sh"),
    ("systemctl_enable", r"^(sudo\s+)?systemctl\s+(--now\s+)?enable\s+", "bootstrap.sh"),
    ("npm_global", r"^(sudo\s+)?npm\s+(i|install)\s+(-g|--global)\s+", "packages.txt"),
    ("pip_user", r"^pip3?\s+install\s+(--user\s+)?", "packages.txt"),
    ("cargo_install", r"^cargo\s+install\s+", "packages.txt"),
]

GSETTINGS_LINE = re.compile(r"^\s*gsettings\s+set\s+(\S+)\s+(\S+)\s+(.+?)\s*$")


def short_hash(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()[:10]


def load_state(path: Path) -> dict:
    if path.exists():
        return json.loads(path.read_text())
    return {"offsets": {}, "dismissed": [], "tracked": []}


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2) + "\n")


def read_new_lines(path: Path, since_line: int) -> tuple[list[str], int]:
    if not path.exists():
        return [], since_line
    lines = path.read_text(errors="replace").splitlines()
    new = lines[since_line:]
    out = []
    for line in new:
        # strip zsh extended-history prefix: ": <epoch>:<elapsed>;"
        m = re.match(r"^:\s*\d+:\d+;(.*)$", line)
        out.append(m.group(1) if m else line)
    return out, len(lines)


def classify_history(cmd: str):
    for name, pattern, target_file in HISTORY_PATTERNS:
        if re.search(pattern, cmd, re.IGNORECASE):
            return name, target_file
    return None, None


def extract_identifiers(category: str, cmd: str) -> list[str]:
    """Pull out the specific thing a command names (package, repo, URL, gsettings
    key, ...) rather than generic verbs like "install" or "sudo", which would
    match almost any prose file and make the tracked-check meaningless."""
    body = re.sub(r"^sudo\s+", "", cmd)
    if category in ("dnf_install", "dnf_copr", "flatpak_install", "npm_global", "cargo_install"):
        m = re.search(r"(?:install|enable)\s+(.*)$", body)
        args = m.group(1) if m else ""
        return [t for t in args.split() if not t.startswith("-")]
    if category == "pip_user":
        m = re.search(r"install\s+(?:--user\s+)?(.*)$", body)
        args = m.group(1) if m else ""
        return [t for t in args.split() if not t.startswith("-")]
    if category == "gsettings":
        m = re.search(r"gsettings\s+set\s+(\S+)\s+(\S+)", body)
        return list(m.groups()) if m else []
    if category == "git_config_global":
        m = re.search(r"--global\s+(\S+)", body)
        return [m.group(1)] if m else []
    if category == "chsh":
        m = re.search(r"-s\s+(\S+)", body)
        return [m.group(1)] if m else []
    if category == "curl_install":
        return re.findall(r"https?://\S+", body)
    if category == "ssh_keygen":
        m = re.search(r"-f\s+(\S+)", body)
        return [Path(m.group(1)).name] if m else []
    if category == "systemctl_enable":
        m = re.search(r"enable\s+(?:--now\s+)?(\S+)", body)
        return [m.group(1)] if m else []
    return []


def tracking_corpus(dotfiles_dir: Path) -> str:
    """Concatenated content of the repo's top-level tracking files (not
    home/ - those are the actual symlinked dotfiles, searching them would
    match unrelated prose)."""
    corpus = ""
    for f in dotfiles_dir.rglob("*"):
        if not f.is_file() or ".git" in f.parts:
            continue
        rel = f.relative_to(dotfiles_dir)
        if rel.parts and rel.parts[0] == "home":
            continue
        try:
            corpus += f.read_text(errors="ignore") + "\n"
        except OSError:
            continue
    return corpus


def already_tracked(corpus: str, category: str, cmd: str) -> bool:
    """A command with no extractable identifier is always treated as
    untracked - showing an extra item to confirm is fine, silently hiding
    one is not."""
    identifiers = extract_identifiers(category, cmd)
    if not identifiers:
        return False
    return any(ident in corpus for ident in identifiers)


def scan_history_candidates(dotfiles_dir: Path, history_files: list[Path], state: dict) -> list[dict]:
    corpus = tracking_corpus(dotfiles_dir)
    candidates = []
    new_offsets = dict(state["offsets"])
    for hist_file in history_files:
        key = str(hist_file)
        since = state["offsets"].get(key, 0)
        new_lines, total = read_new_lines(hist_file, since)
        new_offsets[key] = total
        for cmd in new_lines:
            cmd = cmd.strip()
            if not cmd:
                continue
            category, target_file = classify_history(cmd)
            if not category:
                continue
            cmd_id = f"history:{category}:{cmd}"
            if cmd_id in state["dismissed"] or cmd_id in state["tracked"]:
                continue
            if already_tracked(corpus, category, cmd):
                state["tracked"].append(cmd_id)
                continue
            candidates.append({
                "id": cmd_id,
                "kind": "history",
                "summary": f"ran `{cmd}` but {target_file} doesn't have it",
                "diff": f"--- {target_file}\n+++ {target_file}\n@@\n+{extract_identifiers(category, cmd)[0] if extract_identifiers(category, cmd) else cmd}",
                "apply": {"action": "append_line", "file": target_file,
                          "line": (extract_identifiers(category, cmd) or [cmd])[0]},
            })
    state["offsets"] = new_offsets
    return candidates


def scan_file_drift(dotfiles_dir: Path, state: dict) -> list[dict]:
    home_dir = dotfiles_dir / "home"
    if not home_dir.is_dir():
        return []
    candidates = []
    for repo_file in home_dir.rglob("*"):
        if not repo_file.is_file():
            continue
        rel = repo_file.relative_to(home_dir)
        live_file = Path.home() / rel
        if not live_file.exists() or live_file.is_symlink():
            continue  # nothing to compare, or already bootstrap-linked (can't drift)
        try:
            repo_text = repo_file.read_text(errors="ignore")
            live_text = live_file.read_text(errors="ignore")
        except OSError:
            continue
        if repo_text == live_text:
            continue
        drift_id = f"file:{rel}:{short_hash(live_text)}"
        if drift_id in state["dismissed"] or drift_id in state["tracked"]:
            continue
        diff = "".join(difflib.unified_diff(
            repo_text.splitlines(keepends=True),
            live_text.splitlines(keepends=True),
            fromfile=f"repo: home/{rel}", tofile=f"live: ~/{rel}",
        ))
        candidates.append({
            "id": drift_id,
            "kind": "file",
            "summary": f"~/{rel} has changed since it was last copied into the repo",
            "diff": diff,
            "apply": {"action": "copy_file", "src": str(live_file), "dest": str(repo_file)},
        })
    return candidates


def scan_gsettings_drift(dotfiles_dir: Path, state: dict, gsettings_bin: str = "gsettings") -> list[dict]:
    settings_file = dotfiles_dir / "gnome-settings.sh"
    if not settings_file.is_file():
        return []
    candidates = []
    for line in settings_file.read_text(errors="ignore").splitlines():
        m = GSETTINGS_LINE.match(line)
        if not m:
            continue
        schema, key, script_value = m.groups()
        script_value = script_value.strip("'\"")
        try:
            live_raw = subprocess.run(
                [gsettings_bin, "get", schema, key],
                capture_output=True, text=True, timeout=5,
            ).stdout.strip()
        except (OSError, subprocess.TimeoutExpired):
            continue
        # gsettings get prefixes typed values, e.g. "uint32 250" - strip that
        # the same way the script's own literal ("250") never has it.
        live_value = re.sub(r"^(u?int(32|64)|byte|double|boolean)\s+", "", live_raw).strip("'\"")
        if not live_raw or live_value == script_value:
            continue
        drift_id = f"gsettings:{schema}:{key}:{live_value}"
        if drift_id in state["dismissed"] or drift_id in state["tracked"]:
            continue
        new_line = f"gsettings set {schema} {key} {live_value}"
        candidates.append({
            "id": drift_id,
            "kind": "gsettings",
            "summary": f"{schema} {key} is now {live_value!r} live, gnome-settings.sh still says {script_value!r}",
            "diff": f"--- gnome-settings.sh\n+++ gnome-settings.sh\n-{line.strip()}\n+{new_line}",
            "apply": {"action": "replace_line", "file": "gnome-settings.sh",
                      "old_line": line.strip(), "new_line": new_line},
        })
    return candidates


def cmd_scan(args):
    dotfiles_dir = Path(args.dotfiles_dir).expanduser()
    history_files = [Path(p).expanduser() for p in args.history] if args.history else HISTORY_FILES
    state = load_state(Path(args.state))

    candidates = []
    candidates += scan_history_candidates(dotfiles_dir, history_files, state)
    candidates += scan_file_drift(dotfiles_dir, state)
    candidates += scan_gsettings_drift(dotfiles_dir, state, args.gsettings_bin)

    save_state(Path(args.state), state)
    print(json.dumps({"candidates": candidates, "state_path": str(args.state)}, indent=2))


def cmd_resolve(args):
    path = Path(args.state)
    state = load_state(path)
    for cmd_id in args.tracked or []:
        if cmd_id not in state["tracked"]:
            state["tracked"].append(cmd_id)
    for cmd_id in args.dismissed or []:
        if cmd_id not in state["dismissed"]:
            state["dismissed"].append(cmd_id)
    save_state(path, state)
    print(json.dumps({"ok": True, "tracked_count": len(state["tracked"]),
                       "dismissed_count": len(state["dismissed"])}))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)

    s = sub.add_parser("scan")
    s.add_argument("--dotfiles-dir", required=True)
    s.add_argument("--state", default=str(DEFAULT_STATE))
    s.add_argument("--history", nargs="*", default=[],
                    help="Override history file paths (default: ~/.zsh_history, ~/.bash_history)")
    s.add_argument("--gsettings-bin", default="gsettings",
                    help="Override the gsettings binary (for testing against fake values)")
    s.set_defaults(func=cmd_scan)

    r = sub.add_parser("resolve")
    r.add_argument("--tracked", nargs="*", default=[])
    r.add_argument("--dismissed", nargs="*", default=[])
    r.add_argument("--state", default=str(DEFAULT_STATE))
    r.set_defaults(func=cmd_resolve)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
