---
id: HARNESS-003
title: check-boundaries asserts its own verdict on the story checks
slug: check-boundaries-asserts-its-own-verdict
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-003-check-boundaries-asserts-its-own-verdict
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/boundaries.test.sh]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Filed from `docs/wiki/audits/enforcement-mutants-2026-09-15.md`, cluster C3.

Five further `check-boundaries.sh` rules survive mutation, for one shared reason:
`boundaries()` at `.claude/tests/boundaries.test.sh:23` runs the script, captures
`2>&1`, and never looks at the exit status; every assertion is an
`assert_contains` on a substring of the output. A rule therefore has a test only
where some fixture deliberately violates it. These five have no such fixture, so
deleting them changes no output any assertion reads. Each was run against
`bash .claude/tests/boundaries.test.sh` (41 assertions) and survived:

1. `:76` — `[ "$fid" = "$base" ]` → `[ -n "$fid" ]`. A story whose frontmatter
   `id` disagrees with its filename is accepted. `phase.sh`, `gates.sh` and this
   script all locate a story by filename, so a mismatch silently points three
   tools at different things.
2. `:85` — `if git ls-files --error-unmatch ...` inverted. A committed
   `.claude/state/current-story.env` is accepted; the check fires only when the
   file is *absent*. `rules.md` says this must never be committed — it carries
   the phase the guard reads.
3. `:135` — the "claimed by more than one story" `problem` downgraded to `note`.
   Two stories may name the same branch, which is what makes `sid` ambiguous in
   the first place.
4. `:305` — the `required_gates` PASS check inverted (`grep -qE` → `grep -qvE`).
   No fixture story sets `required_gates`, so the loop body never runs. The
   escalation a story makes for itself is unverified against the record.
