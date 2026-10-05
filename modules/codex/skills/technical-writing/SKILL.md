---
name: technical-writing
description: Apply a terse technical writing style when writing or editing non-trivial code (anything beyond a throwaway utility script), which carries its comments and docstrings, or when composing commit messages or prose/docs. Use before adding real features, modules, or types, and before writing a comment or commit message. Voice is terse, dry, technically exact, and explains the reason/failure mode rather than restating the code.
---

# Technical writing style

Apply this voice when writing comments, docstrings, commit messages, or prose.
Follow explicit user instructions and the project's conventions where they differ.
The rules below are self-contained; the accompanying personal AGENTS.md supplies
broader development preferences. Commit guidance is for drafting text, not
authorization to create commits.

## Voice in one line
Terse, dry, technically exact. A comment gives the *reason* or the *failure mode* -
the thing that bites you if you ignore it - never a retelling of the code.

## The single most important habit: be short
The supplied style guide reports these corpus measurements: **median 13 words, ~60% are a single line**, p90 is
31 words. Default to one line. Earn every extra line. If a comment only re-walks the
steps the code already takes, delete it - that is the most common mistake. Multi-line
is fine for a genuinely subtle caveat (the corpus runs up to ~90 words), but keep each
half tight and never expand just to sound thorough. Treat the reported numbers
as stylistic calibration, not quotas or measurements of the current project.

## The signature move: state the reason causally
Most comments are "<decision/fact>, because/or else/otherwise <consequence>." This
one construction is the backbone of the voice. Keep both halves tight.
- "Directly queue the response to the message, because we are servicing it right now."
- "There appears to be a minimum wait time, or else we hammer the peripherals too fast and they get confused."
- "Don't allocate blocks just to write zeroes. Unallocated ones will read back as zeroes anyway."
- "Opt out of the borrow checker, because we know these are two different mappings."
Use the same shape to justify every `unsafe` / hack: "Transmuting to static because we
know we are not dropping this memory." Explain the actual safety invariants;
a stylistic example is not a complete safety argument for a different operation.

But it's seasoning, not a template: first decide the comment earns its line, *then*
maybe shape it causally. Don't stamp "X, or else Y" onto every comment. A comment that
restates a well-named callee or a constant's own doc is noise - delete it.

## Mechanics
- **"we"/"this" for the code's behaviour**, plain present tense. First-person "I" is
  rare in code comments (save it for prose). "We preallocate a big enough buffer."
- **State preconditions, not callers.** "Should only be called when the RTC is stopped
  (ACKUPD is true)", "Can only be called after calling build()", "Only applicable when phys=0".
  Describe the code's behaviour, not the caller: "Blocks until the reset completes", not
  "blocks the caller until the reset completes".
- **Be concrete, with a short parenthetical gloss.** Real numbers, hex, register names,
  spec refs: "MCK: 164MHz Clock frequency is divided by 2 because of the default
  `h32mxdiv` PMC setting", "(in the vertical blanking interval)".
- **Doc comments:** one imperative summary line, details only if needed; Rust doc
  sections (`# Errors`) when listing errors. Many doc comments are a single line.
- **Full sentences in real block comments**, capitalized, periods. Terse labels and
  field docs can be fragments.
- **Avoid the long dash.** Em-dashes, and their ` -- ` / spaced-hyphen stand-ins,
  read as grammatically lazy; a comma, colon, semicolon, parenthesis, or full stop
  is almost always sharper. Reach for one practically never.

