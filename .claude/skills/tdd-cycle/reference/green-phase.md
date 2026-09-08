# GREEN: making them pass, and nothing more

## Start from the failure, not the description

Run the tests yourself before writing anything. The handoff tells you what the
Test Developer believed; the output tells you what is true.

## Write the simplest thing that could work

The tests are the specification. Code that satisfies no test is code no one
asked for, and it will still be there - unverified - in a year.

Resist:

- generalising for a story that has not been written
- adding configuration nobody requested
- abstracting two similar things into one before a third arrives
- error handling for conditions no test and no acceptance criterion describes

The backlog will come back to you. Speculative code does not get that review.

## Work in small steps

Run the tests after each meaningful change, not once at the end. A red-to-green
transition you can attribute to one edit is a debugging session you never have
to hold in your head.

When they pass, run the whole suite. The story did not mention what you broke.

## Refactor with the net

Once green, improve what you just wrote - naming, duplication, the function that
grew three responsibilities - with the tests as the safety net. Re-run after
each step. Refactoring is not optional tidying; it is the phase that keeps the
next story cheap.

## When a test looks wrong

Sometimes it genuinely is: it asserts the wrong behaviour, encodes a
misunderstanding, or contradicts an acceptance criterion.

The response is never to edit it. Stop, and report:

- which test, and what it asserts
- what the story says the behaviour should be
- why you believe they conflict

The story returns to RED, the Test Developer fixes it, and you resume. This
costs a few minutes. Editing the test costs the guarantee that anything in the
repository is verified.
