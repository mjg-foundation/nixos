# Local coding

OpenCode is the TUI/agent, llama.cpp serves the models, and tmux keeps background
sessions alive after closing a terminal. Everything is packaged by Nix. The
existing `flake.lock` pins OpenCode, llama.cpp, and bubblewrap; `models.nix` pins immutable
Hugging Face revisions and SHA-256 hashes for the weights. No `ollama pull`,
mutable model tags, npm global installs, or cloud inference account is needed.

| Profile | Hosts | Model | Weight download | Runtime policy |
| --- | --- | --- | --- | --- |
| Eco | Both | Qwen3.5-4B Q4_K_M + F16 vision projector, thinking disabled | 3.41 GB | CPU only, 2 threads, 150% CPU quota, low priority, 8 GiB memory ceiling |
| Performance | framework, AC only | Qwen3-Coder-30B-A3B-Instruct Q4_K_M | 18.56 GB | 6 CPU threads, Vulkan attention/shared layers, CPU MoE experts, 26 GiB memory ceiling |

These are starting settings, not measured tokens/second or battery-life promises.
The small model is suitable for bounded edits, tests, documentation, and triage;
expect more supervision than with hosted frontier models. The larger model has
30B total parameters but activates about 3B per token. Keeping its experts in
system RAM suits the Ryzen's small integrated GPU and avoids putting the entire
model in a GPU allocation. This uses the CPU and Radeon GPU, not the Ryzen NPU.
The chosen llama.cpp packages do not provide a Ryzen NPU backend.

Both profiles have a 32K context, one inference slot, a 4K output limit in
OpenCode, and automatic context compaction. Idle model weights and KV state
unload after 120 seconds and reload on demand. CPU busy polling is disabled.
No model starts at login/boot; there is no periodic agent workload. Eco's CPU
quota is 1.5 logical CPUs in total, not 150% of the whole machine. This limits
inference CPU time, not electrical watts, and does not cap compiler/test
processes launched by the agent. Inference cannot swap, to avoid thrashing.

OpenCode allows up to 90 minutes per eco model request (30 for performance),
including prompt processing and response generation. This is separate from
the goal's continuation budget. Long tool calls may not display completed
arguments until generation finishes; on theseus, long-context eco generation
has measured about 2 tokens/second. A timeout does not necessarily mean a hang.

## Install and use

Rebuild the desired host as usual (`sudo nixos-rebuild switch --flake .#theseus`
or `.#framework`). The first rebuild downloads the weights: about 3.41 GB on
theseus including vision, or 21.97 GB on framework, plus package dependencies. A login session
provides the user systemd manager. If rebuilding inside an existing session,
`systemctl --user daemon-reload` refreshes its units.

From the Git repository you want the agent to work on:

```sh
local-code                         # Sandboxed TUI; auto-select model from host/power
local-code eco                     # Explicit low-power TUI on either host
local-code performance             # framework only, requires external power
local-code eco run "Explain the failing test without editing files"
local-code background "Fix the failing parser test and run the relevant tests"
tmux attach -t local-code-XXXXXXXX  # Use the session name printed above
# Ctrl-b d detaches; the session continues while logged in.
local-code status
local-code logs                    # Print this repository's bridge log directory
local-code logs --follow           # Tail the latest launch; Ctrl-C stops tailing
local-code stop                    # Stop inference and release its RAM immediately
```

Background mode always uses eco and retains the full TUI, so you can attach to
answer questions or permissions and inspect progress. It follows OpenCode's
normal permissions: most repository tools, including editing and shell commands,
are allowed; outside-directory access and detected loops can require interaction.
These application permissions operate inside the OS sandbox described below.
No automatic approval bypass is enabled. Per-project OpenCode permissions remain
configurable. Sessions persist in a private per-repo home under
`~/.local/share/local-code/`. tmux continues after closing a terminal, but does
not guarantee survival across logout and does not run during suspend or reboot. Eco
agent turns are limited to 50 steps (performance: 100). Use `/goal` for automatic
continuation across turns.

