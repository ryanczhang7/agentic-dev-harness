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

## Test doubles

Mock what you do not own and cannot run: a payment gateway, a third-party API.
Do not mock what you own - mocking your own code tests your assumptions about it
rather than it. A test that only asserts "this function was called" verifies
wiring, not behaviour, and will survive almost any bug.
