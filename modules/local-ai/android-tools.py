"""Small stdio MCP server for Android emulators inside the local-code sandbox.

The repository supplies the SDK and AVD. This server never connects to host
ADB, physical devices, a display server, or a remote MCP service.
"""

import base64
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time


def definition(name, description, properties, required=()):
    return {"name": name, "description": description, "inputSchema": {
        "type": "object", "properties": properties,
        "required": list(required), "additionalProperties": False,
    }}


STRING = {"type": "string"}
INTEGER = {"type": "integer", "minimum": 0, "maximum": 100000}
SERIAL = {"type": "string", "pattern": "^emulator-[0-9]+$"}
TOOLS = [
    definition("devices", "List emulators on this sandbox's private ADB server.", {}),
    definition("avd", "List repo AVDs or boot one headlessly. Boot returns immediately; use status until booted.", {
        "action": {"enum": ["list", "boot"]}, "name": STRING,
        "port": {"type": "integer", "minimum": 5554, "maximum": 5682},
    }, ["action"]),
    definition("app", "Install a repo APK, launch a component, or stop a package on a sandbox emulator.", {
        "serial": SERIAL, "action": {"enum": ["install", "launch", "stop"]},
        "apk": STRING, "component": STRING, "package": STRING,
    }, ["serial", "action"]),
    definition("input", "Tap/swipe coordinates, type ASCII text, or send an Android keycode.", {
        "serial": SERIAL, "action": {"enum": ["tap", "swipe", "text", "key"]},
        "x": INTEGER, "y": INTEGER, "x2": INTEGER, "y2": INTEGER,
        "duration_ms": {"type": "integer", "minimum": 1, "maximum": 5000},
        "text": STRING, "keycode": INTEGER,
    }, ["serial", "action"]),
    definition("inspect", "Get boot status, UI hierarchy XML, recent logs, or a screenshot. Screenshots return images only with eco vision; also saved in the repo.", {
        "serial": SERIAL, "kind": {"enum": ["status", "ui", "logs", "screenshot"]},
    }, ["serial", "kind"]),
    definition("shutdown", "Shut down a sandbox emulator (its private AVD data persists).", {
        "serial": SERIAL,
    }, ["serial"]),
]


def text(value):
    return {"content": [{"type": "text", "text": value}]}


