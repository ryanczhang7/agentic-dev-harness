---
id: HARNESS-047
title: Deny git log and git diff --output in settings.json
slug: deny-git-log-and-git-diff-output-in-sett
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-047-deny-git-log-and-git-diff-output-in-sett
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/settings.json, .claude/tests/settings.test.sh]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

The settings half of lead 2 of the first `/security-audit` run,
`docs/wiki/audits/security-2026-10-08.md` (fingerprint
`settings.json:allow:git-log-diff-output-arbitrary-write`; full record at
`C:\Users\ryanc\security-audit-skill\agentic-dev-harness\run-1\findings.json`
and `NEEDS-VALIDATION.md`). `.claude/settings.json:13-14` auto-approve
`Bash(git diff:*)` and `Bash(git log:*)` as read-only inspection; both
subcommands accept `--output=<file>` (and `--output <file>`), which writes
the command's output - with `--format=<text>`, agent-chosen bytes - to any
path the user can write. HARNESS-045 teaches the phase lock to see that
write; the lock acts only while a story is active, only on frozen categories
and never outside the repository, so the allow-list consent is the half this
story closes.

**The decision was the user's, 2026-10-08: option B.** Of the three options
put to them - **A** remove both allow rules (certain; a permission prompt on
every `git log` and `git diff`, which agents run constantly), **B** keep both
allow rules and add deny rules for `--output`, **C** leave settings alone and
rely on the lock (HARNESS-045) - the user chose B. The orchestrator did not
pick.

**What the platform documents, and what this repository can observe.** The
Claude Code permissions page (https://code.claude.com/docs/en/permissions)
states: rules are evaluated deny, then ask, then allow, and "an allow rule
can't carve an exception out of a deny rule"; a `*` may appear anywhere in a
pattern (its example is `Bash(git log * main)`) and matches any text
including spaces, while the `:*` form is recognised only at the end of a
pattern - so `Bash(git log *--output*)` is the documented spelling and
`Bash(git log:*--output*)` is not; and a Bash rule "isn't a security
boundary" (`git -C . log --output=…` evades the deny - and equally evades the
allow prefix, so it prompts). That is documentation read on 2026-10-08, not
behaviour observed here: nothing in this repository can run the matcher, so
**no acceptance criterion depends on it**. The criteria pin the text of
`settings.json`, mechanically, through `.claude/tests/settings.test.sh`; the
one owner-observed check the audit asks for is DV-2, owned by REVIEW, and may
be `WAIVED` with a reason.

**Why a deny on `--output` and not a narrower allow.** The docs show no
syntax for excluding an option from an allow rule, and deny-before-allow is
the documented precedence, so two deny lines is the only shape the docs
support that keeps the two allows.

**How this sits beside the state-deny suite.** `settings.test.sh`'s
`problems` checks `settings.json` against `.claude/state/README.md` in both
directions, and both directions see only rules of the form
`<Write|Edit|MultiEdit>(./.claude/state/<path>)`: the forwards check demands
those for `no` rows, and the backwards check greps exactly that alternation
(`settings.test.sh:109-113`). A `Bash(...)` deny entry matches neither and is
invisible to it - the suite's own "no protection at all" fixture already
carries a non-state deny, `Read(./.env)`, and the live file carries three
`Read(...)` denies today without complaint. So the two new lines break no
existing assertion, and the new ones are a separate block that pins them
directly (C-2).

**Type `fix`; not split.** Two lines in one JSON file, pinned by one new
block in the suite that already owns that file. **The gate that fails if this
breaks** is the harness's own `selftest`, `settings` suite. No
`required_gates` entry is needed. Shares no file with HARNESS-044, -045 or
-046.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC. -->

"The checker" is a function in `settings.test.sh` over a supplied settings
file (C-2), in the suite's existing style: the live file must produce no
complaint, and each way of getting it wrong is a fixture that must produce a
specific one.