Bridge diagnostics (both socat relays and the web helper) are appended to a
private log for each launch under `~/.local/state/local-code/logs/<repo-hash>/`
or `$XDG_STATE_HOME/local-code/logs/<repo-hash>/` when set. The launcher prints
the exact filename before entering the TUI. `local-code logs --follow` follows
the latest launch at the time you invoke it; rerun it after restarting the agent.
Only the current log file is mounted into the sandbox, not the log directory.
Old logs are retained for troubleshooting and can be removed when no longer
needed. Model-server logs remain in `journalctl --user -u local-ai-eco.service`
or `-u local-ai-performance.service`; OpenCode's own session logs remain in its
existing private home under `~/.local/share/local-code/<repo-hash>/home/`.

Waybar's AI tile includes these local sessions alongside Codex, for example
`Codex: 1 working, OpenCode: 1 waiting`. OpenCode permission/question prompts,
idle sessions, and stopped/error turns show as waiting; active work and retries
show as working. Pending prompts take precedence over busy child sessions.
Detached tmux sessions count too. Closed launchers disappear, and missing status
is shown as unknown. Right-click cycles through waiting windows when they can
be mapped unambiguously; attach to tmux manually for detached sessions.
The status plugin writes a small file in the existing private sandbox home;
it gains no extra host/network access. This reports OpenCode's lifecycle, not a
watchdog for a hung inference request. Restart existing `local-code` sessions
after activation to load the plugin.

### Persistent goals

