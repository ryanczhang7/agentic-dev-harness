---
id: HARNESS-045
title: The phase lock sees a git --output write
slug: the-phase-lock-sees-a-git-output-write
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-045-the-phase-lock-sees-a-git-output-write
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/hooks/lib.sh, .claude/tests/phase-guard.test.sh, .claude/tests/lib.test.sh]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

**The settings half of this lead is HARNESS-047** (the user chose option B on 2026-10-08: keep the `git log`/`git diff` allow rules and add deny rules for `--output`). This story is the lock half only and shares no file with it.

Lead 2 of the first `/security-audit` run, `docs/wiki/audits/security-2026-10-08.md`
(fingerprint `settings.json:allow:git-log-diff-output-arbitrary-write`; full
record at `C:\Users\ryanc\security-audit-skill\agentic-dev-harness\run-1\findings.json`
and `NEEDS-VALIDATION.md`). `git log` and `git diff` accept `--output=<file>`
(Git for Windows 2.55 docs: git-log.html:2947, git-diff.html:618; also the
two-word form `--output <file>`), which writes the command's output - with
`--format=<text>`, agent-chosen bytes - to that file. The phase lock's Bash
branch (`phase-guard.sh:152`) asks `write_candidates` (`lib.sh:636`) which
paths a command writes; its tool list (`_WC_AWK` `isname`, `lib.sh:411`) is
`sed tee cp mv rm touch`, plus redirects, and has no rule for `git --output`.
So in RED, `git log -1 --format=x --output=src/main.ts` overwrites frozen
source and the lock allows it with no trace, because the verdict is `-` (not
a write) and `no_candidate` never fires.

**Why this is fixed now rather than validated first.** The audit left the
lead `needs_validation` on the platform question above. The lock half does
not depend on it: `CLAUDE.md` "Phase lock" says the guard "covers
`Write`/`Edit`/`MultiEdit`/`NotebookEdit` and shell redirects alike", and
`lib.sh`'s parser already judges `git mv` by the `mv` rule - the lock's own
stated contract is that a shell command's writes are judged, and a git option
whose whole purpose is to write a file is a write the lock cannot see. That is
a defect in the harness's stated behaviour whichever way the platform
question falls. **No criterion below depends on Claude Code's permission
behaviour**; every one is a `phase-guard.test.sh` or `lib.test.sh` assertion
over `.claude/tests/_lib.sh` fixtures (`make_fixture`, `set_phase`,
`assert_blocked`, `assert_allowed`, `wcand`).

**Type `fix`; not split.** One rule added to one awk program in one file,
with its tests in the two suites that already pin that program. The tree's
own `git log`/`git diff` spellings are the real-line probe `rules.md`
requires of a story that changes a rule (DV-2).
**The gate that fails if this breaks** is the harness's own `selftest`: the
`phase-guard` suite (AC-1 to AC-4 through the hook) and the `lib` suite
(AC-5, `write_candidates` directly). No `required_gates` entry is needed.

One of three stories cut from the audit's three cheap leads; the others are
HARNESS-044 (`task.sh` arguments) and HARNESS-046 (story ids). HARNESS-046
also writes `.claude/hooks/lib.sh` and `.claude/tests/lib.test.sh`, so the
two **conflict** (`plan.sh conflicts`) and run one after the other, never in
parallel worktrees.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC. -->

"The guard" below is `phase-guard.sh` fed a `Bash` PreToolUse input through
`_lib.sh`'s `guard_bash`, over a `make_fixture` fixture; "blocked on `P`"
means `assert_blocked` with path `P`.

- **AC-1 (a `--output` target is judged as a write)** — Given a fixture in
  RED (source frozen), when the guard judges each of
  `git log -1 --format=x --output=src/main.ts`,
  `git log -1 --format=x --output src/main.ts` (two-word form),
  `git diff --output=src/main.ts HEAD`, and
  `git log --output="src/main.ts"` (quoted value), then each is blocked on
  `src/main.ts`. *Reproduction today:* all four are allowed.
- **AC-2 (the target is judged by its category, not refused outright)** —
  Given a fixture in RED, when the guard judges
  `git log -1 --output=docs/notes.md`, then it is allowed (docs are writable
  in RED); and given the same fixture in GREEN, `git log -1
  --output=tests/main.test.ts` is blocked on `tests/main.test.ts` while
  `git log -1 --output=src/main.ts` is allowed. The target goes through the
  same `check_path` as every other candidate.
