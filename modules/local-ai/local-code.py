"""Power-aware OpenCode launcher; all dependencies and weights are supplied by Nix."""

import json
import hashlib
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
from contextlib import contextmanager


@contextmanager
def status_record(repo, state):
    """Host-owned liveness record; the sandbox only writes the status payload."""
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/tmp/local-code-{os.getuid()}"))
    registry = runtime / "local-code-status"
    registry.mkdir(parents=True, exist_ok=True, mode=0o700)
    token = uuid.uuid4().hex
    relative = Path(".local/state/local-code-status") / f"{token}.json"
    status = state / relative
    record = registry / f"{token}.json"
    metadata = {
        "pid": str(os.getpid()),
        "start": Path("/proc/self/stat").read_text().rsplit(")", 1)[1].split()[19],
        "cwd": repo.name,
        "status_file": str(status),
    }
    record.write_text(json.dumps(metadata))
    try:
        yield str(Path("/home/agent") / relative)
    finally:
        record.unlink(missing_ok=True)
        status.unlink(missing_ok=True)


def repo_root(settings):
    result = subprocess.run(
        [settings["git"], "rev-parse", "--show-toplevel"],
        text=True, capture_output=True, check=False,
    )
    if result.returncode:
        raise ValueError("Run local-code inside a Git repository; only that repository will be writable.")
    repo = Path(result.stdout.strip()).resolve()
    if repo == Path.home() or repo in Path.home().parents:
        raise ValueError("Refusing to expose the root filesystem or your entire home as a repository.")
    return repo


def store_tool_path(settings, inherited_path):
    """Keep tools from nix develop, but no executable directories in host home."""
    paths = []
    for entry in inherited_path.split(os.pathsep):
        if entry:
            resolved = str(Path(entry).resolve())
            if resolved.startswith("/nix/store/") and Path(resolved).is_dir():
                paths.append(resolved)
    return os.pathsep.join([*paths, settings["toolPath"]])


def toolchain_env(environ):
    """Pass only known toolchain paths in the immutable store, never arbitrary env."""
    result = {}
    for name in ("JAVA_HOME", "ANDROID_NDK_ROOT", "ANDROID_NDK_HOME",
                 "FLUTTER_ROOT", "DART_SDK", "GRADLE_HOME", "CMAKE_PREFIX_PATH"):
        value = environ.get(name)
        if not value:
            continue
        paths = [Path(p).resolve() for p in value.split(":")]
        if all(str(p).startswith("/nix/store/") and p.exists() for p in paths):
            result[name] = ":".join(map(str, paths))
    return result


def sandbox_args(settings, repo, state, socket_path, android_sdk=None):
    """An allowlist of mounts, with no host home, network, IPC, or agent sockets."""
    args = [
        settings["bwrap"], "--unshare-all", "--die-with-parent", "--new-session",
        "--cap-drop", "ALL", "--clearenv",
        "--ro-bind", "/nix/store", "/nix/store",
        "--proc", "/proc", "--dev", "/dev", "--tmpfs", "/tmp",
        "--dir", "/run", "--dir", "/etc", "--dir", "/bin",
        "--symlink", settings["bash"], "/bin/sh",
        "--bind", str(repo), str(repo),
        "--bind", str(state), "/home/agent",
        "--ro-bind", str(socket_path), "/run/local-code-model.sock",
        "--setenv", "HOME", "/home/agent",
        "--setenv", "USER", "agent",
        "--setenv", "PATH", store_tool_path(settings, os.environ.get("PATH", "")),
        "--setenv", "LANG", "C.UTF-8",
        "--setenv", "TERM", os.environ.get("TERM", "xterm-256color"),
        "--setenv", "TMPDIR", "/tmp",
        "--setenv", "XDG_RUNTIME_DIR", "/run/user",
        "--dir", "/run/user",
        "--chdir", str(Path.cwd().resolve()),
    ]
    for name, value in toolchain_env(os.environ).items():
        args += ["--setenv", name, value]
    # Git worktrees may put their metadata outside the checkout. Expose only
    # those metadata directories, read-only, rather than the parent checkout.
    for flag in ("--absolute-git-dir", "--git-common-dir"):
        result = subprocess.run([settings["git"], "rev-parse", flag],
                                text=True, capture_output=True, check=True)
        metadata = Path(result.stdout.strip()).resolve()
        args += ["--ro-bind", str(metadata), str(metadata)]
    if (repo / ".git").is_file():
        # A linked worktree's pointer is metadata too. Protect it from being
        # rewritten to expose a different host directory on the next launch.
        args += ["--ro-bind", str(repo / ".git"), str(repo / ".git")]
    # Nix tools may rely on passwd lookup. Supply synthetic identities, not
    # the host account database or host configuration directories.
    for name in ("passwd", "group", "hosts"):
        args += ["--ro-bind", str(state.parent / name), f"/etc/{name}"]
    if android_sdk:
        sdk = Path(android_sdk).expanduser().resolve(strict=True)
        if not (sdk / "emulator/emulator").is_file():
            raise ValueError("--android-sdk must point to an SDK containing emulator/emulator.")
        if not Path("/dev/kvm").exists():
            raise ValueError("Android acceleration requires /dev/kvm and host KVM access.")
        args += [
            "--ro-bind", str(sdk), "/opt/android-sdk",
            "--dev-bind", "/dev/kvm", "/dev/kvm",
            "--setenv", "ANDROID_HOME", "/opt/android-sdk",
            "--setenv", "ANDROID_SDK_ROOT", "/opt/android-sdk",
            "--setenv", "ANDROID_AVD_HOME", "/home/agent/.android/avd",
            "--setenv", "ANDROID_USER_HOME", "/home/agent/.android",
            "--setenv", "LOCAL_CODE_ANDROID", "1",
            "--setenv", "LOCAL_CODE_REPO", str(repo),
            "--setenv", "QT_QPA_PLATFORM", "offscreen",
        ]
    return args


