#!/usr/bin/env python3
# Prints one Codex plan usage value for conky:
#   plan | session_pct | session_reset | week_pct | week_reset
# Reads account limits through the authenticated Codex app server.
# Responses are cached so the API is hit at most once per TTL across all calls.
import fcntl
import json
import os
import sys
import time
import select
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/{os.getuid()}")
CACHE = RUNTIME / "conky-codex-usage.json"
LOCK = RUNTIME / "conky-codex-usage.lock"
# Share one refresh every five minutes across all readouts.
TTL = 300


def read_cache():
    try:
        return json.loads(CACHE.read_text())
    except (OSError, ValueError):
        return {}


def fetch():
    codex = shutil.which("codex") or str(Path.home() / ".local/bin/codex")
    with subprocess.Popen(
        [codex, "app-server"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL, bufsize=0,
    ) as proc:
        pending = b""
        deadline = time.monotonic() + 20

        def send(message):
            proc.stdin.write((json.dumps(message) + "\n").encode())

        def receive(request_id):
            nonlocal pending
            while True:
                while b"\n" in pending:
                    line, pending = pending.split(b"\n", 1)
                    message = json.loads(line)
                    if message.get("id") == request_id:
                        if "error" in message:
                            raise RuntimeError("Codex usage unavailable")
                        return message["result"]
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not select.select([proc.stdout], [], [], remaining)[0]:
                    raise TimeoutError("Codex usage timed out")
                chunk = os.read(proc.stdout.fileno(), 65536)
                if not chunk:
                    raise RuntimeError("Codex app server closed")
                pending += chunk

        try:
            send({"id": 1, "method": "initialize", "params": {
                "clientInfo": {"name": "conky_usage", "version": "1.0"},
            }})
            receive(1)
            send({"method": "initialized"})
            send({"id": 2, "method": "account/rateLimits/read"})
            result = receive(2)
            data = (result.get("rateLimitsByLimitId") or {}).get("codex")
            data = data or result["rateLimits"]
            return data, data.get("planType")
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()


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
    resets = w.get("resetsAt")
    resets = datetime.fromtimestamp(resets).astimezone() if resets else None
    # Cached data outlives the window it describes; a past reset means 0 used.
    if resets and resets <= datetime.now().astimezone():
        return 0, None
    return round(w.get("usedPercent") or 0), resets


def fmt_reset(dt):
    if not dt:
        return "-"
    now = datetime.now().astimezone()
    return dt.strftime("%H:%M" if dt.date() == now.date() else "%a %H:%M")


key = sys.argv[1] if len(sys.argv) > 1 else "session_pct"
cache = load()
data = cache.get("data")

if key == "plan":
    print((cache.get("plan") or "Codex") if data else "offline")
elif key in ("session_pct", "week_pct"):
    print(window(data, "primary" if key == "session_pct" else "secondary")[0])
elif key in ("session_reset", "week_reset"):
    print(fmt_reset(window(data, "primary" if key == "session_reset" else "secondary")[1]))
else:
    print("?")