- **AC-3 (negative controls: read-only git stays read-only)** — Given a
  fixture in RED, when the guard judges each of
  `git log --output-indicator-new=+ -- src/main.ts`,
  `git log --oneline -- src/main.ts`, `git diff -- src/main.ts`,
  `git diff --stat`, `git diff --name-only` (the spelling at
  `scripts/check-boundaries.sh:173`) and `git diff --no-index a b` (the
  spelling at `scripts/mutate.sh:357`), then every one is allowed; and the
  existing assertions `git diff -- src/main.ts` allowed
  (`phase-guard.test.sh:68`) and "a read-only `git diff` logs nothing" /
  `git diff > /dev/null` logs nothing (`:1065-1067`) stay green - a `git`
  command with no `--output` has verdict `-`, so `no_candidate` must not
  start tracing every `git diff`.
- **AC-4 (`git mv` and `git rm` keep their existing rules)** — Given a
  fixture in GREEN, when the guard judges `git mv src/main.ts docs/notes.md`
  and `git mv tests/main.test.ts docs/notes.md`, then the first is blocked on
  `src/main.ts` and the second on `tests/main.test.ts` with the `mv` roles,
  exactly as `phase-guard.test.sh:965-972` already assert; and in RED
  `git rm src/main.ts` is blocked on `src/main.ts`. Teaching the parser the
  word `git` must not stop it reaching the subcommand the existing rules
  already judge.
- **AC-5 (`write_candidates` says what it found)** — Given the masked text
  of `git log -1 --format=x --output=src/x.ts`, when `write_candidates` runs,
  then its verdict line is `W` and it emits exactly one candidate,
  `src/x.ts` with the role `destination of git --output`; given the masked
  text of `git diff -- src/x.ts` or of
  `git log --output-indicator-new=+ src/x.ts`, the verdict is `-` and no
  candidate is emitted. (`lib.test.sh`'s `wcand` renders both as one string
  for an equality assertion.)

Every criterion is **mechanical** (oracle partition, Contract C-5).

## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. -->

**Writes:** `.claude/hooks/lib.sh`, `.claude/tests/phase-guard.test.sh`, `.claude/tests/lib.test.sh`

All three classify as `harness` (`bash scripts/classify.sh` at PLANNED), so
the phase lock freezes none of them; the role boundary is honoured by the
agents: RED writes the two test files only, GREEN writes `lib.sh` only. No
existing export changes signature: `write_candidates <masked command>` keeps
its signature and its output grammar (a verdict line `W`/`-`, then `TARGET`
or `TARGET<TAB>ROLE` lines). There is no caller list.

**RED may amend any block below in place, with a reason; GREEN builds what
the amended block says.**

- **C-1 The rule, in `_WC_AWK` (`lib.sh:410-606`).** `isname(w)` gains
  `w == "git"`. `dispatch` gains, **before** its `WRITE = 1` line,
  `if (name == "git") { do_git(a, b); return }` - `git` is not a write by
  itself, so the verdict is set only when a write is found (AC-3, AC-5).
  `do_git(a, b)`, a new function beside `do_touch`, does two things in order:
  1. **Reach the subcommand the existing rules judge.** For `k` from `a` to
     `b`: if `isname(tok[k])` and `tok[k] != "git"`, call
     `dispatch(tok[k], k + 1, b)` and return. That is what keeps `git mv` on
     the `mv` rule and `git rm` on the `rm` rule (AC-4): today the outer loop
     finds `mv` at the second word; once `git` is a name the loop stops at
     the first word, so `do_git` must hand on. A global option before the
     subcommand (`git -C x mv …`) is walked past by the same loop.
  2. **Find `--output`.** For `k` from `a` to `b`: if `islong(tok[k])` and
     `longname(tok[k]) == "output"` - an **exact** match, not the
     `index(...) == 1` prefix test `do_sed`/`do_mv` use - then `WRITE = 1`
     and the target is `LONGVAL` when `LONGHAS`, else `tok[k + 1]` (and `k`
     advances past it); emit it with `emitr(target, "destination of git
     --output")`. Exact rather than prefix because git's diff options
     include `--output-indicator-new`, `--output-indicator-old` and
     `--output-indicator-context`, none of which writes a file, and git
     refuses any abbreviation shorter than `--output` as ambiguous with them,
     so `--output` spelled in full is the only spelling that writes. There is
     no short `-o` for `git log`/`git diff`; `git format-patch -o` is out of
     scope.
  Quote characters survive masking and are stripped in `END`, so the quoted
  value in AC-1's fourth case needs no special handling. Redirects are
  stripped by `write_candidates` before the awk runs, as today.
