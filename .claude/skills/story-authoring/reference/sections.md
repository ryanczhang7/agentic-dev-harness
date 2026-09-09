# The sections of a story file

Written by different agents at different times. Each has one owner.

## Frontmatter - Lead PO

`id`, `title`, `slug`, `epic`, `type`, `status`, `phase`, `branch`,
`depends_on`. Only `scripts/phase.sh` should change `phase`, `status` and
`branch` once the story is in flight.

## Context - Lead PO

Why this story exists and what constrains it. Link the epic and the wiki pages
that bound the solution. Two or three sentences; the Test Developer reads this
first and needs orientation, not history.

## Acceptance criteria - Lead PO

Numbered, observable, testable. See the main skill file.

## Amendments - Lead PO, with the user

Acceptance criteria are frozen once the story leaves PLANNED. If one is wrong or
unsatisfiable, the story stops, the product owner decides, and the change is
recorded here: which AC, what it said, what it says now, who approved it and
why. `check-boundaries.sh` fails a PR whose criteria differ from the base branch
without an entry. Omit when unused.

## Out of scope - Lead PO

The explicit non-goals. This is how the Feature Developer knows where to stop,
and it is often the most valuable section in the file.

## Design notes - Lead Designer

For user-facing stories: components, states, tokens, breakpoints, accessibility
requirements. Concrete enough to implement without a second conversation. Omit
entirely for headless work rather than writing "n/a".

## Test plan - Test Developer

Which tests, at which level, and which acceptance criterion each covers. Written
during RED, before or as the tests are written.

## Handoff: RED to GREEN - Test Developer

The only channel to the Feature Developer. See the `tdd-cycle` skill,
`reference/handoff.md`.

## Gate results - scripts/gates.sh, nobody else

Written by the script itself on every full run: a marker line, the UTC time,
the commit, a hash of the source/test/config content the gates ran against, and
the summary. Not pasted, not edited. `check-boundaries.sh` refuses a PR whose
section lacks the marker or whose recorded hash does not match the code being
merged - so a story that changes code after its last gate run has to run the
gates again, which is the point.

## Gate probes - Feature Developer

Required for any story that adds or changes a gate, its command, or its
`evidence` line; omitted entirely otherwise. For each such gate: what was broken
to make it fail, the failure output, and confirmation the probe was reverted.

This is RED applied to the gates. Without it a story can add a gate that has
never been seen to do anything, and every story afterwards inherits it as proof.
See the `quality-gates` skill.

## Scaffold inventory - whoever scaffolds

Required for a `bootstrap` or `chore` story that writes production code under
SCAFFOLD; omitted otherwise. One line per production file written, and for
anything with behaviour rather than configuration, the test that covers it.
SCAFFOLD is the one phase where nothing forces a test to exist first, and it is
the phase every later story's correctness rests on; this is where the scaffolder
shows the tests were written anyway. `check-boundaries.sh` refuses the PR if a
changed source file is not named here. Whether the named test is adequate is a
reviewer's judgement, not the script's.

## Notes - anyone

Decisions taken mid-story, surprises, things deliberately deferred. If a story
returns from GREEN to RED, the reason goes here.
