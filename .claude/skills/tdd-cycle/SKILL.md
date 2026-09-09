---
name: tdd-cycle
description: The RED to GREEN discipline this repository enforces - how to write a test that fails for the right reason, how to make it pass without weakening it, and what must be handed between the two phases. Use when writing tests for a story, implementing a story, or deciding whether a story is genuinely done.
---

# The RED to GREEN cycle

One story is one cycle. The cycle is not a ritual; each step exists to catch a
specific way software goes wrong.

| Phase | Question it answers | Failure it prevents |
|---|---|---|
| RED | Does a test exist that fails when this behaviour is absent? | Code with no verification |
| GREEN | Does the simplest implementation satisfy it? | Speculative generality |
| GATES | Does it hold up under lint, types, build and coverage? | "Works on my machine" |

## Non-negotiables

1. The test is written first and is **observed failing**. Paste the failure.
   The one exception is a regression guard for an invariant an earlier story
   established, which is green on arrival by definition; it survives only with
   a probe or a negative control, and only if the handoff says which. See
   `reference/red-phase.md`.
2. The failure must be the *right* failure - your assertion, not an unrelated
   error that happens to be red.
3. During GREEN the tests are frozen. A test that is wrong sends the story back
   to RED; it is never edited into passing.
4. Never reach green by weakening: no relaxed tolerance, no skipped case, no
   deleted case, no assertion narrowed to what the code already does.
5. Done means `bash scripts/gates.sh` was run and passed. It writes its own
   summary into the story, stamped with the code it ran against; do not paste
   one, and do not edit what it wrote.
6. The same discipline applies to the gates themselves: a gate that has never
   been observed to fail is not a gate. When a story adds or changes one, break
   what it guards, watch it fail, record it in `## Gate probes`, and revert.
   See the `quality-gates` skill.
7. RED and GREEN each end with `bash scripts/gates.sh --fast`. Not for a pass -
   in RED the test gates are supposed to be red - but because the gates judge
   your tests with a *different and slower command* than the one you have been
   running. See "The gates run your tests differently" below.
8. A test that is wrong sends the story back to RED, and RED on a return is
   narrower: fix the defective test, touch nothing else, and earn the correction
   with a probe or a measurement. See `reference/red-phase.md`.

## The gates run your tests differently

RED and GREEN validate with the test command. At least one required gate does
not: the coverage gate runs the same suite under instrumentation, which is
strictly slower, and CI hardware is slower again. Nothing about a green test
command tells you the tests are *admissible* to the gate that will judge them.

This is not hypothetical. A suite passed RED, passed GREEN, passed sixteen local
gates and reached REVIEW - then failed a required gate in CI, because one
property test took 1,835 ms plain and 2,644 ms instrumented against a 5,000 ms
default timeout. Comfortable on a desktop, over the line on a runner. The cost
was a full RED -> GREEN -> GATES -> REVIEW round trip.

So:

- End RED and GREEN with `bash scripts/gates.sh --fast`. In RED read it for the
  *shape* of the failure: lint and typecheck should pass, and the test gates
  should fail with your assertion. A test gate failing on a timeout, a config
  error or a lint rule means the tests are not admissible and RED is not done.
- Set an explicit, generous timeout on property tests and anything that loops
  over a generated collection. The framework default is measured against the
  plain run, which is the fast one.
- In a property test or a whole-collection loop, do not call the assertion once
  per item. Accumulate the violations and assert once at the end. On identical
  work this is routinely an order of magnitude cheaper - in the case above, 260
  ms against 2,644 ms for the sibling test in the same block.

## Details

- `reference/red-phase.md` - choosing the test level, naming, what to cover
- `reference/green-phase.md` - implementing without over-building, refactoring
- `reference/handoff.md` - what crosses the context boundary, and the template

## Why the lock exists

Both classic failure modes are invisible from inside the conversation that
commits them: writing the implementation while "writing the test", and softening
the test to reach green. `.claude/hooks/phase-guard.sh` makes both impossible
rather than merely discouraged. Being blocked by it is information: either you
are in the wrong phase, or you were about to do the wrong thing.
