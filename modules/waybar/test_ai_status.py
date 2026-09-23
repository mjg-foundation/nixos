import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


root = Path(__file__).resolve().parents[1]
bar = load("bar", root / "waybar/codex-status.py")
launcher = load("launcher", root / "local-ai/local-code.py")


class StatusTests(unittest.TestCase):
    def test_combined_tile_and_markup(self):
        result = bar.add_local_activity(
            {"text": "Codex: 1 working", "tooltip": "Codex", "class": ["working"]},
            [("1", "local", "<repo>", "waiting", "permission or question")])
        self.assertIn("Codex: 1 working, OpenCode:", result["text"])
        self.assertIn("1 waiting", result["text"])
        self.assertEqual(result["class"], ["working", "waiting"])
        self.assertIn("&lt;repo&gt;", result["tooltip"])

    def test_liveness_cleanup_pid_reuse_and_untrusted_payload(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            state = base / "home"
            with patch.dict(os.environ, {"XDG_RUNTIME_DIR": str(base)}):
                with launcher.status_record(Path("/repo"), state) as sandbox_path:
                    payload = state / Path(sandbox_path).relative_to("/home/agent")
                    payload.parent.mkdir(parents=True)
                    self.assertEqual(bar.local_sessions(base)[0][3], "unknown")
                    payload.write_text(json.dumps({"status": "waiting", "reason": "permission or question"}))
                    self.assertEqual(bar.local_sessions(base)[0][3], "waiting")
                    payload.write_text("[]")
                    self.assertEqual(bar.local_sessions(base)[0][3], "unknown")
                    payload.unlink()
                    payload.symlink_to(base / "missing")
                    self.assertEqual(bar.local_sessions(base)[0][3], "unknown")
                    record_path = next((base / "local-code-status").glob("*.json"))
                    record = json.loads(record_path.read_text())
                    record["start"] = "wrong process generation"
                    record_path.write_text(json.dumps(record))
                    self.assertEqual(bar.local_sessions(base), [])
                self.assertEqual(list((base / "local-code-status").iterdir()), [])

    def test_opencode_without_codex(self):
        result = bar.add_local_activity(bar.activity([], {}), [("1", "local", "repo", "working", "running")])
        self.assertEqual(result["text"], "OpenCode: 1 working")
        self.assertEqual(result["class"], ["working"])


if __name__ == "__main__":
    unittest.main()