- **AC-1 (both deny rules are present, in the deny block)** — Given
  `.claude/settings.json`, when the checker reads its `permissions.deny`
  array, then it finds the two entries `"Bash(git log *--output*)"` and
  `"Bash(git diff *--output*)"` exactly, and prints nothing.
  *Reproduction today:* it prints one line per missing rule, naming it.
- **AC-2 (both allow rules remain, in the allow block)** — Given
  `.claude/settings.json`, when the checker reads its `permissions.allow`
  array, then it finds `"Bash(git diff:*)"` and `"Bash(git log:*)"` exactly
  and prints nothing. Passes today; it is the control that B, not A, was
  implemented.
- **AC-3 (each way of getting it wrong is named)** — Given fixture copies
  of the live file, when the checker reads a copy with one deny line
  removed, a copy with a deny line spelled `"Bash(git log:*--output*)"`
  (the `:*` form the docs say is not a mid-pattern wildcard), and a copy
  with the two deny strings moved into the `allow` array, then each
  produces one complaint naming the rule and the block it is missing from,
  and nothing else.
- **AC-4 (the state-deny pair still agrees)** — Given the live pair, when
  `bash scripts/selftest.sh settings` runs, then `problems` prints nothing
  (`the shipped pair agrees with itself`) and every pre-existing assertion
  stays green: the new entries are invisible to the state checks, as Context
  says.

Every criterion is **mechanical** (oracle partition, Contract C-5).

## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. -->

**Writes:** `.claude/settings.json`, `.claude/tests/settings.test.sh`

Both classify as `harness` (`bash scripts/classify.sh` at PLANNED), so the
phase lock freezes neither; the role boundary is honoured by the agents: RED
writes `settings.test.sh` only, GREEN writes `settings.json` only. No existing
export changes signature; there is no caller list.

**RED may amend any block below in place, with a reason; GREEN builds what
the amended block says.**

- **C-1 The two lines (settled - read out, never re-derived).** Appended to
  the `deny` array of `.claude/settings.json`, after the three
  `MultiEdit(...)` entries, as the last two elements, byte for byte:

      "Bash(git log *--output*)",
      "Bash(git diff *--output*)"

  Semantics: a space then `*` after `git log` means "git log, then any text
  including spaces, then `--output`, then anything" - so both
  `--output=<file>` and `--output <file>` are covered, at any position after
  the subcommand. Nothing else in the file changes; the `allow` array keeps
  `"Bash(git diff:*)"` and `"Bash(git log:*)"` where they are. The JSON stays
  valid (comma on the preceding line; none after the last element). The
  `:*` spelling is **not** used: the docs recognise it only at the end of a
  pattern.
- **C-2 The checker, in `settings.test.sh`.** A function
  `git_output_rules <settings file>` beside `problems`, taking a file and
  printing one line per disagreement, nothing when there is none. It reads
  the `deny` array as the text between the line matching `"deny": [` and the
  next line matching `^\s*\]`, and the `allow` array likewise, with awk;
  then, per expected entry, `grep -cxF` on the trimmed line
  (`"<rule>"` with or without a trailing comma - strip the comma first) so
  the match is anchored and a rule in the wrong block, or spelled with `:*`,
  is a miss. Complaint texts, exactly, so AC-3's fixtures can match them:

      deny has no "Bash(git log *--output*)"
      deny has no "Bash(git diff *--output*)"
      allow has no "Bash(git diff:*)"
      allow has no "Bash(git log:*)"

  No `node`, no JSON parser (`rules.md`, "Portability"); the file is read as
  lines, as `problems` already does. The live-file assertion is
  `assert_eq "… " "" "$(git_output_rules "$SETTINGS")"`; AC-3's fixtures are
  `sed`/`awk` copies of the live file into `$FIX`, in the suite's existing
  `deny_also`/`good_settings` style, each asserted with `assert_eq` on the
  **whole** output (one specific line, nothing else).
