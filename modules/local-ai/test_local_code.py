"""Regression checks for power selection, interruption, and shell-safe tasks."""

import importlib.util
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location("local_code", Path(__file__).with_name("local-code.py"))
local_code = importlib.util.module_from_spec(spec)
spec.loader.exec_module(local_code)


class LocalCodeTests(unittest.TestCase):
    def test_only_approved_store_toolchain_variables_cross_boundary(self):
        store = "/nix/store/jxyrvv4gbpnp3ap5iy7wxwl1sg4x2x88-python3-3.14.6"
        with patch.object(local_code.Path, "exists", return_value=True):
            result = local_code.toolchain_env({
                "JAVA_HOME": store, "ANDROID_NDK_ROOT": "/home/matt/private",
                "AWS_SECRET_ACCESS_KEY": "secret", "GRADLE_OPTS": "secret",
                "CMAKE_PREFIX_PATH": store + ":/tmp/unsafe",
            })
        self.assertEqual(result, {"JAVA_HOME": store})

    def test_image_capability_only_on_vision_profile(self):
        for vision in (False, True):
            config = local_code.agent_config("eco", {"port": 8087, "name": "test", "vision": vision})
            model = config["provider"]["local"]["models"]["eco"]
            self.assertEqual("image" in model["modalities"]["input"], vision)
            self.assertEqual(model["attachment"], vision)

    def test_power_detection_including_usb_c_and_unknown(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertFalse(local_code.on_ac(root))
            battery = root / "BAT1"
            battery.mkdir()
            (battery / "type").write_text("Battery\n")
            (battery / "online").write_text("1\n")
            self.assertFalse(local_code.on_ac(root))
            ac = root / "ucsi-source-psy-USBC000:001"
            ac.mkdir()
            (ac / "type").write_text("USB\n")
            (ac / "online").write_text("1\n")
            self.assertTrue(local_code.on_ac(root))
            (ac / "online").write_text("0\n")
            self.assertFalse(local_code.on_ac(root))

    def test_host_and_power_selection(self):
        both = {"eco": {}, "performance": {}}
        self.assertEqual(local_code.select_profile("auto", both, True), "performance")
        self.assertEqual(local_code.select_profile("auto", both, False), "eco")
        self.assertEqual(local_code.select_profile("auto", {"eco": {}}, True), "eco")
        with self.assertRaises(ValueError):
            local_code.select_profile("performance", both, False)
        with self.assertRaises(ValueError):
            local_code.select_profile("performance", {"eco": {}}, True)

    def test_do_not_interrupt_another_profile(self):
        settings = {"profiles": {"eco": {}, "performance": {}}}
        with patch.object(local_code, "active", return_value=True), patch.object(local_code, "systemctl") as ctl:
            with self.assertRaisesRegex(ValueError, "local-code stop"):
                local_code.start(settings, "eco")
            ctl.assert_not_called()

    def test_ac_removal_terminates_large_model(self):
        child = Mock()
        child.poll.return_value = None
        settings = {"profiles": {"performance": {}}, "notify": "notify-send"}
        with patch.object(local_code, "on_ac", side_effect=[True, False]), \
             patch.object(local_code, "server_args", return_value=["llama-server"]), \
             patch.object(local_code.subprocess, "Popen", return_value=child), \
             patch.object(local_code.subprocess, "run"):
            self.assertEqual(local_code.serve(settings, "performance"), 0)
        child.terminate.assert_called_once()
        child.wait.assert_called_once_with(timeout=10)

    def test_background_prompt_is_one_literal_shell_argument(self):
        prompt = "Fix 'quotes'; $(touch /tmp/must-not-exist)\n`echo test`"
        with patch.object(local_code, "start"), \
             patch.object(local_code, "repo_root"), \
             patch.object(local_code.sys, "argv", ["launcher", "/nix/store/settings.json"]), \
             patch.object(local_code.subprocess, "run") as run:
            local_code.main({"tmux": "tmux"}, ["background", prompt])
        command = run.call_args.args[0][-1]
        self.assertEqual(shlex.split(command)[-3:], ["eco", "--prompt", prompt])

    def test_failed_server_is_reported_without_launching_agent(self):
        settings = {"profiles": {"eco": {"port": 8087}}}
        with patch.object(local_code, "systemctl", return_value=subprocess.CompletedProcess([], 0)), \
             patch.object(local_code, "active", return_value=False):
            with self.assertRaisesRegex(ValueError, "journalctl"):
                local_code.start(settings, "eco")


if __name__ == "__main__":
    unittest.main()