## Seasoning - rare on purpose
These give the voice its character, but the supplied guide reports them in only
~1-2% of comments.
Reach for them seldom; overusing them is the giveaway of an imitation.
- **Honesty markers:** `TODO:` / `XXX:` (~2-3% each) for real debt; when you punt, say
  why and what the proper fix is ("it would be a waste of time to implement a generic
  solution for this one case. Once we have more than one, a proper solution should be
  implemented."). Hedges like "(probably)" only to mark a genuine unknown (~1.5%).
- **Deadpan humor**, woven into an otherwise factual line, not as a separate joke:
  "or else ... they get confused", "Nice big chunk of well-aligned memory for optimal
  writing experience", "Make sure not to remove the soldered-on flash chip at runtime".
  A literal ":)" is almost never used (<0.1%) - basically don't.

## Prose (docs, longer writing) - looser than comments
First person here, casual connectives ("Well,", "Anyway,", "So", "BTW"), the odd
one-line paragraph for effect ("Ugh.", "Phew."). Build the mental model before the
details; analogies welcome ("pop the hood"). Self-deprecating about dead ends, but
always land on the concrete fact. Loose tone, exact specifics.

## Commit messages
For any project with issues tracked in Linear, use `SFT-XXXX: description`,
substituting the actual Linear issue identifier if the team uses another prefix.
Do not add a component prefix or repeat the issue ID as a suffix. Use a known
issue ID from the branch or task context; resolve it before finalizing the
message if unknown, never invent it.

For projects not tracked in Linear, follow the project's required format;
otherwise use `component: description`. Keep the entire subject <= 72 chars,
including the issue identifier or component prefix; write a body only when
necessary. The corpus figures below come from the supplied guide and describe
the style.

**Subject** - the norm, ~53 chars median:
- For Linear-tracked work: `SFT-XXXX: lowercase imperative description`.
  Name the affected component naturally in the description when needed to make
  the scope clear.
- Otherwise, when using the component format, use a short lowercase
  subsystem/crate/module name (kernel, server, fs, usb, security, crypto, ...);
  use `project:` for repo-wide changes. Use the crate/module's real name, not an
  ad-hoc abbreviation (keyboard, not kbd; api-server, not api). Established short
  names are fine (bt, fs, usb).
- Imperative present tense, **first word after the colon lowercase**, no trailing
  period. The common verbs are fix, add, remove, use, make, implement, simplify,
  update, don't, optimize, allow, move, split, set, disable, refactor, rename,
  replace, bump. Examples with illustrative issue identifiers:
  - "SFT-3679: don't crash the kernel if IRQ disappears"
  - "SFT-5286: allow 7 DMA endpoints as device in usb"
  - "SFT-4520: make logging mostly non-blocking"

**Body** - the exception, present in only ~11% of commits, median ~2 lines:
- Write one only when the subject plus the diff don't convey the *why*. Skip it for
  routine changes; don't summarize the diff in prose.
- Content is the reason: the bug's root cause, the constraint, the trade-off, the
  alternative you rejected, or evidence it works. State the problem, then the fix
  rationale ("This races with our IRQ handler and wins. In this case let's just return
  instead of crashing.").
- Voice is looser than comments: causal and dry, first person "I"/"we"/"let's" fine,
  honest hedges ("probably", "(at least compared to ...)"). Call out confusing external
  facts ("The datasheet is very confusing about this").
- For a gnarly bug, lay out a timeline or numbered steps, and list the options
  considered with the chosen one marked "(implemented)".
- Add a short evidence line when it reflects verification actually performed ("Tested Channel 7 and DMA on it worked.",
  "There was no noticeable slowdown for loading."). Note surprising side effects in
  parens. Wrap at ~72 columns.
- Deadpan humor shows up here a bit more than in comments ("Not great, not terrible"),
  but it's still seasoning, not the point.

## Don't
- Don't restate the code, and don't narrate steps ("Read it out, then advance head, then...").
- In code comments, don't reference history ("used to be", "now", "previously");
  state the current fact. Commit messages may describe the change and its cause.
- Don't name callers or assert what they do; state requirements instead.
- Don't pad with empty hedging; hedge only to flag a real unknown.
- Don't sprinkle jokes or smileys to force the voice - terseness and the causal "because" carry it.
- ASCII only in comments.

## When in doubt
Cut the comment. If what's left can't earn its line by naming a reason, consequence,
or precondition, it shouldn't be there.
