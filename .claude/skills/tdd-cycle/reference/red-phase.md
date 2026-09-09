# RED: writing tests that mean something

## Pick the level that can actually falsify the claim

- **Unit** - where the logic lives. Fast, precise, most of your tests. A pure
  function, a reducer, a rule, a parser.
- **Integration** - where a contract lives. Two of your own components, or one
  of yours and a real dependency (a database, a file format, a renderer).
- **End-to-end** - the handful of paths a user genuinely walks. Expensive and
  flaky in proportion to their number; keep them few and keep them real.

Do not test through three layers what one layer can prove. Do not unit-test a
function whose only interesting behaviour is the integration.

## Name tests after behaviour

The name is read when it fails, by someone who has lost the context.

- Bad: `test_calculate`, `it works`, `renders correctly`
- Good: `rejects a region whose borders do not close`
- Good: `keeps the seed stable when the world is reloaded`

## Cover the shape of the problem

For each acceptance criterion, ask:

- **Zero, one, many** - empty input, a single element, a realistic collection
- **Boundaries** - the value at the limit, and either side of it
- **Errors** - what should happen when it goes wrong, stated as a behaviour
  ("returns a validation error naming the field"), not "it throws something"
- **Non-goals** - where the story's Out of scope section is cheap to pin down,
  pin it down
- **Invariants** - what must remain true regardless of input; property-based
  tests earn their keep here

## Watch it fail

Run the tests. Read the output. Ask: if someone deleted the feature, would this
test go red? If someone subtly broke it - flipped a comparison, dropped a side
effect - would this test go red? If the answer is no, the test is theatre.

Common false RED: an import error. The suite is red because the module does not
exist, not because your assertion is unsatisfied. That is acceptable only for
the very first test of a new module, and only if the next run - after the module
exists but is empty - is red for your actual assertion.

## When a test passes the moment you write it

Usually this means the test is theatre, and the rule is to delete it or fix it.

There is one honest exception: a **regression guard for an invariant an earlier
story already established** - an import boundary, a lint rule, a schema
constraint, a migration that already ran. The mechanism works, so the guard is
green on arrival; deleting it leaves the mechanism untested, and somebody can
remove the rule later with nothing going red.

Keep such a test only if it earns it, one of two ways:

- **Probe the mechanism.** Break what the rule guards - or the rule's own
  configuration - watch the test go red, and revert. This is the `## Gate
  probes` discipline from the `quality-gates` skill applied to a test, and it
  is the stronger of the two. Prefer it whenever the story owns the rule.
- **Ship a negative control.** Assert the same offending construct is *accepted*
  where the rule does not apply and *rejected* where it does. One test without
  the other proves only that the tool rejects things; the pair is what proves
  the rule is specific to the boundary it claims to defend.

Both must exercise the real gate command. A linter invoked through a
convenience API is not the gate: `biome lint --stdin-file-path` ignores
`overrides`, so a path-scoped rule reports no diagnostic and exit 0 for a file
the real gate rejects. Write a real file, run the real command, delete the file.

Then say so in the handoff: which tests passed on arrival, which invariant and
which story they guard, and where the probe or the negative control is. Without
one of those, the test is decoration and the law stands - a test that has never
been observed to fail is not a test.

## Test doubles

Mock what you do not own and cannot run: a payment gateway, a third-party API.
Do not mock what you own - mocking your own code tests your assumptions about it
rather than it. A test that only asserts "this function was called" verifies
wiring, not behaviour, and will survive almost any bug.