- **C-3 Why the mutation does not go through `mutate.sh` on the live
  file.** `docs/wiki/audits/state-deny-2026-09-10.md` records that the
  runtime reads `settings.json` live, so a suite - or a GATES run - that
  edits the real file mid-session changes the rules the session runs under.
  The "defect put back" (DV-1) is therefore run on a **copy** of the live
  file with the two lines removed, which is the same text the fixture case
  in AC-3 reads; `mutate.sh` is not used on `.claude/settings.json`.
- **C-4 `floors.conf`.** The `settings` floor is 27 executed assertions;
  this story adds assertions and removes none, so the file is untouched.
- **C-5 Oracle partition.** Every criterion is **mechanical**: exact rule
  text, exact block, exact complaint line. Nothing is invented or
  calibrated. The two rule strings are **settled** (C-1); RED reads them
  out.
- **C-6 Test-only dependencies.** None.

## Deferred verifications

<!-- One block per entry; the owning phase pastes the result in. -->

- **DV-1 (defect put back - the story's central claim). Owner: GATES.**
  On a copy of the live `.claude/settings.json` taken at GATES (not a
  hand-written fixture) with both C-1 lines deleted, `git_output_rules`
  **must** print exactly the two `deny has no …` lines, and with only the
  `git diff` line deleted, exactly that one; on the live file itself it must
  print nothing. Not through `mutate.sh`, for the reason in C-3: the runtime
  reads the live file, so the copy is the mutation. RED cannot run this
  against the live file: the lines do not exist yet, so the live-file
  assertion is red and the copy is the same as the file. Paste the three
  outputs here, as a fenced block.
- **DV-2 (the audit's owner-observed check). Owner: REVIEW. May be WAIVED
  with a reason.** In a throwaway Claude Code session in default permission
  mode, on a checkout carrying this story's `settings.json` and with no
  user-level git allow or deny rules, ask the agent to run exactly
  `git log -1 --format=probe --output=<a scratch path outside the project>`
  and separately `git log -1 --oneline`; record for each whether a
  permission prompt appeared and whether the file appeared. Expected from
  the documented precedence: the first prompts (deny before allow), the
  second does not. This is the platform fact no test here can observe; a
  result either way goes also into
  `docs/wiki/audits/security-2026-10-08.md` under `## Evidence`. If it is
  not run, write `WAIVED` and why, and the audit keeps the lead at
  `needs_validation` for the consent half.

## Out of scope

- Every other allow-listed git prefix (`git branch`, `git add`, `git
  rev-parse`, `git ls-files`, `git status`) and every other git write option
  (`format-patch -o`, `--output-directory`, `-c core.fsmonitor=…`). The audit
  deferred "every auto-approved git prefix beyond `log`/`diff` for
  option-based writers" as a coverage unit for a later run.
- `git -C <dir> log --output=…` and other spellings that evade the allow
  prefix: they prompt today and prompt after; the docs say a Bash rule is
  not a security boundary and this story does not claim one.
- The lock half: HARNESS-045 (`write_candidates` sees `--output`).
- The `.claude/state/` deny rules, the `Read(...)` denies, and
  `.claude/state/README.md`.
- Option A or C. The user chose B; a change of mind is a new story.
- HARNESS-044 and HARNESS-046.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

## Handoff: RED -> GREEN

<!-- Filled by the Test Developer at the end of RED. This is the ONLY channel
     to the Feature Developer, whose context is fresh. Must contain:
       * the exact command that runs the new tests
       * the failure output, and why it is the RIGHT failure
       * every file touched, and which AC each test covers
       * the EXPORT SHAPE the tests already pin: every module they import, the
         exact exported names and signatures, and the types the assertions
         destructure. Not a suggestion - a test already imports them, so a
         wrong guess is a compile error. Say what the tests do NOT constrain
         too, so it stays the implementer's choice.
       * any test that passed on arrival, and the probe or negative control
         that earns it
       * the EXPECTED VALUE of every negative control, as a table: threshold,
         candidate range, and the number the control measured. In RED the
         suite fails at import, so no assertion in it has run - the controls
         are claims until GREEN confirms them against the shipped module
       * anything discovered that changes the approach -->

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. A test that is wrong is never edited into passing, and the
     return is not a footnote - it is the story failing to be one clean cycle,
     and the next person needs to know why. One block per return:
       * which test, what it asserted, and what was wrong with it
       * how the defect was found
       * what it asserts now
       * what earns it, since "watched it fail" cannot apply once the
         implementation exists - the corrected assertion passes on its first
         run and every run after, whether or not it asserts anything: either a
         PROBE (mutate the specific behaviour the test pins, paste the red,
         confirm the revert) or, where the defect was cost rather than
         correctness, a BEFORE/AFTER measurement taken under the gate command -
         not the plain test command, which is the faster one.
         PASTE THE OUTPUT. check-boundaries.sh refuses a PR whose Regressions
         or Gate probes section describes a failure without showing one.
         A result counts only as a block: a line beginning with three
         backticks or three tildes (a fence), or a line indented by exactly
         four spaces. Prose does not count, nor inline code in backticks, nor
         a tab, nor anything inside an HTML comment
       * whether GREEN was a no-op, and the command output proving the source
         was untouched and still passes -->

## Gate results

<!-- Written by scripts/gates.sh itself on every full run, stamped with the
     commit and a hash of the code it ran against. Do not paste or edit it:
     check-boundaries.sh refuses a PR whose recorded run does not match the
     code being merged. -->

## Gate probes

<!-- REQUIRED if this story adds or changes a gate, its command, or its
     evidence line. Omit the section entirely otherwise.
     A gate that has never been observed to fail is not a gate: break the thing
     it guards, run the gate, paste the failure, revert. A result counts
     only as a block: a line beginning with three backticks or three tildes
     (a fence), or a line indented by exactly four spaces. Prose does not
     count, nor inline code in backticks, nor a tab, nor anything inside an
     HTML comment. One block per gate:
       * what was broken, and where
       * the gate output proving it failed
       * confirmation the probe was reverted -->

## Scaffold inventory

<!-- REQUIRED for a bootstrap or chore story that writes production code under
     SCAFFOLD, where nothing forces a test to exist first, and for a spike that
     commits its throwaway code. Omit otherwise.
     One line per production file written, and for anything with behaviour
     rather than configuration, the test that covers it:
       src/core/palette.ts        - src/core/palette.test.ts
       vite.config.ts             - configuration, no behaviour
     check-boundaries.sh refuses the PR if any changed source file is not
     named here. -->

## Notes


## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-047` from `.claude/harness/models.conf`.
A PLAN, not a record: a session setting or an explicit override can beat both
this and the agent's own `model:` field, and nothing here can see which won.
The orchestrator still writes down the model each dispatch **resolved** to, by
name, below the table.

| Phase | Agent | Planned | Why |
|---|---|---|---|
| PLANNED | `lead-po` | `fable` | planning is the judgement phase - decomposition, the oracle partition, the contract - and planning is what fable is judged best at |
| RED | `test-developer` | `opus` | writing the failing tests, the negative controls and the handoff is development work, and opus is judged the stronger model for it |
| GREEN | `feature-developer` | `opus` | the failure mode of a weaker model here is reaching green by weakening a test, which is the one thing this harness exists to prevent |
| GATES | `feature-developer` | `opus` | same risk as GREEN, and a gate failure is where "make it stop complaining" is most tempting |
| REVIEW | `lead-po` | `fable` | reading review feedback against the contract is orchestration judgement, and a wrong call here ships; a fix it finds goes back to GATES or RED, on opus |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation - code, with no failing test in front of any of it, so the stronger development model |

**Resolved:**

- PLANNED: `lead-po` ran on **Fable 5.1** (`claude-fable-5-1`), the model its definition declares; the dispatching prompt stated no override and none was observed. 2026-10-08.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