def sandbox(settings, profile, rest, android_sdk=None):
    repo = repo_root(settings)
    key = hashlib.sha256(str(repo).encode()).hexdigest()[:20]
    # State is private to this repository. Never mount normal OpenCode/browser
    # state, SSH keys, cloud credentials, host agents, or an existing AVD.
    state_base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "local-code" / key
    state = state_base / "home"
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    (state_base / "passwd").write_text(f"agent:x:{os.getuid()}:{os.getgid()}:Agent:/home/agent:/bin/sh\n")
    (state_base / "group").write_text(f"agent:x:{os.getgid()}:\n")
    (state_base / "hosts").write_text("127.0.0.1 localhost\n::1 localhost\n")
    port = settings["profiles"][profile]["port"]
    with tempfile.TemporaryDirectory(prefix="local-code-proxy-") as temporary:
        socket_path = Path(temporary) / "model.sock"
        # The only network bridge has a fixed destination: this model server.
        # There is no SOCKS/HTTP CONNECT proxy and no shared host network.
        proxy = subprocess.Popen([
            settings["socat"], f"UNIX-LISTEN:{socket_path},fork,mode=0600",
            f"TCP:127.0.0.1:{port}",
        ])
        try:
            for _ in range(100):
                if socket_path.exists():
                    break
                if proxy.poll() is not None:
                    raise ValueError("Local model bridge failed to start.")
                time.sleep(0.05)
            else:
                raise ValueError("Local model bridge timed out.")
            args = sandbox_args(settings, repo, state, socket_path, android_sdk)
            args += [settings["python"], str(Path(__file__).resolve()), sys.argv[1],
                     "_inside", profile, *rest]
            print(f"Sandbox: {repo} writable; isolated home; no external network.", flush=True)
            with status_record(repo, state) as status_path:
                # Insert the environment option before the sandbox command.
                index = args.index(settings["python"])
                args[index:index] = ["--setenv", "LOCAL_CODE_STATUS_FILE", status_path]
                return subprocess.run(args, check=False).returncode
        finally:
            proxy.terminate()
            proxy.wait(timeout=10)


def inside(settings, profile, rest):
    """Runs inside the network namespace; relay only to the mounted model socket."""
    port = settings["profiles"][profile]["port"]
    relay = subprocess.Popen([
        settings["socat"], f"TCP-LISTEN:{port},bind=127.0.0.1,reuseaddr,fork",
        "UNIX-CONNECT:/run/local-code-model.sock",
    ])
    env = os.environ.copy()
    config = agent_config(profile, settings["profiles"][profile], settings["goalPlugin"])
    config["plugin"].append(settings["statusPlugin"])
    if env.get("LOCAL_CODE_ANDROID") == "1":
        env["LOCAL_CODE_VISION"] = "1" if settings["profiles"][profile].get("vision") else "0"
        config["mcp"] = {"android": {
            "type": "local", "command": [settings["androidTools"]], "enabled": True,
        }}
    env.update({
        "OPENCODE_CONFIG_CONTENT": json.dumps(config),
        "OPENCODE_DISABLE_MODELS_FETCH": "true",
        "OPENCODE_DISABLE_AUTOUPDATE": "true",
        "OPENCODE_DISABLE_LSP_DOWNLOAD": "true",
    })
    try:
        return subprocess.run([settings["opencode"], *rest, "--model", f"local/{profile}"], env=env).returncode
    finally:
        relay.terminate()
        relay.wait(timeout=10)


