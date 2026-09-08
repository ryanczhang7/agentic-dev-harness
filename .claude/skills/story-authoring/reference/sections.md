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

## Gate results - Feature Developer

The `bash scripts/gates.sh` summary, verbatim, with the date.

## Notes - anyone

Decisions taken mid-story, surprises, things deliberately deferred. If a story
returns from GREEN to RED, the reason goes here.
