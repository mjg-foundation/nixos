# Working agreements

- Never run a Git command that creates a commit. Leave all changes uncommitted for the user to review and commit manually.
- Before requesting permission to create or edit content on third-party services, including GitHub and Linear pull requests, issues, and comments, present the user with a readable version of the proposed changes.
- If a separate branch is appropriate for a subtask, first check Linear for a matching issue. If none exists, work with the user to create one, and let the user create the branch manually.

# General development guidance

These are personal defaults across projects. Follow explicit user instructions
and the current project's more specific conventions. Use the technical-writing
skill when writing or editing non-trivial code, comments, docstrings, draft
commit messages, or prose/docs.

## Project context

Read the project's architecture documentation before concluding that something
in the codebase is broken. It may record non-obvious facts about target hardware,
memory and zeroization, panics, system services, IPC permissions, or filesystem
guarantees that the surrounding code takes for granted.

## Datasheets

Check the relevant hardware documentation before asserting what a register does.
Find the datasheet, architecture reference, or schematic in the current project's
resources; `pdftotext -layout` makes PDF documentation greppable.

## Git comparisons

Use the project's actual base branch when assessing a branch's changes,
accounting for commits the base may have gained since the fork. Do not assume a
particular branch name, remote credential setup, or commit-rewriting workflow.

## Workflow

When asked to implement anything, follow these steps **in order**, stopping for
confirmation between stages:

1. **Plan** — describe the approach and what will change. Stop and wait for approval.
2. **Code** — implement the changes, then double-check added comments against the
   comment policy below, format with the project toolchain, and run appropriate
   checks. Stop and wait for approval.
3. **Hand off** — leave changes uncommitted for review. When asked for a commit
   message, draft it using the policy below; do not create a commit. Stop and wait
   for approval before any further action.

Never proceed from one step to the next without explicit confirmation.

## Subagent review

When asked for a subagent review, give the agent only the branch name and the
project's review policy to follow, with no other context from the conversation.
If there is no project review policy, provide the agreed review scope instead.
On later reviews of the same branch, also list the findings already rejected,
so it doesn't spend time on them again.

When it reports back, verify each finding yourself and present the survivors
as a numbered list, so they can be answered by number.

## Commit messages

These rules apply to drafting messages, not creating commits.

For any project with issues tracked in Linear, use `SFT-XXXX: description`,
substituting the actual Linear issue identifier if the team uses another prefix.
Do not add a component prefix or repeat the issue ID as a suffix.
Name the affected component naturally in the description when needed to make
the scope clear, e.g. `SFT-3679: don't crash the kernel if IRQ disappears` or
`SFT-5286: allow 7 DMA endpoints as device in usb`.

Use the actual issue ID from the branch name or task context. If it is unknown,
resolve it before finalizing the message; never invent one. A cleanup or refactor
that falls out of the work can carry the same issue ID.

For projects not tracked in Linear, follow the project's required format;
otherwise use `component: description`. The component is the crate or module's
real name (keyboard, server, fs, usb, bt), not an ad-hoc abbreviation; use
`project:` for repo-wide changes.

