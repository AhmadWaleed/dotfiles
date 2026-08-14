#!/usr/bin/env python3
"""Deterministic half of dotfiles-sync-check: parse shell history, classify
system-changing commands, and cross-check them against a dotfiles repo.
State (what's already been seen/dismissed) lives in --state so repeat scans
only surface genuinely new, unresolved items.

Usage:
  scan_history.py scan --dotfiles-dir DIR [--state PATH]
  scan_history.py resolve --tracked ID [ID ...] --dismissed ID [ID ...] [--state PATH]
"""
import argparse
import json
import re
from pathlib import Path

DEFAULT_STATE = Path.home() / ".claude" / "dotfiles-sync-state.json"
HISTORY_FILES = [Path.home() / ".zsh_history", Path.home() / ".bash_history"]

# (category, regex, dotfiles file the category normally lands in)
PATTERNS = [
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


def classify(cmd: str):
    for name, pattern, target_file in PATTERNS:
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


def already_tracked(dotfiles_dir: Path, category: str, cmd: str) -> bool:
    """Check whether a command's specific identifiers already appear in the
    tracking files (top-level scripts/lists, not home/ - those are the actual
    symlinked dotfiles, searching them would match unrelated prose). A command
    with no extractable identifier is always treated as untracked - showing an
    extra item to confirm is fine, silently hiding one is not."""
    identifiers = extract_identifiers(category, cmd)
    if not identifiers:
        return False
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
    return any(ident in corpus for ident in identifiers)


def cmd_scan(args):
    dotfiles_dir = Path(args.dotfiles_dir).expanduser()
    history_files = [Path(p).expanduser() for p in args.history] if args.history else HISTORY_FILES
    state = load_state(Path(args.state))
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
            category, target_file = classify(cmd)
            if not category:
                continue
            cmd_id = f"{category}:{cmd}"
            if cmd_id in state["dismissed"] or cmd_id in state["tracked"]:
                continue
            if already_tracked(dotfiles_dir, category, cmd):
                state["tracked"].append(cmd_id)
                continue
            candidates.append({
                "id": cmd_id,
                "category": category,
                "command": cmd,
                "target_file": target_file,
                "source": hist_file.name,
            })

    state["offsets"] = new_offsets
    save_state(Path(args.state), state)

    # Anything from a prior scan that's still neither tracked nor dismissed
    # stays pending and is re-surfaced here too (not just brand-new lines).
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