5. `:316` — `case "$story_type" in feature|fix)` → `nosuchtype)`. The
   `## Handoff` requirement ("the only channel to the next agent; RED is not
   finished without it") never runs.

Required gate that would fail if this story's artifact broke: `unit`
(`bash scripts/selftest.sh`).

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

- **AC-1** — Given a story file whose frontmatter `id` differs from its
  filename, when `check-boundaries.sh` runs, then it FAILs naming both. Kills:
  `scripts/check-boundaries.sh:76` `s#\[ "$fid" = "$base" \]#[ -n "$fid" ]#`.
- **AC-2** — Given a repository in which `.claude/state/current-story.env` is
  tracked by git, when `check-boundaries.sh` runs, then it FAILs saying the file
  is machine-local. Kills: `scripts/check-boundaries.sh:85`
  `s#if git ls-files --error-unmatch#if ! git ls-files --error-unmatch#`.
- **AC-3** — Given two story files whose frontmatter `branch` is the same branch,
  when `check-boundaries.sh` runs on that branch, then it FAILs naming both story
  ids and exits non-zero. Kills: `scripts/check-boundaries.sh:135`
  `135s#problem "branch#note "branch#`.
- **AC-4** — Given a story at REVIEW whose frontmatter sets
  `required_gates: [integration]` and whose recorded gate run contains no
  `PASS integration` line, when `check-boundaries.sh` runs, then it FAILs naming
  that gate; and given a record that does contain it, then it reports the gate
  passed. Kills: `scripts/check-boundaries.sh:305` `305s#grep -qE#grep -qvE#`.
- **AC-5** — Given a `feature` story at REVIEW whose `## Handoff` section is
  empty or template-only, when `check-boundaries.sh` runs, then it FAILs saying
  the handoff is empty. Kills: `scripts/check-boundaries.sh:316`
  `316s#feature|fix)#nosuchtype)#`.
- **AC-6** — Given any `check-boundaries.sh` invocation in
  `.claude/tests/boundaries.test.sh` that is expected to refuse, when the suite
  runs, then it asserts the script's exit status is non-zero as well as its text;
  and for every invocation expected to pass, that it is zero.

## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. This is where "RED
     tested one shape and GREEN built another" is prevented, and it is not the
     acceptance criteria: the criteria are frozen and change only through
     ## Amendments; this is a working agreement RED is expected to sharpen.
     One block per thing the story touches:
       * module paths and exported names, exactly
       * exact signatures, and the types the assertions will destructure
       * THE SEMANTICS BEHIND EACH NUMBER - not clamp(latitude) but "latitude
         clamps at +/-85, and dragging DOWN brings the north into view". One
         sentence per number settles a sign error in one line
       * the accessible markup for anything user-facing: roles, labels, what is
         a sibling of what
       * the oracle partition of the criteria (settled / oracle-free /
         mechanical - see story-authoring)
       * baseline measurements the story may read out rather than re-derive,
         each with what it was measured on
       * TEST-ONLY DEPENDENCIES this story is likely to need, by name. RED
         may add them itself, but only inside the dev block - so a library
         production will ALSO use is a GREEN change and is better decided
         here than discovered mid-phase. Where the ecosystem has no dev
         block at all (go.mod, requirements.txt, *.csproj), RED cannot
         declare one and the phase round trip is yours to plan for
       * FOR EVERY EXISTING EXPORT WHOSE SIGNATURE THIS STORY CHANGES: every
         caller, source and test, grep-listed here before dispatch. RED cannot
         find these itself - the old signature still exists during RED, so a
         caller of it still compiles and is absent from RED's typecheck. One
         such file went missing and took 25 tests with it, silently, at GREEN. -->

**Scope, as of 2026-09-30.** AC-1 to AC-5 and the refusal half of AC-6 were
delivered before this story started, by commits `9fbd39d` and the earlier
exit-status work it builds on. The orchestrator verified that by putting each
mutant back with `scripts/mutate.sh` against `bash .claude/tests/boundaries.test.sh`
(the output is in ## Notes). The `boundaries()` helper the Context blames no
longer exists: `run_boundaries` (`boundaries.test.sh:32`) sets `$out` and `$rc`,
and `refused` (`:41`) fails any refusal that exits 0. **What remains is the pass
half of AC-6**, and that is all RED writes.

**Writes:** `.claude/tests/boundaries.test.sh`

**Which invocations count as "expected to pass".** A whole run can exit 0 only
when the fixture story carries a real `## Gate results` written by `gates.sh`.
That means `story_blocked` (`:236`) or anything else that runs `gates.sh` into
the fixture. Every other fixture (`story_on_branch`, `scaffold_story`,
`manifest_story`, `story_claiming`, `harness_branch`) has no gate record and is
refused by the gate-record rule *by design*, as the comment above
`accepts_manifest` (`:52`) says. Those invocations assert that one rule accepts,
not that the run does, and AC-6 does not reach them. Asserting rc there is out
of scope.

Of the gate-recorded invocations whose assertions are acceptances, four already
assert `0 "$rc"`: "and it is not refused" (`:274`), "and the run is clean"
(`:1045`), and the two AC-2 assertions (`:1245`, `:1249`). Two do not:

| Line | Assertion | Owed |
|---|---|---|
| `:293` | "DONE with the CI run quoted is accepted" | `assert_eq "<name>" 0 "$rc"` |
| `:1191` | "a record made against this tree matches it" | `assert_eq "<name>" 0 "$rc"` |

RED **checks this enumeration against the tree** (every `story_blocked` use, and
any other fixture that runs `gates.sh`) and amends this table in place with a
reason if it finds another, or finds one of these is not actually expected clean.

**If either run does not exit 0 today, that is a finding, not a test to
soften.** Report what refused it. Do not change the fixture to make it pass
without saying so in the handoff.

**Earning (tests written against code that already exists).** Each new
assertion passes on arrival, so it is earned by one mutation of the production
behaviour it pins, via `scripts/mutate.sh`, with the output pasted into the
handoff. The mutation must keep the message the existing `assert_contains`
reads, so that **only** the new rc assertion goes red:

- `:293`: in `check-boundaries.sh`, `ok "blocked gate '$g' was verified on CI"`
  becomes `problem "blocked gate ...`. The output still contains "verified on
  CI", and the run exits 1.
- `:1191`: `ok "gate record matches $where (tree $rec)"` becomes
  `problem "gate record matches ...`. The existing `assert_contains` anchors on
  `ok    `, so it goes red too, as do the rc assertions at `:1245`/`:1249`.
  That is expected; what must be shown is that the NEW rc assertion is among
  the failures.

**Oracle partition.** Everything here is mechanical: the exact value is 0.

**No production code changes.** GREEN is expected to be a no-op, verified by the
orchestrator (`rules.md`, the return-to-RED paragraph, applies by analogy: do
not dispatch a feature developer with nothing to do).

## Deferred verifications

<!-- REQUIRED when a verification this story depends on provably cannot run in
     the phase that wants it; omit the section otherwise. Written by the Lead PO
     at PLANNED, and the phase that owns it pastes the result in.
     The case this exists for: a negative control for a round trip, a threshold
     or a codec has to break the real implementation to mean anything, and in
     RED there is no implementation to break. RED naming the control and saying
     it could not run it is the honest answer; RED claiming a verification it
     did not do is the failure. One block per entry:
       * what it verifies, as a falsifiable condition - "with one field dropped
         from the encoder, AC-1's property test MUST fail"
       * why the phase that wants it cannot run it
       * THE PHASE THAT OWNS IT, by name. check-boundaries.sh refuses a PR
         whose block names no phase
       * the RESULT, pasted, once that phase runs it: what was mutated, what
         failed, and that the file was restored - or the word WAIVED with the
         reason. check-boundaries.sh refuses a PR that has neither
     Schedule it into GATES rather than RED where you can: source is writable
     there, and a story that bounced back to RED mid-cycle gets its corrected
     assertions earned by the same mutation, for free. Do THREE mutations rather
     than one, and make one of them a wrong VALUE rather than a missing field: a
     suite that catches an omission can be blind to a corruption, and a codec
     that is uniformly wrong round-trips through itself perfectly. -->

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. check-boundaries.sh fails a PR whose criteria differ
     from the base branch without an entry here. Omit the section if unused.
     Where the change came from a subagent's claim that the criterion was
     wrong, record the ORCHESTRATOR'S OWN reproduction of it - different
     inputs, not the subagent's code. That claim is also what an agent says
     when it wants to stop failing. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-003` from `.claude/harness/models.conf`.
A PLAN, not a record: a session setting or an explicit override can beat both
this and the agent's own `model:` field, and nothing here can see which won.
The orchestrator still writes down the model each dispatch **resolved** to, by
name, below the table.

| Phase | Agent | Planned | Why |
|---|---|---|---|
| PLANNED | `lead-po` | `opus` | planning is the judgement phase: decomposition, the oracle partition, and what goes in the contract |
| RED | `test-developer` | `opus` | the lock freezes none of the paths this story names, so the contract is not an aid to the model here - it is the only enforcement there is. A weaker model against a safety net and a weaker model against nothing are different propositions |
| GREEN | `feature-developer` | `opus` | the failure mode of a weaker model here is reaching green by weakening a test, which is the one thing this harness exists to prevent |
| GATES | `feature-developer` | `opus` | same risk as GREEN, and a gate failure is where "make it stop complaining" is most tempting |
| REVIEW | `lead-po` | `opus` | reading review feedback against the contract is judgement, and a wrong call here ships |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation, with no failing test in front of any of it |

**Resolved:**

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- Asserting an exit status on fixtures that have no gate record. Their whole
  run is refused by design; see ## Contract.
- Re-earning AC-1 to AC-5. Their mutants were re-run on 2026-09-30 and all were
  caught (## Notes).

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
         or Gate probes section describes a failure without showing one
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
     it guards, run the gate, paste the failure, revert. One block per gate:
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


### AC-1 to AC-5 already covered (orchestrator, 2026-09-30)

Each mutant was put back with `scripts/mutate.sh` against
`bash .claude/tests/boundaries.test.sh`, anchored on today's code because the
Context's line numbers have drifted. All five were caught and all restores were
verified byte for byte.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s#\[ "$fid" = "$base" \]#[ -n "$fid" ]#) ===
    FAIL an id that disagrees with the filename
boundaries: 79 passed, 1 failed
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s#^if git ls-files --error-unmatch#if ! git ls-files --error-unmatch#) ===
    FAIL and it is not refused
    FAIL and the run is clean
    FAIL a committed current-story.env is refused
    FAIL and does not also report it clean
    FAIL AC-2: and the local run exits 0
    FAIL AC-2: and CI's run exits 0
boundaries: 74 passed, 6 failed
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s#problem "branch '$br' is claimed#note "branch '$br' is claimed#) ===
    FAIL two claimants is a problem, not a coin flip
boundaries: 79 passed, 1 failed
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by /PASS\[\[:space:\]\]+\$g/s#if awk#if ! awk#) ===
    FAIL a required gate the record has no PASS for
    FAIL one that did pass is reported as passing
    FAIL and the run is clean
boundaries: 77 passed, 3 failed
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s#^  feature|fix)#  nosuchtype)#) ===
    FAIL a feature story with a template-only handoff
    FAIL while a template-only one still is
boundaries: 78 passed, 2 failed
```

| AC | Test (`boundaries.test.sh`) |
|---|---|
| AC-1 | "an id that disagrees with the filename" |
| AC-2 | "a committed current-story.env is refused" |
| AC-3 | "two claimants is a problem, not a coin flip" |
| AC-4 | "a required gate the record has no PASS for", "one that did pass is reported as passing" |
| AC-5 | "a feature story with a template-only handoff" |
| AC-6 (refusals) | every refusal goes through `refused`, which fails on exit 0 |
