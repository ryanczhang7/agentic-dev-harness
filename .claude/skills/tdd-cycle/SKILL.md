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
