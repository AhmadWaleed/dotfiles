#!/usr/bin/env python3
# Prints one Claude plan usage value for conky:
#   plan | session_pct | session_reset | week_pct | week_reset
# Reads the Claude Code OAuth token and queries the endpoint behind /usage.
# Responses are cached so the API is hit at most once per TTL across all calls.
import fcntl
import json
import os
import sys
import time
import urllib.request
from datetime import datetime
from pathlib import Path

CREDS = Path.home() / ".claude" / ".credentials.json"
API = "https://api.anthropic.com/api/oauth/usage"
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/{os.getuid()}")
CACHE = RUNTIME / "conky-claude-usage.json"
LOCK = RUNTIME / "conky-claude-usage.lock"
# Anthropic rate-limits this endpoint; don't poll more often than 5 min.
TTL = 300


def read_cache():
    try:
        return json.loads(CACHE.read_text())
    except (OSError, ValueError):
        return {}


def fetch():
    creds = json.loads(CREDS.read_text())["claudeAiOauth"]
    req = urllib.request.Request(API, headers={
        "Authorization": f"Bearer {creds['accessToken']}",
        "anthropic-beta": "oauth-2025-04-20",
    })
    with urllib.request.urlopen(req, timeout=8) as r:
        return json.loads(r.read()), creds.get("subscriptionType")


def load():
    cache = read_cache()
    if time.time() - cache.get("attempt_ts", 0) < TTL:
        return cache
    with open(LOCK, "w") as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        cache = read_cache()
        if time.time() - cache.get("attempt_ts", 0) < TTL:
            return cache
        # Record every attempt so failures (expired token, 429) back off too.
        cache["attempt_ts"] = time.time()
        try:
            cache["data"], cache["plan"] = fetch()
        except Exception:
            pass
        tmp = CACHE.with_suffix(".tmp")
        tmp.write_text(json.dumps(cache))
        tmp.replace(CACHE)
        return cache


def window(data, name):
    w = (data or {}).get(name) or {}
    resets = w.get("resets_at")
    resets = datetime.fromisoformat(resets).astimezone() if resets else None
    # Cached data outlives the window it describes; a past reset means 0 used.
    if resets and resets <= datetime.now().astimezone():
        return 0, None
    return round(w.get("utilization") or 0), resets


def fmt_reset(dt):
    if not dt:
        return "-"
    now = datetime.now().astimezone()
    return dt.strftime("%H:%M" if dt.date() == now.date() else "%a %H:%M")


key = sys.argv[1] if len(sys.argv) > 1 else "session_pct"
cache = load()
data = cache.get("data")

if key == "plan":
    print(cache.get("plan") or "offline")
elif key in ("session_pct", "week_pct"):
    print(window(data, "five_hour" if key == "session_pct" else "seven_day")[0])
elif key in ("session_reset", "week_reset"):
    print(fmt_reset(window(data, "five_hour" if key == "session_reset" else "seven_day")[1]))
else:
    print("?")
