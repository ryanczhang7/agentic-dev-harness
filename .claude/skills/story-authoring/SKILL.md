---
name: story-authoring
description: How to write epics and stories for this harness - sizing a story to one RED to GREEN cycle, phrasing acceptance criteria as testable behaviour, and choosing story types. Use when planning a product, adding a story to the backlog, or judging whether a story is ready to start.
---

# Writing epics and stories

## Create stories with the script

    bash scripts/new-story.sh WORLD-014 "Regions render with distinct biome colours" EPIC-03 feature

It writes the canonical file with the frontmatter the harness depends on. Do not
hand-roll story files; `scripts/check-boundaries.sh` validates the frontmatter
in CI and the hooks read it.

## Sizing

A story is one RED to GREEN cycle: one behaviour, testable in isolation,
typically a handful of files. Signs it is too big:

- the acceptance criteria describe two features joined by "and"
- you cannot name the tests before writing them
- it touches the data model, the API and the UI at once
- you would want to commit halfway through

Split by behaviour, not by layer. "Backend for regions" and "frontend for
regions" is a split that produces two stories neither of which can be
demonstrated. "Regions persist across reload" and "Regions render with distinct
colours" is a split that produces two demonstrable behaviours.

The rule above is framed around RED→GREEN. The bootstrap story runs under
SCAFFOLD instead, where nothing forces a test to exist, so over-sizing it is
both easier and more expensive: keep it to the toolchain and the gates, and
put every project-specific piece in a story of its own afterwards. See
`reference/bootstrap-story.md`, Sizing.

Order matters as well as size. `depends_on` in the frontmatter is enforced:
`phase.sh set` refuses to start a story while a dependency is not DONE. Use it
whenever a spike decides something a later story builds on.

## Acceptance criteria

Each one is a behaviour observable from outside the code, phrased so that a test
either passes or fails against it. Number them AC-1, AC-2 - the Test Developer
cites them and the PR body maps tests to them.

Good:

- **AC-1** - Given a world with three regions, when the map is rendered, then
  each region is filled with the colour registered for its biome.
- **AC-2** - Given a region whose biome is unknown, when the map is rendered,
  then it is filled with the neutral placeholder colour and a warning names the
  region.

Not criteria:

- "The map looks good." Not observable.
- "Refactor the renderer." No behaviour; that is a chore.
- "Use a quadtree." An implementation choice - if it matters it belongs in the
  architecture doc, and if it does not, let the Feature Developer choose.

Performance and accessibility criteria are welcome, with numbers: "renders a
10,000-tile world in under 100ms on the reference machine", "every control is
reachable by keyboard in visual order".

## Types

| Type | When | Phase path |
|---|---|---|
| `feature` | new behaviour | PLANNED, RED, GREEN, GATES, REVIEW, DONE |
| `fix` | a bug; criteria reproduce it | same - the failing test becomes the regression test |
| `chore` | tooling or migrations with no behaviour change | may use SCAFFOLD |
| `bootstrap` | turns the repo into the chosen stack | SCAFFOLD, GATES, REVIEW, DONE |
| `spike` | a timeboxed investigation; output is a document | PLANNED, REVIEW, DONE |

A bug is never fixed without a test that reproduces it first. That test is the
whole value of the fix.

## More

- `reference/sections.md` - what belongs in each section of a story file
- `reference/bootstrap-story.md` - how to write the first story of a project
- `reference/epics.md` - epic format and ordering