def on_ac(root=Path("/sys/class/power_supply")):
    """Check external supplies, including USB-C; unknown means battery-safe."""
    for supply in root.glob("*"):
        try:
            if (supply / "type").read_text().strip() not in ("Battery", "UPS"):
                if (supply / "online").read_text().strip() == "1":
                    return True
        except OSError:
            pass
    return False


def select_profile(requested, profiles, ac):
    if requested == "auto":
        return "performance" if "performance" in profiles and ac else "eco"
    if requested not in profiles:
        raise ValueError(f"Profile {requested!r} is not installed on this host.")
    if requested == "performance" and not ac:
        raise ValueError("Performance mode requires AC power. Use local-code eco.")
    return requested


def agent_config(profile, spec, goal_plugin=None):
    model = f"local/{profile}"
    return {
        "$schema": "https://opencode.ai/config.json",
        "enabled_providers": ["local"],
        "model": model,
        "small_model": model,
        "autoupdate": False,
        "share": "disabled",
        **({
            "plugin": [[goal_plugin, {
                "maxTurns": 10,
                "maxDurationMs": 2 * 60 * 60 * 1000,
                "maxTokens": 200000,
                "noProgressTurnsBeforePause": 2,
                "noToolCallTurnsBeforePause": 2,
                "agentGoalAuthority": "status",
                "registerAgents": False,
                "persistState": True,
                "stateFilePath": "/home/agent/.local/state/opencode-goals/state.json",
            }]],
            "command": {"goal": {
                "description": "Work toward a goal with bounded automatic continuation",
                "template": "$ARGUMENTS",
                "agent": "build",
            }},
        } if goal_plugin else {}),
        "provider": {
            "local": {
                "npm": "@ai-sdk/openai-compatible",
                "name": "Local llama.cpp",
                "options": {
                    "baseURL": f"http://127.0.0.1:{spec['port']}/v1",
                    "apiKey": "local",
                    "timeout": 600000,
                },
                "models": {
                    profile: {
                        "name": spec["name"],
                        "tool_call": True,
                        "attachment": spec.get("vision", False),
                        "modalities": {
                            "input": ["text", "image"] if spec.get("vision") else ["text"],
                            "output": ["text"],
                        },
                        "limit": {"context": 32768, "output": 4096},
                    }
                },
            }
        },
        "agent": {
            name: {"model": model, "steps": 50 if profile == "eco" else 100}
            for name in ("build", "plan", "general", "explore", "title", "summary", "compaction")
        },
        "compaction": {"auto": True, "prune": True, "reserved": 8192},
    }


def server_args(profile, spec):
    return [
        spec["server"], "--model", spec["model"], "--alias", profile,
        "--host", "127.0.0.1", "--port", str(spec["port"]),
        "--ctx-size", "32768", "--parallel", "1", "--jinja",
        "--threads", str(spec["threads"]), "--threads-batch", str(spec["threads"]),
        "--poll", "0", "--poll-batch", "0",
        "--batch-size", "512", "--ubatch-size", "128",
        "--cache-ram", "128", "--sleep-idle-seconds", "120",
        "--temp", "0.7", "--top-p", "0.8", "--top-k", "20",
        *spec["extraArgs"],
    ]


def systemctl(settings, *args, **kwargs):
    return subprocess.run([settings["systemctl"], "--user", *args], **kwargs)


def active(settings, profile):
    return systemctl(settings, "is-active", "--quiet", f"local-ai-{profile}.service").returncode == 0


def serve(settings, profile):
    select_profile(profile, settings["profiles"], on_ac())
    if profile == "eco":
        args = server_args(profile, settings["profiles"][profile])
        os.execv(args[0], args)
    child = subprocess.Popen(server_args(profile, settings["profiles"][profile]))
    try:
        while child.poll() is None:
            if profile == "performance" and not on_ac():
                print("AC disconnected: stopping the performance model. Resume with local-code eco --continue.", flush=True)
                subprocess.run([
                    settings["notify"], "Local coding paused on battery",
                    "Resume with local-code eco --continue. The large model has been unloaded.",
                ], check=False)
                return 0
            time.sleep(5)
        return child.returncode
    finally:
        if child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()