Keep the entire subject line at most 72 characters, including the issue identifier
or component prefix. After the colon, use imperative mood with a lowercase first
word and no trailing period (fix, add, remove, use, make, implement, simplify,
don't, ...).

Only write a commit body when it is really necessary — i.e. it carries
context a reader couldn't get from the subject and diff, such as the
incident or constraint that motivated the change, a non-obvious
trade-off, or a surprising design choice. Bodies are for *why*, not
*what* — do not summarize the diff in prose unless the change is
large enough that the diff alone is hard to navigate.

## Comments

Only write a comment when it is really necessary. Names carry the *what*,
the code shows the *how*, so a comment should only carry the *why* —
context that can't be read off the names or the code itself. Public function
and type docs are the exception: they document *what* in detail for callers.

Keep comments terse — usually a single line. A comment must carry a reason,
consequence, or precondition; phrase it whichever way reads most directly
(e.g. "Only valid when phys=0", or "Don't allocate blocks just to write
zeroes; they read back as zeroes anyway").

Log and error messages count as comments. When the string next to the code
already names the reason or the failure, a comment restating it is redundant;
the message is what both the reader and whoever reads the logs sees first.

Docstrings and inline comments answer different questions.

A docstring says *what* the function does, plus how to use it when that isn't
obvious from the signature — never how the current code happens to call it.
Don't assert what callers do ("callers fall back to …") or name them ("used
by X"); state requirements as preconditions instead ("callers must …"), and
skip what the signature already conveys (e.g. that a `&mut` borrow prevents
re-entrancy).

An inline comment carries the *why* of the line it sits on: the reason we do
this here, especially why an unrelated-looking call is needed. Reasoning that
only holds at one call site belongs at that call site, not in the callee's
docstring — the callee can't know it, and the next reader deletes the call,
not the function.

Don't reference a file's history or a prior implementation ("used to be",
"was X", "now Y", "previously"). The reader doesn't know the history, so the
contrast with a past state adds nothing — state the current fact directly, and
pick a representative example over an incidental one: "page tables are now
cacheable" → "page tables are cacheable"; "the framebuffer unmap was ~48k L2
writes" → "a 2MB buffer would be ~64k L2 writes".

Match the surrounding comment density. Don't add a lone comment to one item when
its siblings are bare, whether those are match arms, struct fields, constants,
functions, methods or statements. The exception is information that can't be
reached from the surrounding code, such as an external constraint the siblings
don't share; that earns a comment even when its neighbours have none.

Use only ASCII in comments — no Unicode arrows, symbols, or punctuation.

## Design

Few states, straightforward transitions. Complex behaviour should emerge from
simple rules interacting, not be spelled out as cases.

A corner case that needs several unlikely things to coincide does not need
handling correctly, only not catastrophically: a stray log line or a redundant
reset is fine, a stuck state or a lost security property is not.

What gets judged is the end result, not the diff. Once a fix or addition is in,
re-read the code around it as if it were new: a patch on a workaround on a patch
should collapse into whatever the plain version is now.

## Code style

Prefer the descriptive name to the short one. A name is read far more often than
it is typed, so an abbreviation only ever saves the author: spell out identifiers,
opcodes, messages and fields (`RegisterOnDemandLauncher`, not `RegisterLauncher`;
`is_on_demand_built_in`, not `is_odb`). Shorten only where the short form is the
domain's own name for the thing (`sid`, `cid`, `pid`, `psbt`, `usb`).

Declare a `const` or `static` used by one function inside that function, and one
used by several at the top of the file. Never leave them loose between functions
in the middle of a file.
In binary-only crates, prefer `pub` to `pub(crate)` when exposing items across
modules. In libraries, use `pub(crate)` when access should remain within the crate.
Every new `unsafe` block needs a `// SAFETY:` comment justifying why the safe
alternative is infeasible and why the block upholds the invariants it relies on
(layout, lifetimes, aliasing, bounds). GUI application code should generally
not need `unsafe`; keep low-level operations behind safe interfaces.

## Formatting

Use the project's pinned formatter and toolchain. In Rust projects, check
`rust-toolchain.toml` and `rustfmt.toml`; if formatting uses nightly-only options,
run the pinned nightly, e.g. `cargo +<that-nightly> fmt`.

Nested workspaces can pin a different channel. A plain `cargo fmt` in a stable
workspace can silently reformat files differently from the intended nightly
configuration. Check the workspace and toolchain before formatting.

## Localization

Do not manually edit generated translation catalogs or invent translation IDs.
Follow the project's localization workflow for adding source strings and
regenerating catalogs. When localization is deferred, a raw user-facing string
may be used with a `// TODO: localize` comment immediately above it (or the
equivalent comment syntax for the language). Follow any more specific project
rules about whether and where deferred localization is allowed.

## Checking

Take commands from the project's CI configuration and task runner, such as its
`Justfile`, instead of inventing flags. Check the affected crates or components
first, taking target and feature flags from the matching recipe. Run broader
checks when required by the project or justified by the change.

Do not infer device-target correctness from a host-only check. Use the project's
custom-target toolchain or build environment where required. Run integration
tests through the project's service harness when they depend on other services.

## Building and flashing

Distinguish a successful build from a flashable image. Firmware may require a
separate packaging step combining the bootloader, recovery, and normal images.
Use the project's documented commands and prerequisites for the required output.

For an authorized firmware update, prefer the smallest documented write that
achieves the requested change. Do not replace a bootloader or device-specific
configuration without establishing that the requested update requires it.
Discover image paths, device state, and tooling in the current environment;
do not assume another developer's setup or credentials.