- **C-2 Known assertions that must stay green**, read at PLANNED, because a
  parser change is judged by what it stops refusing as much as by what it
  starts: `phase-guard.test.sh:39` (an operator inside a commit message),
  `:68` (`git diff -- src/main.ts` allowed), `:464-474` (four `git commit`
  shapes with the harness vocabulary in the message), `:955` (`git status
  && mv …` blocked), `:965-972` (`git mv` by the mv rule), `:1065-1067`
  (read-only `git diff` logs nothing), and the HARNESS-010 C-6 block at
  `:1166` (what the parser must NOT start refusing). RED's handoff states
  the suite was run and these were green before the new block was added.
- **C-3 Where the tests go.** `phase-guard.test.sh`: one new
  `describe "HARNESS-045 …"` block per AC-1..AC-4, using `make_fixture`,
  `set_phase "$FIX" RED|GREEN`, `assert_blocked "$FIX" '<cmd>' <path>` and
  `assert_allowed`. `lib.test.sh`: AC-5 beside the HARNESS-010 C-4 block
  (`:654-700`), through `wcand` after `mask_shell_quotes`, as equalities on
  the whole rendered answer. No new suite, so `floors.conf` is untouched.
- **C-4 The denial text.** The path line is `path:     src/main.ts` as for
  every candidate; the role line immediately after it is
  `operand:  destination of git --output` (`phase-guard.sh:75-80` prints a
  role when one is carried). The role string is part of AC-5's equality.
- **C-5 Oracle partition.** Every criterion is **mechanical**: exact
  blocked/allowed, exact path, exact verdict and candidate text. Nothing is
  invented or calibrated.
- **C-6 Process budget.** `_WC_AWK` is one awk process per guard call
  (HARNESS-025 cut the guard to that); the new function adds no process.
  `lib.test.sh`'s existing spawn-count assertions, if any cover the guard,
  must stay equal.
- **C-7 Docs.** `CLAUDE.md` "Phase lock" may gain the words "and a `git
  --output` target" to its list of what the guard covers; docs are writable
  in GREEN and this is GREEN's choice, not a criterion.
- **C-8 Test-only dependencies.** None.

## Deferred verifications

<!-- One block per entry; the owning phase pastes the result in. -->

- **DV-1 (defect put back - the story's central claim). Owner: GATES.**
  With `git` removed from `isname` again through `bash scripts/mutate.sh
  .claude/hooks/lib.sh '<sed expression for the exact token GREEN wrote>' --
  bash scripts/selftest.sh phase-guard`, AC-1's four cases and AC-2's GREEN
  case **must** go red and AC-3, AC-4 and every pre-existing assertion must
  stay green (RED predicts the exact red count in its handoff). Then the
  restore is verified and the suite is green again. RED cannot run this:
  there is no rule to remove. Paste the mutate.sh output and the red
  assertion names here, as a fenced block.
- **DV-2 (the rule, probed against real lines of the tree). Owner: GATES.**
  `rules.md`, "A rule is probed against the tree it judges": the fixtures in
  AC-3 are the author's spellings. Take every `git log` and `git diff`
  invocation actually present in `scripts/*.sh`, `.claude/hooks/*.sh` and
  `.claude/commands/*.md` (at PLANNED: `scripts/check-boundaries.sh:173`
  `git diff --name-only …`, `scripts/mutate.sh:357` `git diff --no-index …`,
  and whatever `grep -rnoE 'git (log|diff)[^`"'\'')|;&]*'` over those
  directories lists at GATES), feed each through the guard in a RED fixture
  as written, and then once more with ` --output=src/main.ts` appended.
  Every original **must** be allowed and every appended form **must** be
  blocked on `src/main.ts`. Paste the list and both verdict columns here as
  a fenced block. If any original is refused, that is a false positive the
  fixtures could not see, and the story returns to RED.

## Out of scope

- **`.claude/settings.json` and `.claude/tests/settings.test.sh`** - the settings
  half of the lead, which is HARNESS-047 (see the first line of Context).
- `git format-patch -o/--output-directory`, `git worktree add`, `git
  checkout --`, `git stash`, `git clone`, `git config --file`: every other git
  write surface. The audit deferred "every auto-approved git prefix beyond
  `log`/`diff` for option-based writers" as a coverage unit; a story per
  surface, if one is wanted, after a run that confirms it.
- `--output` on any tool other than git.
- A target outside the repository (`--output=/tmp/x`, `--output=../x`):
  judged exactly as a redirect to that path is today (outside the root is
  outside), no better and no worse.
- Any observation of Claude Code's permission matcher.
- The other two leads: HARNESS-044, HARNESS-046.

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

Planned by `bash scripts/plan.sh write HARNESS-045` from `.claude/harness/models.conf`.
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
