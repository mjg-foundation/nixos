"""Live isolation test: python3 -B test_sandbox.py /nix/store/...-settings.json.

Requires working unprivileged user/network namespaces, but no running model.
"""

import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

spec = importlib.util.spec_from_file_location("local_code", Path(__file__).with_name("local-code.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
settings = json.loads(Path(sys.argv[1]).read_text())
# Test fixtures must never invoke the user's signing setup, hooks, or helpers.
os.environ["GIT_CONFIG_GLOBAL"] = "/dev/null"
os.environ["GIT_CONFIG_NOSYSTEM"] = "1"
os.environ["GIT_TERMINAL_PROMPT"] = "0"

with tempfile.TemporaryDirectory(prefix="local-code-isolation-test-") as temporary:
    root = Path(temporary)
    repo = root / "repo"
    repo.mkdir()
    subprocess.run([settings["git"], "init", "-q", str(repo)], check=True)
    if "--worktree" in sys.argv:
        subprocess.run([settings["git"], "-C", str(repo), "-c", "user.name=Test",
                        "-c", "user.email=test@example.invalid", "-c", "commit.gpgsign=false",
                        "-c", "core.hooksPath=/dev/null", "commit", "--no-gpg-sign", "--allow-empty",
                        "-qm", "initial"], check=True)
        worktree = root / "worktree"
        subprocess.run([settings["git"], "-C", str(repo), "worktree", "add", "-qb",
                        "agent", str(worktree)], check=True)
        repo = worktree
    sentinel = root / "outside-secret"
    sentinel.write_text("must stay private")
    (repo / "escape-link").symlink_to(sentinel)
    state = root / "state" / "home"
    state.mkdir(parents=True)
    for name in ("passwd", "group", "hosts"):
        (state.parent / name).write_text("")
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen()
    port = listener.getsockname()[1]
    unix_socket = root / "model.sock"
    # A fixed Unix bridge provides the only allowed route to the host listener.
    proxy = subprocess.Popen([settings["socat"], f"UNIX-LISTEN:{unix_socket},fork", f"TCP:127.0.0.1:{port}"])
    try:
        for _ in range(100):
            if unix_socket.exists():
                break
            time.sleep(0.05)
        os.chdir(repo)
        android_sdk = None
        if "--android" in sys.argv:
            android_sdk = root / "sdk"
            (android_sdk / "emulator").mkdir(parents=True)
            (android_sdk / "emulator/emulator").write_text("fixture only; no emulator boot\n")
        args = m.sandbox_args(settings, repo, state, unix_socket, android_sdk)
        if "--mcp" in sys.argv or "--goal" in sys.argv:
            config = m.agent_config("eco", settings["profiles"]["eco"], settings["goalPlugin"])
            config["plugin"].append(settings["statusPlugin"])
            if "--mcp" in sys.argv:
                config["mcp"] = {"android": {"type": "local", "command": [settings["androidTools"]], "enabled": True}}
            args += ["--setenv", "OPENCODE_CONFIG_CONTENT", json.dumps(config),
                     "--setenv", "OPENCODE_DISABLE_MODELS_FETCH", "true",
                     "--setenv", "LOCAL_CODE_TEST_OPENCODE", settings["opencode"],
                     "--setenv", "LOCAL_CODE_STATUS_FILE", "/home/agent/status-test.json",
                     "--setenv", "LOCAL_CODE_TEST_GOAL", str("--goal" in sys.argv),
                     "--setenv", "LOCAL_CODE_TEST_MCP", str("--mcp" in sys.argv)]
        code = '''
import os, pathlib, socket, subprocess, sys
repo, sentinel, port = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), int(sys.argv[3])
assert not sentinel.exists(), "host file exposed"
assert not (repo / "escape-link").exists(), "symlink escaped sandbox"
assert not pathlib.Path("/run/nix/daemon-socket/socket").exists(), "Nix daemon exposed"
assert not pathlib.Path("/run/user/1000/bus").exists(), "host D-Bus exposed"
assert "SSH_AUTH_SOCK" not in os.environ
assert "LOCAL_CODE_TEST_SECRET" not in os.environ
assert "DISPLAY" not in os.environ
assert "WAYLAND_DISPLAY" not in os.environ
if "ANDROID_HOME" in os.environ:
    import fcntl
    with open("/dev/kvm", "rb") as kvm:
        assert fcntl.ioctl(kvm, 0xAE00, 0) == 12, "KVM_GET_API_VERSION failed"
    try:
        pathlib.Path("/opt/android-sdk/emulator/emulator").write_text("unsafe")
    except OSError:
        pass
    else:
        raise AssertionError("Android SDK writable")
else:
    assert not pathlib.Path("/dev/kvm").exists(), "KVM exposed without grant"
try:
    metadata = repo / ".git" if (repo / ".git").is_file() else repo / ".git/config"
    metadata.write_text("unsafe")
except OSError:
    pass
else:
    raise AssertionError("Git metadata writable")
(repo / "allowed.txt").write_text("repo writes work")
pathlib.Path.home().joinpath("allowed-state").write_text("private state works")
for address in [("127.0.0.1", port), ("1.1.1.1", 443)]:
    try:
        s = socket.create_connection(address, timeout=1)
    except OSError:
        pass
    else:
        s.close()
        raise AssertionError("unexpected network access: " + str(address))
s = socket.socket(socket.AF_UNIX)
s.connect("/run/local-code-model.sock")
s.sendall(b"model bridge works")
s.close()
(repo / "hello.c").write_text('int main(void) { return 0; }\\n')
subprocess.run(["cc", "hello.c", "-o", "hello"], check=True)
subprocess.run(["./hello"], check=True)
if os.environ.get("LOCAL_CODE_TEST_MCP") == "True":
    result = subprocess.run([os.environ["LOCAL_CODE_TEST_OPENCODE"], "mcp", "list"],
                            capture_output=True, text=True, timeout=45)
    assert result.returncode == 0 and "connected" in result.stdout.lower(), result.stdout + result.stderr
    print("PASS: OpenCode connected to packaged Android MCP helper inside sandbox")
if os.environ.get("LOCAL_CODE_TEST_GOAL") == "True":
    import json, time, urllib.request
    server = subprocess.Popen([os.environ["LOCAL_CODE_TEST_OPENCODE"], "serve", "--port", "18991"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for attempt in range(100):
            try:
                with urllib.request.urlopen("http://127.0.0.1:18991/experimental/tool/ids", timeout=2) as response:
                    tools = json.load(response)
                break
            except OSError:
                time.sleep(0.2)
        else:
            raise AssertionError("OpenCode plugin server did not become ready")
        assert {"goal_status", "goal_set", "goal_complete", "goal_pause"} <= set(tools), tools
        with urllib.request.urlopen("http://127.0.0.1:18991/command") as response:
            commands = json.load(response)
        assert any(c["name"] == "goal" for c in commands), commands
        print("PASS: packaged goal plugin tools and /goal command load in offline OpenCode sandbox")
        status_path = pathlib.Path("/home/agent/status-test.json")
        assert json.loads(status_path.read_text())["status"] == "waiting"
        def post(path, body):
            request = urllib.request.Request("http://127.0.0.1:18991" + path,
                data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        session = post("/session", {"title": "status integration test"})
        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor() as pool:
            job = pool.submit(post, "/session/" + session["id"] + "/shell",
                              {"agent": "build", "command": "sleep 3; echo status-test"})
            for attempt in range(100):
                if json.loads(status_path.read_text())["status"] == "working":
                    break
                time.sleep(0.1)
            else:
                raise AssertionError("OpenCode did not report working during shell command")
            job.result()
        for attempt in range(50):
            if json.loads(status_path.read_text())["status"] == "waiting":
                break
            time.sleep(0.1)
        else:
            raise AssertionError("OpenCode did not report waiting after shell command")
        print("PASS: real OpenCode session events publish working then waiting inside sandbox")
    finally:
        server.terminate()
        server.wait(timeout=15)
print("PASS: repo writes, private state, compiler, fixed model bridge; host files, symlink escape, Git writes, credentials, host sockets and external network blocked")
'''
        env = os.environ | {"LOCAL_CODE_TEST_SECRET": "not-for-agent"}
        subprocess.run(args + [settings["python"], "-c", code, str(repo), str(sentinel), str(port)],
                       env=env, check=True)
        listener.settimeout(3)
        connection, _ = listener.accept()
        with connection:
            assert connection.recv(1024) == b"model bridge works"
        assert sentinel.read_text() == "must stay private"
        assert (repo / "allowed.txt").exists()
    finally:
        proxy.terminate()
        proxy.wait(timeout=10)
        listener.close()
