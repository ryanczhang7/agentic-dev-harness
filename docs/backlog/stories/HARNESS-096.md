---
id: HARNESS-096
title: --suites counts a mention only where the path ends, and declares fixture mentions
slug: suites-counts-a-mention-only-where-the-p
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-096-suites-counts-a-mention-only-where-the-p
depends_on: [HARNESS-094]      # the mechanism it refines; user decision 2026-11-04 to ship 094 and file this
touches: [scripts/selftest-needed.sh, .claude/tests/selftest-needed.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]
required_gates: []  # every gate is unconfigured here; the artifact is judged by selftest (see Context)
---

## Context

HARNESS-094 added `bash scripts/selftest-needed.sh --suites`, which maps a
branch's changed harness paths to the suites that can break. Rule R3 maps a
path to every suite whose source contains it as a fixed-string substring (the
awk `index($0, p[j])`). R5 gives `all` for any path that no rule maps. The
second GATES diff review of HARNESS-094 found two ways R3 keeps a path away
from R5 when it should not. The orchestrator reproduced both in a clone at
`9bf37f0` (see `HARNESS-094.md`, `## Diff review`, "Second review"). The user
chose to ship 094 and file them here (094 `## Notes`, PO decision).

1. **Prefix match.** A path counts as mentioned when a suite names a longer
   path that starts with it. An untracked `scripts/plan` selected 8 of 34
   suites `(mentioned)`, from suites that name `scripts/plan.sh`. A comment
   `# leftover: scripts/newtool.sh.bak` in one suite made a new
   `scripts/newtool.sh` select that suite. Today no tracked harness path
   (158, against 34 suites) is mentioned only as a prefix, so this is latent.
2. **Fixture mentions.** `selftest-needed.test.sh` names
   `.claude/tests/_helpers.sh` and `scripts/newtool.sh` as fixture data. A
   real file of either name is therefore mapped to `selftest-needed` and never
   reaches R5: an untracked `.claude/tests/_helpers.sh` gave 3 of 34, where an
   unmentioned `.claude/tests/_zz_probe_helper.sh` gave `all`. This is a limit
   of mapping by mention and cannot be removed without dropping R3. It can be
   declared, and the suite's own fixture names can be made ones no real file
   will take.

CI runs every suite on every PR whatever `--changed` selects, so an
under-selection costs a CI round trip, not a broken `main`. That is why this
was deferred rather than fixed in 094.

Required gate that would fail if this story's artifact broke: none is
configured in this repository. The artifact is judged by
`bash scripts/selftest.sh selftest-needed`, which CI runs in full on the PR.

## Acceptance criteria

- **AC-1 (a mention ends where the path ends)** — Given a fixture suite whose
  source names `scripts/x.sh.bak` and `scripts/xy.sh` but never `scripts/x.sh`
  on its own, when a changed `scripts/x.sh` is enumerated by `--suites`, then
  stdout is exactly `all` and stderr names `scripts/x.sh` as mapped by no
  rule. Given the same suite naming `scripts/x.sh` followed by a space, a
  quote, a backtick, a closing parenthesis, a colon, a comma, or a `.` that
  ends a sentence, then `scripts/x.sh` maps to that suite (the control).
- **AC-2 (prefix of a directory)** — Given a suite that names
  `scripts/new-story.sh` only, a changed untracked `scripts/new` gives
  exactly `all`.
- **AC-3 (fixture names cannot collide)** — Every path that
  `selftest-needed.test.sh` creates as fixture data for an R5 case uses a name
  no real harness file will plausibly take, and that `classify.sh` still calls
  `harness` (check it with `bash scripts/classify.sh PATH`; do **not** reach
  for the `__probe_` convention without checking, because it classifies as
  `test`). A real-tree probe of each such R5
  case is pasted into `## Gate probes`: on the real tree, an untracked file of
  a plausible real name that no suite mentions gives `all`.
- **AC-4 (the limit is declared)** — The header of `selftest-needed.sh` and
  `CLAUDE.md`'s `--suites` line no longer claim R3 "never under-selects".
  They say instead that a path any suite names, including as test data, is
  mapped by that mention and does not reach R5.

## Contract

- **Writes:** `scripts/selftest-needed.sh`, `.claude/tests/selftest-needed.test.sh`,
  `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh` (its floor
  table), `.claude/harness/VERSION`.
- **R3, amended.** A match of `p` at offset `k` in a line counts only when the
  character after it (offset `k + length(p)`) is end of line, or is not in
  `[A-Za-z0-9_/-]` and is not a `.` followed by `[A-Za-z0-9]`. When a line
  holds `p` more than once, any one match that ends cleanly counts. This
  holds in POSIX awk, so it needs no gawk extension (`rules.md`,
  Portability).
- **Oracle.** All criteria are mechanical: exact stdout, exact stderr shape,
  exact exit status, in the fixture style of the HARNESS-094 cases.
- RED may amend a block in place with a reason, and GREEN builds what the
  amended block says.

## Deferred verifications

**DV-1 (defect put back). Owner: GATES.** Revert the boundary check with
`bash scripts/mutate.sh scripts/selftest-needed.sh '<expr restoring a bare index() hit>' -- bash scripts/selftest.sh selftest-needed`.
AC-1's `x.sh.bak` case and AC-2 must go red, and AC-1's control must stay
green. Paste the red lines and the restore line.

**DV-2 (real tree). Owner: GATES.** On the real tree, `--suites` against the
branch's merge base must still give, for the merged PRs #165 to #177 replayed
as in HARNESS-094's second review, the same answers as the 094 script, or
`all` where a prefix-only mention was the only thing mapping a path. Paste
the table. A list that shrinks is a finding.

## Amendments

<!-- none yet -->

## Suppressions

<!-- none -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-096` from `.claude/harness/models.conf`.
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

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

- Replacing mention-based mapping with a static call graph of which scripts
  each suite runs. That was the rejected alternative in HARNESS-094.
- Changing what CI runs. CI keeps running every suite.

## Test plan

## Handoff: RED -> GREEN

## Regressions

## Gate results

## Gate probes

## Scaffold inventory

<!-- not a SCAFFOLD story -->

## Notes

- Planned 2026-11-04 from HARNESS-094's second GATES diff review, at the
  user's decision "Ship, file follow-up".