def start(settings, profile):
    for other in settings["profiles"]:
        if other != profile and active(settings, other):
            raise ValueError(
                f"The {other} model is running. Finish/pause its sessions, then run "
                "local-code stop before switching models."
            )
    unit = f"local-ai-{profile}.service"
    systemctl(settings, "start", unit, check=True)
    # Ignore HTTP proxy environment variables for the loopback health check.
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        if not active(settings, profile):
            raise ValueError(f"Model failed to start. Inspect: journalctl --user -u {unit} -n 60")
        try:
            with http.open(f"http://127.0.0.1:{settings['profiles'][profile]['port']}/health", timeout=2) as response:
                if response.status == 200:
                    return
        except (urllib.error.URLError, TimeoutError):
            pass
        time.sleep(1)
    raise ValueError(f"Model startup timed out. Inspect: journalctl --user -u {unit} -n 60")


HELP = """Usage: local-code [auto|eco|performance] [OpenCode arguments...]
       local-code [profile] --android [OpenCode arguments...]
       local-code [profile] --android-sdk /path/to/SDK [OpenCode arguments...]
       local-code background 'task description'
       local-code status
       local-code stop

auto selects performance on framework/AC and eco otherwise.
Runs inside a Git repo sandbox: writable repo, private home, no external network.
--android-sdk grants read-only SDK and /dev/kvm access for a headless emulator.
--android uses ANDROID_HOME from your devshell and enables emulator MCP tools.
eco supports screenshots; performance is text-only (UI tree/logs still work).
background starts an eco TUI in a detached tmux session in this directory.
Attach with: tmux attach -t SESSION   Detach with: Ctrl-b d
Models unload after 2 minutes idle. stop releases the server immediately.
"""


def main(settings, args):
    command = args[0] if args else "auto"
    rest = args[1:]
    if command in ("-h", "--help", "help"):
        print(HELP)
        return 0
    if command == "_serve":
        return serve(settings, rest[0])
    if command == "_inside":
        return inside(settings, rest[0], rest[1:])
    if command == "stop":
        return systemctl(settings, "stop", *[
            f"local-ai-{p}.service" for p in settings["profiles"]
        ]).returncode
    if command == "status":
        for profile in settings["profiles"]:
            print(f"{profile}: {'running (possibly idle/unloaded)' if active(settings, profile) else 'stopped'}")
        return 0
    if command == "background":
        if len(rest) != 1:
            raise ValueError("Usage: local-code background 'task description'")
        repo_root(settings)
        start(settings, "eco")
        session = "local-code-" + uuid.uuid4().hex[:8]
        # Quote every argument, including the user's prompt; tmux uses a shell.
        invocation = shlex.join([
            sys.executable, str(Path(__file__).resolve()), sys.argv[1],
            "eco", "--prompt", rest[0],
        ])
        subprocess.run([
            settings["tmux"], "new-session", "-d", "-s", session,
            "-c", os.getcwd(), invocation,
        ], check=True)
        print(f"Started {session}. Attach with: tmux attach -t {session}")
        return 0
    if command not in ("auto", "eco", "performance"):
        # Allow local-code --continue, run ..., etc. to use automatic selection.
        rest = args
        command = "auto"
    profile = select_profile(command, settings["profiles"], on_ac())
    repo_root(settings)
    android_sdk = None
    if "--android" in rest:
        android_sdk = os.environ.get("ANDROID_HOME")
        if not android_sdk:
            raise ValueError("--android requires ANDROID_HOME from a trusted repo devshell.")
        rest = [arg for arg in rest if arg != "--android"]
    if "--android-sdk" in rest:
        index = rest.index("--android-sdk")
        if index + 1 >= len(rest):
            raise ValueError("--android-sdk needs a path.")
        android_sdk = rest[index + 1]
        rest = rest[:index] + rest[index + 2:]
    start(settings, profile)
    print(f"Using {settings['profiles'][profile]['name']} (local).", flush=True)
    return sandbox(settings, profile, rest, android_sdk)


if __name__ == "__main__":
    try:
        with open(sys.argv[1]) as handle:
            settings = json.load(handle)
        sys.exit(main(settings, sys.argv[2:]))
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"local-code: {error}", file=sys.stderr)
        sys.exit(1)
