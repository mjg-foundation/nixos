"""Waybar activity for live Codex terminals, with ai-usagebar's quota tooltip.

Only processes with a terminal are counted. Codex's live terminal title takes
precedence over rollout state: a turn stays open while an approval is pending.
Unknown or ambiguous window mappings are never treated as proof of work.
"""

import collections
import html
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time


COLORS = {"#5c6370": "#a6afbd", "#abb2bf": "#e6edf3", "#3e4451": "#737f91"}
SPINNER_FRAMES = frozenset("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏")


def title_state(title):
    # Codex 0.153.4: tui/src/chatwidget/status_surfaces.rs. Both phases of
    # the blinking action-required title must count as waiting. This covers
    # exec approvals, MCP elicitations, and request_user_input overlays.
    if title.startswith(("[ ! ] Action Required", "[ . ] Action Required")):
        return "waiting"
    if title[:1] in SPINNER_FRAMES and title[1:2] == " ":
        return "working"
    return None


def window_states(processes, clients, proc=Path("/proc")):
    windows = collections.defaultdict(list)
    for client in clients:
        if isinstance(client.get("pid"), int) and client["pid"] > 0:
            windows[str(client["pid"])].append(client)
    owners = {}
    for pid, *_ in processes:
        parent = pid
        seen = set()
        while parent not in seen and parent != "0":
            seen.add(parent)
            if parent in windows:
                owners[pid] = parent
                break
            try:
                # comm in /proc/PID/stat may itself contain spaces or ')'.
                fields = (proc / parent / "stat").read_text().rsplit(")", 1)[1].split()
                parent = fields[1]
            except (OSError, IndexError):
                break
    counts = collections.Counter(owners.values())
    result = {}
    for pid, owner in owners.items():
        # A terminal with multiple tabs/windows only publishes the visible
        # title. Do not assign that state to every Codex sharing its process.
        if counts[owner] == 1 and len(windows[owner]) == 1:
            result[pid] = title_state(windows[owner][0].get("title", ""))
    return result


def hyprland_clients(binary):
    try:
        output = subprocess.run(
            [binary, "clients", "-j"], capture_output=True, text=True,
            timeout=2, check=True,
        )
        clients = json.loads(output.stdout)
        if isinstance(clients, list) and all(isinstance(c, dict) for c in clients):
            return clients
    except (OSError, subprocess.SubprocessError, ValueError):
        pass
    return []


def brighten(tooltip):
    for old, new in COLORS.items():
        tooltip = tooltip.replace(old, new)
    return '<span weight="semibold">' + tooltip + '</span>'


class Session:
    def __init__(self, path):
        self.path = path
        self.offset = 0
        self.state = "unknown"
        self.pending = set()
        self.identity = None

    def apply(self, record):
        payload = record.get("payload", {})
        kind = payload.get("type")
        if self.state == "fresh" and (
            record.get("type") == "turn_context"
            or (record.get("type") == "event_msg" and kind == "user_message")
            or (record.get("type") == "response_item" and payload.get("role") == "user")
        ):
            self.state = "unknown"
        if record.get("type") == "event_msg":
            if kind in ("task_started", "turn_started"):
                self.state = "working"
                self.pending.clear()
            elif kind in ("task_complete", "turn_complete", "turn_aborted"):
                self.state = "waiting"
                self.pending.clear()
        elif record.get("type") == "response_item":
            call_id = payload.get("call_id")
            if kind == "function_call" and payload.get("name", "").split(".")[-1] == "request_user_input":
                self.pending.add(call_id)
            elif kind == "function_call_output":
                self.pending.discard(call_id)

    def update(self):
        with self.path.open("rb") as stream:
            stat = os.fstat(stream.fileno())
            identity = (stat.st_dev, stat.st_ino)
            if self.identity != identity or stat.st_size < self.offset:
                self.state = "unknown"
                self.pending.clear()
                # Bootstrap from a bounded tail; subsequent polls read only
                # appended records. A missing turn boundary remains unknown.
                self.offset = max(0, stat.st_size - 8 * 1024 * 1024)
                # Only a complete history can establish that no task has
                # started. A bounded tail of an older session is not fresh.
                self.state = "fresh" if self.offset == 0 else "unknown"
                stream.seek(self.offset)
                if self.offset:
                    stream.readline()
                    self.offset = stream.tell()
                self.identity = identity
            stream.seek(self.offset)
            # Do not chase a writer indefinitely or consume a partial record.
            end = stat.st_size
            while stream.tell() < end:
                line = stream.readline(end - stream.tell())
                if not line.endswith(b"\n"):
                    break
                self.offset = stream.tell()
                try:
                    record = json.loads(line)
                    if isinstance(record, dict) and isinstance(record.get("payload"), dict):
                        self.apply(record)
                    elif self.state == "fresh":
                        self.state = "unknown"
                except (ValueError, UnicodeError):
                    if self.state == "fresh":
                        self.state = "unknown"
                    continue
        return "waiting" if self.pending else self.state