`local-code` includes [opencode-goal-plugin](https://github.com/william-ricchiuti/OpenCode-goal-plugin)
0.10.0. `goal-plugin.nix` pins its npm archive and Zod 4.5.4 dependency with
fixed hashes; the plugin loads from the Nix store without runtime downloads.
In the TUI, start a goal explicitly:

```text
/goal Implement requirements.md. Track each requirement, implement missing work, run the relevant tests, and verify the app in the Android emulator when available. Claim completion only with evidence for every requirement; report concrete blockers and unverified platform behavior honestly.
/goal status
/goal pause
/goal resume
/goal clear
```

Defaults allow 10 automatic continuations, two hours, and 200,000 cumulative
context tokens per budget window. These are plugin checkpoints, not a hard
process timeout: an in-flight turn can exceed a limit, and a final wrap-up turn
may follow. `/goal resume` opens a fresh budget window. Override limits for a
specific goal with, for example, `--max-turns 20 --max-minutes 240`.
Two consecutive stalled or tool-free continuation turns pause the loop. Sending
a normal message also pauses it. Goals persist in the private per-repo home;
resume the same OpenCode session with `local-code --continue`, then use
`/goal resume` if paused. After crash recovery, goals remain paused until resumed.

The plugin uses the existing local build agent, preserves its step limits and
sandbox, and cannot grant extra filesystem, network, or emulator access.
Agent goal authority is restricted so the model cannot replace/edit/clear an
existing goal. Completion requires evidence but remains a model judgment, not
proof that every requirement is met. Permission prompts and real blockers can
still require your input. For background work, attach to the tmux TUI and enter
`/goal`; a regular background prompt alone does not start the goal loop.

Only one profile may be loaded at a time. The launcher refuses to interrupt an
existing different profile: finish or pause its sessions, then `local-code stop`
and start the other profile. Multiple sessions on the same profile share one
inference slot, so requests queue. `stop` affects all sessions using that server.

When AC is disconnected on framework, the performance server stops within
roughly five seconds and sends a desktop notification. An in-flight request
can fail; it is not silently retried against a different model. In the same
project, resume with `local-code eco --continue` (or `--session SESSION_ID`).
Plugging back in does not silently switch an active eco session. Automatic
selection occurs at launch. Unknown power-supply state selects eco.

The launcher restricts inference to its local provider and explicitly sets the
small/helper model and standard agents to the same local model, including on
resume. It disables sharing, model-catalog fetching, automatic application
updates, and automatic LSP downloads. Model HTTP servers bind only `127.0.0.1`,
on ports 8087/8088; no firewall ports are opened. Running plain `opencode` uses
its ordinary config **without this sandbox**; use `local-code` for confinement.

## Sandbox and development tools

Models do not enforce permissions. `local-code` runs OpenCode and its child
commands inside a bubblewrap sandbox, with separate mount, PID, IPC, user, and
network namespaces, no capabilities, and no privilege escalation. It fails
closed if bubblewrap cannot start; there is no unsandboxed fallback.

| Resource | Default access |
| --- | --- |
| Selected Git checkout | Read/write, including deleting its files |
| Git metadata (including linked-worktree metadata) | Read-only: status/diff work, commits and hook/config changes do not |
| Per-repo agent home | Read/write; sessions, build caches, and emulator data persist here |
| Nix store / installed compiler packages | Read-only |
| Real home, other repos, SSH/cloud/browser credentials | Not mounted; host environment is cleared |
| Host processes, D-Bus, SSH agent, Docker/Nix daemon sockets, desktop display | Not exposed |
| Internet, LAN, host localhost services from shell/tools | No direct route/access |
| Public web research | Restricted Exa search/page-fetch MCP bridge; no accounts or cookies |
| Local model | A Unix socket relay to one fixed loopback model port only |
| Devices | Minimal `/dev`; no GPU, KVM, USB, or host ADB by default |

Neither bridge is a general network proxy. They do not expose your signed-in
browser or payment credentials. Giving an OpenCode permission does not grant new
OS-level mounts or network access. Project plugins and MCP tools run under the
same boundary; additional remote MCP servers and network-dependent plugins will
fail. Plain `opencode`, Claude Code, and Codex are not affected by this wrapper.

### Web research

Both local model profiles get `web_search` and `web_fetch` MCP tools backed by
[Exa's hosted MCP service](https://exa.ai/docs/get-started/exa-mcp). No API key,
sign-in, or paid account is configured; keyless access has provider rate limits.
Ask the agent to search official library documentation and fetch relevant pages.
Search queries and requested URLs are sent to Exa. Do not include secrets or
private repository content in them. Web results are untrusted input.

`web-tools.py` is packaged using the flake's pinned Python and CA certificates;
there is no runtime npm install. The hosted service and its search index remain
external and cannot be locked by the flake. An isolated helper with host network
access exposes a private Unix socket, validates only `search(query)` and
`fetch(url)`, and connects to a fixed HTTPS Exa endpoint with redirects disabled.
It has no host home, credentials, cookies, environment proxies, or user-supplied
headers. Requested pages are fetched by Exa, never by this host. Private/local
literal URLs, custom ports, non-HTTP URLs, arbitrary methods and commands are
rejected. Queries, result counts and returned text are bounded.

The agent still cannot use curl, package managers, or arbitrary HTTP clients to
access the Internet. Dependency preparation stays on the host. Built-in OpenCode
web tools are disabled in favor of these MCP tools. `/mcp` shows the `web`
connection; rate-limit and provider failures appear as tool errors. Restart
existing `local-code` sessions after activation to load the new tools.

The model can still damage the writable checkout, including uncommitted files,
and read any secrets already in that checkout. Use a disposable Git worktree
for unattended tasks and review its diff before merging. Mounted files that
were already hard-linked elsewhere share their contents. This is namespace
isolation, not a VM or a guarantee against kernel/runtime vulnerabilities.
Disk consumption and compiler resource use are not hard-capped.

C/C++, Make, Python, Git, and basic file tools are available. To supply other
Nix-packaged toolchains, enter the project's development shell **on the host**
before launching the agent:

```sh
nix develop --command local-code eco
```

The launcher preserves executable PATH entries resolving inside `/nix/store`
(before the fallback tools), plus store-backed `JAVA_HOME`, `ANDROID_NDK_ROOT`,
`ANDROID_NDK_HOME`, `FLUTTER_ROOT`, `DART_SDK`, `GRADLE_HOME`, and `CMAKE_PREFIX_PATH`.
Other environment variables and home directories are not inherited. Prepare language
dependencies in the checkout first if needed. Downloads, host Cargo/Gradle
caches, and Nix daemon access are unavailable inside the sandbox. A `shellHook`
or `nix develop` runs on the host before confinement, so only use trusted flakes.

To grant a headless Android emulator capability explicitly:

```sh
nix develop --command local-code eco --android-sdk "$HOME/Android/Sdk"
# Prefer the repo-pinned SDK exposed as ANDROID_HOME by its devshell:
nix develop --command local-code eco --android
```

This mounts that existing SDK read-only at `/opt/android-sdk` and exposes only
`/dev/kvm`. The host user is added to the `kvm` group (a new login may be needed).
Create a fresh AVD under the sandbox's `ANDROID_AVD_HOME`, using system images
already installed in the SDK. Run the emulator with `-no-window -no-audio
-gpu swiftshader`; SDK tools live under `$ANDROID_HOME`. Java/Gradle and other
build dependencies can come from the dev shell. This does not install an SDK,
download images, expose an existing AVD/account, share host ADB, or enable
network/display/physical-device access. Actual emulator boot remains hardware-
and SDK-dependent. Android builds can also run without this flag when their
SDK is already supplied from a Nix store path by the dev shell, but `/dev/kvm`
requires the explicit capability.

Both Android flags also enable the Nix-packaged `local-android-tools` MCP server
inside the sandbox. It provides six tools: list devices; list/boot an existing
AVD; install/launch/stop an app; tap/swipe/type/send a key; inspect boot status,
UI XML, logs, or screenshots; and shut down an emulator. They use the SDK's ADB
with a fixed namespace-local server and accept only `emulator-NNNN` serials.
There is no physical-device or remote ADB connection option. Input text is
quoted for the device shell and limited to printable ASCII; use app integration
tests for Unicode input. Boot is asynchronous: inspect status before testing.
The helper does not create AVDs; the repo supplies that setup command.

Eco now accepts images through its pinned vision projector. Screenshot tool
results include PNG image content for that model, and the PNG is also saved under
`.local-code-artifacts/android/` in the repo (add this directory to `.gitignore`).
Vision encoding is CPU-bound and limited to 1024 image tokens; use UI XML for
small labels and exact text. The performance model remains text-only: screenshots
are saved but not sent to it as image input. Use XML/logs or stop performance and
resume with `local-code eco --android --continue` for visual inspection. This
avoids loading both models concurrently into a 32 GB host.

The SDK, emulator, system images, Java/Flutter/Rust versions, AVD definition,
offline dependency preparation, and app-specific test commands belong in each
repo's devshell and scripts. No Android Studio, SDK, or system image is installed
by this shared module. Human Android Studio sessions can use the same SDK but
must keep their devices/accounts separate from the agent's AVD.

## Troubleshooting and tuning

Validation on theseus: the full NixOS system builds; both host configurations
evaluate. Live sandbox tests cover a normal checkout, a linked worktree, and an
explicit KVM grant. Repository writes, C compilation, and the fixed model bridge
work while outside files, symlink escapes, Git metadata writes, inherited secrets,
and direct outside networking are blocked. A real eco-model function call succeeded.
An OpenCode read/write task ran through the sandbox, but the 4B model included a
displayed line number in the output: generated changes still need review.
The vision projector passed a real synthetic-image color-recognition test.
OpenCode connected to the Android MCP server inside the sandbox, and actual ADB
startup/shutdown passed in a private network namespace. Helper regression tests
cover argument validation, device restrictions, shell quoting, and image results.
Framework GPU performance and actual Android emulator boot have not been tested.

```sh
journalctl --user -u local-ai-eco -n 80
journalctl --user -u local-ai-performance -n 80
curl http://127.0.0.1:8087/health
python3 -B modules/local-ai/test_local_code.py
python3 -B modules/local-ai/test_android_tools.py
```

The performance profile needs functioning Mesa/RADV Vulkan drivers from the
host's existing graphics configuration. Confirm the server log actually reports
GPU offload on framework. If memory pressure is too high alongside a build or
browser, use eco; the 26 GiB ceiling protects some host memory but does not
reserve RAM for other applications. Tune threads, quotas, context, and GPU
offload only after measuring useful task completion time and power on that host.
A lower instantaneous CPU draw does not necessarily mean less energy per task.

Update application/runtime packages with the existing nixpkgs flake update
workflow. Update model revisions and hashes deliberately in `models.nix`;
old generations keep their weights until garbage-collected. No extra flake
input is needed.

References: [OpenCode local providers](https://opencode.ai/docs/providers/#llamacpp),
[llama.cpp server](https://github.com/ggml-org/llama.cpp/tree/b9925/tools/server),
[Qwen3.5-4B](https://huggingface.co/Qwen/Qwen3.5-4B),
[Qwen3-Coder-30B-A3B](https://huggingface.co/Qwen/Qwen3-Coder-30B-A3B-Instruct),
[bubblewrap security model](https://github.com/containers/bubblewrap#sandbox-security).
