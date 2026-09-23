"""MCP protocol and Android command-boundary tests; no SDK/device required."""

import importlib.util
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("android_tools", Path(__file__).with_name("android-tools.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class AndroidTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        env = {"LOCAL_CODE_ANDROID": "1", "ANDROID_HOME": "/opt/android-sdk",
               "LOCAL_CODE_REPO": str(self.repo), "LOCAL_CODE_VISION": "1"}
        self.patch = patch.dict(os.environ, env)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.android = m.Android()

    def test_grant_required(self):
        with patch.dict(os.environ, {"LOCAL_CODE_ANDROID": "0"}):
            with self.assertRaises(ValueError):
                m.Android()

    def test_adb_is_local_and_rejects_physical_or_network_serial(self):
        with patch.object(self.android, "run", return_value=b"ok") as run:
            self.android.adb("emulator-5554", "get-state")
            self.assertEqual(run.call_args.args[0][1:5], ["-L", "tcp:5037", "-s", "emulator-5554"])
            for serial in ("phone123", "192.168.1.10:5555", "emulator-5554;id"):
                with self.assertRaises(ValueError):
                    self.android.adb(serial, "get-state")

    def test_text_cannot_inject_device_shell(self):
        value = "hello;$(id)' & goodbye"
        with patch.object(self.android, "adb", return_value=b"") as adb:
            self.android.call("input", {"serial": "emulator-5554", "action": "text", "text": value})
            command = adb.call_args.args[-1]
            self.assertEqual(shlex.split(command), ["input", "text", value.replace(" ", "%s")])

    def test_apk_path_cannot_escape_repo(self):
        with tempfile.TemporaryDirectory() as outside:
            apk = Path(outside) / "outside.apk"
            apk.write_bytes(b"apk")
            (self.repo / "link.apk").symlink_to(apk)
            with self.assertRaises(ValueError):
                self.android.call("app", {"serial": "emulator-5554", "action": "install", "apk": str(self.repo / "link.apk")})

    def test_screenshot_is_image_only_for_vision_model(self):
        png = b"\x89PNG\r\n\x1a\nfixture"
        with patch.object(self.android, "adb", return_value=png):
            result = self.android.call("inspect", {"serial": "emulator-5554", "kind": "screenshot"})
            self.assertEqual(result["content"][1]["type"], "image")
            with patch.dict(os.environ, {"LOCAL_CODE_VISION": "0"}):
                result = self.android.call("inspect", {"serial": "emulator-5554", "kind": "screenshot"})
            self.assertEqual(len(result["content"]), 1)
            self.assertIn("text-only", result["content"][0]["text"])
        self.assertEqual(len(list(self.repo.glob(".local-code-artifacts/android/*.png"))), 2)

    def test_protocol_initialization_and_tool_error(self):
        requests = [
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
            {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "input", "arguments": {"serial": "emulator-5554", "action": "tap", "x": -1}}},
        ]
        process = subprocess.run([sys.executable, "-B", str(Path(m.__file__))],
            input="\n".join(map(json.dumps, requests)) + "\n", text=True, capture_output=True, check=True)
        responses = [json.loads(line) for line in process.stdout.splitlines()]
        self.assertEqual([r["id"] for r in responses], [1, 2, 3])
        self.assertEqual(len(responses[1]["result"]["tools"]), 6)
        self.assertTrue(responses[2]["result"]["isError"])


if __name__ == "__main__":
    unittest.main()
