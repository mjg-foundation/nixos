import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("web", Path(__file__).with_name("web-tools.py"))
web = importlib.util.module_from_spec(spec)
spec.loader.exec_module(web)


class WebTests(unittest.TestCase):
    def test_only_two_bounded_operations(self):
        for name, args in [("exec", {"command": "id"}), ("search", {"query": "x", "headers": {}}),
                           ("search", {"query": "x" * 1501}), ("search", {"query": "\n"}),
                           ("fetch", {"url": "https://example.org", "method": "POST"})]:
            with self.assertRaises(ValueError):
                web.tool_params(name, args)
        self.assertEqual(web.tool_params("search", {"query": "Flutter docs"})["arguments"]["numResults"], 5)

    def test_disallow_local_urls_credentials_and_alternate_protocols(self):
        for url in ["file:///etc/passwd", "http://localhost/x", "http://127.0.0.1", "http://10.0.0.1",
                    "http://169.254.169.254/latest", "http://[::1]", "http://2130706433", "http://127.1",
                    "http://host.local", "https://u:p@example.com", "https://example.com:22",
                    "https://example.com\\@localhost", "https://example.com/\r\nHeader: x"]:
            with self.subTest(url=url), self.assertRaises(ValueError):
                web.tool_params("fetch", {"url": url})
        self.assertEqual(web.tool_params("fetch", {"url": "https://docs.flutter.dev/"})["name"], "web_fetch_exa")

    def test_only_fixed_remote_endpoint_and_text_output(self):
        class Response:
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def read(self, size):
                return json.dumps({"id": 1, "result": {"content": [
                    {"type": "text", "text": "x" * 20000},
                    {"type": "resource", "resource": {"uri": "file:///etc/passwd"}},
                ]}}).encode()
        with patch.object(web.urllib.request, "build_opener") as build:
            build.return_value.open.return_value = Response()
            result = web.remote_call("fetch", {"url": "https://docs.flutter.dev/"})
            request = build.return_value.open.call_args.args[0]
            self.assertEqual(request.full_url, web.ENDPOINT)
            self.assertEqual(request.get_method(), "POST")
            self.assertNotIn("Authorization", request.headers)
            self.assertNotIn("Cookie", request.headers)
            self.assertEqual(len(result["content"]), 1)
            self.assertLess(len(result["content"][0]["text"]), 17000)

    def test_redirect_rejected(self):
        with self.assertRaises(ValueError):
            web.NoRedirect().redirect_request(None, None, 302, "", {}, "http://127.0.0.1/")

    def test_sse_response_and_provider_errors(self):
        result = {"id": 1, "result": {"content": [{"type": "text", "text": "source https://example.org"}]}}
        parsed = web.parse_remote(("event: message\ndata: " + json.dumps(result) + "\n\n").encode())
        self.assertIn("https://example.org", parsed["content"][0]["text"])
        with self.assertRaises(ValueError):
            web.parse_remote(b'{"id":1,"error":{"message":"failure"}}')

    def test_mcp_protocol_without_network(self):
        messages = [{"jsonrpc": "2.0", "id": i, "method": method} for i, method in
                    enumerate(["initialize", "tools/list", "ping", "unknown"])]
        process = subprocess.run([sys.executable, str(Path(web.__file__))],
                                 input="\n".join(map(json.dumps, messages)) + "\n",
                                 capture_output=True, text=True, check=True)
        responses = list(map(json.loads, process.stdout.splitlines()))
        self.assertEqual({t["name"] for t in responses[1]["result"]["tools"]}, {"search", "fetch"})
        self.assertEqual(responses[3]["error"]["code"], -32601)


if __name__ == "__main__":
    unittest.main()