def cli_rollout(path):
    try:
        with path.open("rb") as stream:
            meta = json.loads(stream.readline(65536))
        return meta.get("type") == "session_meta" and meta.get("payload", {}).get("source") == "cli"
    except (OSError, ValueError):
        return False


def terminals(proc=Path("/proc")):
    result = []
    for process in proc.iterdir():
        if not process.name.isdigit():
            continue
        try:
            if process.stat().st_uid != os.getuid():
                continue
            if process.joinpath("comm").read_text().strip() not in ("codex", ".codex-wrapped"):
                continue
            args = process.joinpath("cmdline").read_bytes().split(b"\0")
            if any(arg in (b"app-server", b"mcp-server", b"exec", b"e", b"review") for arg in args[1:]):
                continue
            tty = os.readlink(process / "fd/0")
            if not tty.startswith("/dev/pts/"):
                continue
            paths = set()
            for fd in process.joinpath("fd").iterdir():
                try:
                    target = Path(os.readlink(fd))
                    if target.name.startswith("rollout-") and target.suffix == ".jsonl" and cli_rollout(target):
                        paths.add(target)
                except OSError:
                    continue
            cwd = Path(os.readlink(process / "cwd")).name
            # No rollout can mean the startup screen or an unreadable session.
            result.append((process.name, tty.removeprefix("/dev/"), cwd, paths))
        except OSError:
            continue  # Process exited during discovery.
    return result


def activity(processes, sessions, live_states=None):
    live_states = live_states or {}
    counts = collections.Counter()
    lines = []
    live_paths = set()
    for pid, tty, cwd, paths in processes:
        states = []
        for path in paths:
            live_paths.add(path)
            session = sessions.setdefault(path, Session(path))
            try:
                states.append(session.update())
            except OSError:
                states.append("unknown")
        # The launch screen has no rollout; a new rollout may contain only
        # setup records. Neither should make the tile appear before a task.
        if not states or all(state == "fresh" for state in states):
            continue
        state = next((s for s in ("working", "waiting", "unknown") if s in states), "unknown")
        live_state = live_states.get(pid)
        if live_state is not None:
            state = live_state
        elif state == "working":
            # An open turn alone cannot distinguish actual work from a
            # permission prompt, especially with a custom/hidden title.
            state = "unknown"
        counts[state] += 1
        label = "waiting for input" if state == "waiting" else state
        lines.append(html.escape(f"{tty} · {cwd} · {label}"))
    for path in list(sessions):
        if path not in live_paths:
            del sessions[path]
    parts = [f"{counts[s]} {s}" for s in ("working", "waiting", "unknown") if counts[s]]
    # Waybar hides custom modules with empty text; keep polling for new agents.
    text = "Codex: " + " · ".join(parts) if parts else ""
    tooltip = '<b>Codex terminals</b>\n' + ("\n".join(lines) if lines else "No running CLI sessions")
    if counts["unknown"]:
        tooltip += '\n<span foreground="#a6afbd">Unknown: no unambiguous live Codex title.\nKeep the spinner enabled in Codex /terminal-title.</span>'
    classes = [s for s in ("working", "waiting", "unknown") if counts[s]] or ["offline"]
    return {"text": text, "tooltip": tooltip, "class": classes}


def fetch_quota(binary):
    try:
        output = subprocess.run(
            [binary, "--vendor", "openai", "--json", "--format", "{vendor_short}"],
            capture_output=True, text=True, timeout=30, check=True,
        )
        tooltip = json.loads(output.stdout).get("tooltip")
        if isinstance(tooltip, str) and tooltip:
            return brighten(tooltip)
    except (OSError, subprocess.SubprocessError, ValueError):
        pass
    return "Codex usage unavailable; click to open the usage dashboard."


def main():
    quota = ["Loading Codex usage…"]

    def refresh():
        while True:
            quota[0] = fetch_quota(sys.argv[1])
            time.sleep(300)

    threading.Thread(target=refresh, daemon=True).start()
    sessions = {}
    while True:
        processes = terminals()
        live_states = window_states(processes, hyprland_clients(sys.argv[2]))
        result = activity(processes, sessions, live_states)
        result["tooltip"] += "\n\n" + quota[0]
        print(json.dumps(result), flush=True)
        time.sleep(2)


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        pass
