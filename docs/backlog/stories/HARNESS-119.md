---
id: HARNESS-119
title: A consumer's own suites stay out of the pinned real-suite lists
slug: consumer-suites-stay-out-of-pinned-lists
epic: 
type: fix
status: done
phase: DONE
branch: story/HARNESS-119-consumer-suites-stay-out-of-pinned-lists
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/selftest-needed.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the selftest-needed suite under its selftest floor, which CI runs in full on the PR
---

## Context

Field report, fantasy-world-builder PR #130 (the 130 -> 136 refresh), CI
run 44693179916, `boundaries` job: `selftest-needed: 1012 passed, 18
failed`. All 18 are three HARNESS-115 cases, each failing six ways (root and
subdir, three assertions):

- `AC-1: VERSION, floors.conf, selftest.test.sh and shipped-docs.test.sh changed over the real suites print the seven suites that read or scan them`
- `AC-2: VERSION and floors.conf changed over the real suites print doctor, lib, selftest and worktree`
- `AC-5: a copy of the real doctor.test.sh declaring VERSION is still printed when VERSION changes`

The log shows why: the printed list also holds `project-handoff` and
`project-harness-deps`, the consumer's own suites, which name
`.claude/harness/VERSION` and `.claude/tests/floors.conf`.

`h115_real` in `.claude/tests/selftest-needed.test.sh` builds "the real
suites" with `cp "$REPO_ROOT"/.claude/tests/*.test.sh`, and `H115_M`, the
total in the pinned header, counts the same glob. Upstream ships no
`project-*.test.sh`, so upstream is green. A consumer keeps its own
`project-*.test.sh` across every refresh (`refresh-harness.sh` never
overwrites them, and `floors.conf`'s header names that convention), so in
any consumer whose suites mention one of those paths these pins fail. They
pin the shipped suites' selection, and the consumer's suites are not part of
what they claim.

**Reproduced upstream, PLANNED, 2026-11-20, release 136 (`4bb0f54`),
worktree `D:\adh-HARNESS-119`.** An untracked
`.claude/tests/project-probe.test.sh` whose comments name both paths, then
`bash scripts/selftest.sh selftest-needed`, then the probe removed:

    exit 1
          6     FAIL AC-1: VERSION, floors.conf, selftest.test.sh and shipped-docs.test.sh changed over the real suites print the seven suites that read or scan them
          6     FAIL AC-2: VERSION and floors.conf changed over the real suites print doctor, lib, selftest and worktree
          6     FAIL AC-5: a copy of the real doctor.test.sh declaring VERSION is still printed when VERSION changes
          6     FAIL AC-5: a copy of the real selftest.test.sh declaring floors.conf is still printed when floors.conf changes
    selftest-needed: 952 passed, 24 failed

(24, not 18: the probe names `floors.conf` as well, so the second AC-5 case
fails too.)

## Acceptance criteria

- **AC-1 (reproduces the report)** - Given the real tree plus a
  `.claude/tests/project-*.test.sh` whose source names
  `.claude/harness/VERSION` and `.claude/tests/floors.conf`, when
  `bash scripts/selftest.sh selftest-needed` runs, then it passes with 0
  failed. *(Today: 24 failed, above.)*
- **AC-2 (control: upstream unchanged)** - Given the real tree with no
  `project-*.test.sh`, the suite passes with its assertion count unchanged
  (976 executed at release 136), and every pinned list and header is the
  same text as before.

## Contract

**Writes:** `.claude/tests/selftest-needed.test.sh`, `.claude/harness/VERSION`

**C-1.** In `selftest-needed.test.sh`, `H115_M`'s count and `h115_real`'s
copy both skip files whose name starts `project-`. Nothing else in the
HARNESS-115 block changes: the pinned lists, headers and reasons are
already the shipped suites' answer. Both are harness paths, writable in
every phase; the test file is written in RED (the change is to a test),
`VERSION` (137) in GREEN.

**C-2.** No other suite is in scope. A grep for the same shape
(`cp "$REPO_ROOT"/.claude/tests/*.test.sh`, or a count over that glob) at
PLANNED finds only these two lines.

**Overlap.** HARNESS-117, in flight, also writes
`selftest-needed.test.sh`; its diff appends after line 1470 and does not
touch lines 1131-1183. No textual conflict expected; whichever merges
second re-runs the suite.

## Deferred verifications

- **DV-1, the defect put back (AC-1).** With the probe of the Context
  present and `h115_real`'s exclusion mutated back to the plain copy, the
  suite **must** go red on the HARNESS-115 cases. Run with
  `bash scripts/mutate.sh .claude/tests/selftest-needed.test.sh 'EXPR' --
  bash scripts/selftest.sh selftest-needed`. **Owner: GATES.**

  **DV-1 result (GATES, 2026-11-20, run by the orchestrator): PASSED.**
  With the probe `.claude/tests/project-probe.test.sh` (naming VERSION and
  floors.conf) present and the copy put back, the suite went red on the
  same 24 HARNESS-115 assertions as the Context's reproduction; restored and
  verified; probe removed.

    bash scripts/mutate.sh .claude/tests/selftest-needed.test.sh 's/^    case "\${f##\*\/}" in project-\*) ;; \*) cp "\$f" "\$d\/.claude\/tests\/" ;; esac$/    cp "$f" "$d\/.claude\/tests\/"/' -- bash scripts/selftest.sh selftest-needed
      1192 -     case "${f##*/}" in project-*) ;; *) cp "$f" "$d/.claude/tests/" ;; esac
      1192 +     cp "$f" "$d/.claude/tests/"
    selftest-needed: 952 passed, 24 failed
    === mutate: command exited 1; restored (verified byte-for-byte against .../.claude_tests_selftest-needed.test.sh.20261120T141917Z.1924008.bak) ===
          6     FAIL AC-1: VERSION, floors.conf, selftest.test.sh and shipped-docs.test.sh changed over the real suites print the seven suites that read or scan them
          6     FAIL AC-2: VERSION and floors.conf changed over the real suites print doctor, lib, selftest and worktree
          6     FAIL AC-5: a copy of the real doctor.test.sh declaring VERSION is still printed when VERSION changes
          6     FAIL AC-5: a copy of the real selftest.test.sh declaring floors.conf is still printed when floors.conf changes
    mutate: no stranded mutation; nothing of a previous run is in the tree.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-119` from `.claude/harness/models.conf`.
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
| DIFF-REVIEW | `lead-po` | `fable` | reading a whole diff for the defect no test was written for is judgement against the contract, and it is where a wrong call ships; a finding it labels goes back to GATES or RED, on opus |
| REVIEW | `lead-po` | `fable` | reading review feedback against the contract is orchestration judgement, and a wrong call here ships; a fix it finds goes back to GATES or RED, on opus |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation - code, with no failing test in front of any of it, so the stronger development model |
| ADJUDICATE | `lead-po` | `fable` | a claim that an acceptance criterion, a threshold or a frozen test is wrong is judged against the contract by a fresh dispatch on different inputs, never by the orchestrator that wants the answer; needed in any phase, so it is last |

**Resolved:**

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
- PLANNED, RED, GREEN, GATES: run inline by the orchestrating session; resolved Opus 5.5 (`claude-opus-5-5`). PLANNED was planned for `lead-po` on `fable` and ran on `opus`: a two-line test fix cut from a CI log, with the fresh `fable` judgement spent on the diff review.
- DIFF-REVIEW round 1: `lead-po`, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override.
## Out of scope

- `scripts/selftest-needed.sh`: its selection is right; a consumer suite
  that names a path should be selected for it.
- HARNESS-117's work.

## Test plan

The change is to the test suite itself: `h115_real` and `H115_M` in
`.claude/tests/selftest-needed.test.sh` skip `project-*.test.sh`. No
assertion is added, removed or reworded; AC-1 is observed by running the
suite with a consumer-style probe suite in the tree (the Context's
reproduction), AC-2 by running it without one.

## Handoff: RED -> GREEN

Written by the orchestrating session (Opus 5.5, `claude-opus-5-5`), acting
as Test Developer. The RED failure is the Context's reproduction (24 failed
with the probe, on the unfixed suite). On the corrected suite, 2026-11-20:

    with the probe .claude/tests/project-probe.test.sh (names VERSION and floors.conf), untracked:
    selftest-needed: 976 passed, 0 failed
    with-probe exit 0
    probe removed:
    selftest-needed: 976 passed, 0 failed
    no-probe exit 0

These pass on arrival because the suite is corrected against code that
already exists; DV-1 earns the correction at GATES by putting the plain copy
back with the probe present. GREEN writes only `VERSION` (137).
## Regressions

## Diff review

### Round 1 (2026-11-20)

`lead-po` on the DIFF-REVIEW row, planned `fable`, resolved Fable 5.2
(`claude-fable-5-2`); no override reported. Changed no file.

Checked: the count and the copy use the same glob and the same skip, so the
header's total and the fixture cannot drift apart; top-level `for f` was
already `for f` and nothing later reads it; `local f` in `h115_real`
shadows nothing its callbacks (`h115_decl_doctor`, `h115_decl_selftest`)
read, and HARNESS-117's new calls pass no argument; no other suite copies
or counts the real suites into a pinned list (`shipped-docs.test.sh:215`
already skips `project-*.test.sh`; `scripts/selftest-needed.sh` counts
consumer suites on purpose); `project-*.test.sh` is the convention
`floors.conf`, `selftest.sh`, `refresh-harness.sh` and `shipped-docs`
already use. Ran AC-2: `selftest-needed: 976 passed, 0 failed`, exit 0.
HARNESS-117's new `h115_real` cases expect `all`, independent of what was
copied.

No findings.

Not checked: AC-1 with the probe was not re-run by the reviewer (relies on
the pasted handoff and DV-1).

Verdict: Ship.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-20T14:24:31Z
    commit: 9cd5ae8
    tree:   0f5e1fc2352e35737459c461339b7b35b357b2d4
    result: pass (0 ran, 7 unconfigured, 0 known)

    UNCONFIGURED format
    UNCONFIGURED lint
    UNCONFIGURED typecheck
    UNCONFIGURED unit
    UNCONFIGURED coverage
    UNCONFIGURED integration
    UNCONFIGURED build
    ON REQUEST   mutation (not run: per-story cost the user declined (HARNESS-015); run it with /audit-mutations; bash scripts/gates.sh --gate mutation)

## Notes

- **PLANNED, 2026-11-20.** Planned by the orchestrating session (Opus 5.5,
  `claude-opus-5-5`) from the CI log of fantasy-world-builder PR #130. Id
  checked free on `origin/main`, the remote branches and open PRs (117 is
  in flight in `D:\adh-HARNESS-117`, 118 is DONE).
- **REVIEW, 2026-11-20.** `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`:
  7 of 35 suites, all passed (doctor 71, grep-count 38, lib 332,
  selftest-needed 976, shipped-docs 24, sigpipe 91, worktree 73; floors
  met). CI's full run is the run of record. The downstream CI run named
  `selftest-needed` as its only failing suite (1 of 40).