class Android:
    def __init__(self):
        if os.environ.get("LOCAL_CODE_ANDROID") != "1":
            raise ValueError("Launch with local-code --android or --android-sdk to grant emulator access.")
        self.sdk = Path(os.environ["ANDROID_HOME"])
        self.repo = Path(os.environ["LOCAL_CODE_REPO"]).resolve()

    def run(self, args, timeout=30):
        result = subprocess.run(args, capture_output=True, timeout=timeout, check=False)
        if result.returncode:
            raise ValueError(result.stderr.decode(errors="replace")[-4000:] or
                             result.stdout.decode(errors="replace")[-4000:] or "Android command failed")
        return result.stdout

    def adb(self, serial, *args, timeout=30):
        # tcp:PORT is ADB's local-only socket form. Naming 127.0.0.1 with -H
        # or -L is classified as remote and prevents automatic server startup.
        command = [str(self.sdk / "platform-tools/adb"), "-L", "tcp:5037"]
        if serial is not None:
            if not isinstance(serial, str) or not re.fullmatch(r"emulator-\d+", serial):
                raise ValueError("Only local emulator-NNNN serials are allowed.")
            command += ["-s", serial]
        return self.run(command + list(args), timeout)

    def shell(self, serial, *args):
        # ADB joins shell arguments on the device: quote even though no host
        # shell is used, so input text cannot become a device shell command.
        return self.adb(serial, "shell", shlex.join(map(str, args)))

    def call(self, name, a):
        serial = a.get("serial")
        if name == "devices":
            output = self.adb(None, "devices", "-l").decode(errors="replace")
            return text("\n".join(line for line in output.splitlines() if line.startswith("emulator-")) or "No emulators running.")
        if name == "avd":
            emulator = str(self.sdk / "emulator/emulator")
            available = self.run([emulator, "-list-avds"]).decode().splitlines()
            if a["action"] == "list":
                return text("\n".join(available) or "No AVDs. Create one with the repo's setup command.")
            avd = a.get("name", "")
            port = a.get("port", 5554)
            if avd not in available or not re.fullmatch(r"[A-Za-z0-9_.-]+", avd):
                raise ValueError("Choose an existing repo AVD from avd/list.")
            if port % 2:
                raise ValueError("Emulator console port must be even.")
            # Start our namespace-local ADB first. No inherited host socket.
            self.adb(None, "start-server")
            directory = Path.home() / ".local/state/local-code/android"
            directory.mkdir(parents=True, exist_ok=True)
            log = directory / f"emulator-{port}.log"
            with log.open("ab") as handle:
                process = subprocess.Popen([
                    emulator, "-avd", avd, "-port", str(port), "-no-window",
                    "-no-audio", "-gpu", "swiftshader", "-no-snapshot-save", "-no-boot-anim",
                ], stdin=subprocess.DEVNULL, stdout=handle, stderr=handle)
            return text(f"Started emulator-{port} (pid {process.pid}); inspect/status until booted. Log: {log}")
        if name == "app":
            if a["action"] == "install":
                apk = Path(a["apk"]).resolve(strict=True)
                if not apk.is_relative_to(self.repo) or apk.suffix.lower() != ".apk":
                    raise ValueError("APK must be a file inside this repo.")
                return text(self.adb(serial, "install", "-r", str(apk), timeout=50).decode(errors="replace"))
            if a["action"] == "launch":
                component = a["component"]
                if not re.fullmatch(r"[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+", component):
                    raise ValueError("Expected package/activity component.")
                return text(self.shell(serial, "am", "start", "-W", "-n", component).decode(errors="replace"))
            package = a["package"]
            if not re.fullmatch(r"[A-Za-z0-9_.]+", package):
                raise ValueError("Invalid package name.")
            return text(self.shell(serial, "am", "force-stop", package).decode(errors="replace"))
        if name == "input":
            action = a["action"]
            if action == "tap":
                args = ["tap", a["x"], a["y"]]
            elif action == "swipe":
                args = ["swipe", a["x"], a["y"], a["x2"], a["y2"], a.get("duration_ms", 300)]
            elif action == "key":
                args = ["keyevent", a["keycode"]]
            else:
                value = a["text"]
                if len(value) > 1000 or not value.isascii() or any(ord(c) < 32 for c in value):
                    raise ValueError("Input supports up to 1000 printable ASCII characters; use app tests for Unicode input.")
                args = ["text", value.replace(" ", "%s")]
            return text(self.shell(serial, "input", *args).decode(errors="replace") or "Input sent.")
        if name == "inspect":
            kind = a["kind"]
            if kind == "status":
                booted = self.shell(serial, "getprop", "sys.boot_completed").decode().strip()
                return text("booted" if booted == "1" else "still booting")
            if kind == "logs":
                return text(self.adb(serial, "logcat", "-d", "-t", "150").decode(errors="replace")[-24000:])
            if kind == "ui":
                self.shell(serial, "uiautomator", "dump", "/sdcard/local-code-window.xml")
                return text(self.adb(serial, "exec-out", "cat", "/sdcard/local-code-window.xml").decode(errors="replace")[:50000])
            png = self.adb(serial, "exec-out", "screencap", "-p")
            if not png.startswith(b"\x89PNG\r\n\x1a\n") or len(png) > 16 * 1024 * 1024:
                raise ValueError("Invalid or oversized screenshot (limit 16 MiB).")
            folder = self.repo / ".local-code-artifacts/android"
            folder.mkdir(parents=True, exist_ok=True)
            path = folder / f"{serial}-{time.time_ns()}.png"
            path.write_bytes(png)
            result = text(f"Screenshot saved: {path}")
            if os.environ.get("LOCAL_CODE_VISION") == "1":
                result["content"].append({"type": "image", "mimeType": "image/png",
                                          "data": base64.b64encode(png).decode()})
            else:
                result["content"][0]["text"] += "\nCurrent model is text-only. Use inspect/ui, or resume under local-code eco for visual inspection."
            return result
        if name == "shutdown":
            return text(self.adb(serial, "emu", "kill").decode(errors="replace"))
        raise ValueError("Unknown tool.")


def validate(name, arguments):
    schema = next((t["inputSchema"] for t in TOOLS if t["name"] == name), None)
    if schema is None or not isinstance(arguments, dict):
        raise ValueError("Unknown tool or invalid arguments.")
    if set(arguments) - set(schema["properties"]):
        raise ValueError("Unexpected arguments.")
    for key in schema["required"]:
        if key not in arguments:
            raise ValueError(f"Missing {key}.")
    for key, value in arguments.items():
        rule = schema["properties"][key]
        if "enum" in rule and value not in rule["enum"]:
            raise ValueError(f"Invalid {key}.")
        if rule.get("type") == "integer":
            if type(value) is not int or not rule.get("minimum", 0) <= value <= rule.get("maximum", 100000):
                raise ValueError(f"Invalid {key}.")
        if rule.get("type") == "string" and not isinstance(value, str):
            raise ValueError(f"Invalid {key}.")
    if name not in ("devices", "avd") and "serial" not in arguments:
        raise ValueError("Missing serial.")


def main():
    # MCP stdio transport is one JSON-RPC message per line, stdout reserved.
    for line in sys.stdin:
        request = json.loads(line)
        if "id" not in request:
            continue
        response = {"jsonrpc": "2.0", "id": request["id"]}
        method = request.get("method")
        if method == "initialize":
            response["result"] = {"protocolVersion": "2024-11-05", "capabilities": {"tools": {}},
                                  "serverInfo": {"name": "local-android-tools", "version": "1.0.0"}}
        elif method == "ping":
            response["result"] = {}
        elif method == "tools/list":
            response["result"] = {"tools": TOOLS}
        elif method == "tools/call":
            try:
                params = request["params"]
                arguments = params.get("arguments", {})
                validate(params["name"], arguments)
                response["result"] = Android().call(params["name"], arguments)
            except (ValueError, OSError, KeyError, subprocess.TimeoutExpired) as error:
                response["result"] = text(str(error)) | {"isError": True}
        else:
            response["error"] = {"code": -32601, "message": "Method not found"}
        print(json.dumps(response), flush=True)


if __name__ == "__main__":
    main()
