# The handoff between phases

The Test Developer and the Feature Developer never share a context. Everything
that crosses between them crosses through the story file. Treat it as writing
for someone who has read nothing.

## Filling in `## Handoff: RED -> GREEN`

Four things, always:

**1. The exact command.** Copy-pasteable, taken from
`.claude/harness/project.conf`, not from memory. Include any filter that runs
only this story's tests.

**2. The verbatim failure output.** Not a summary of it. Indent it as a code
block. The next agent needs to recognise the same output when they run it.

**3. A table of what was written.** One row per test:

| Test | Asserts | Covers |
|---|---|---|
| `rejects a region whose borders do not close` | validation error naming the open edge | AC-2 |

**4. Notes for the implementer.** Anything discovered that should change the
approach: a constraint in the architecture doc, an existing helper worth
reusing, an edge case the acceptance criteria did not anticipate, a place where
the criteria and the design notes disagree.

Also state, in one sentence, **why this is the right failure** - which assertion
is unsatisfied, and why that assertion is the behaviour the story asks for.

## Filling in `## Gate results`

The `bash scripts/gates.sh` summary block, verbatim, with the date. Then a line
for anything skipped or any optional gate that failed, and why that is
acceptable. If you cannot justify it, it is not acceptable.

## What not to write

- "The tests fail as expected." Which tests, with what output?
- "Implemented the feature." Which files, satisfying which criteria?
- "All good." The gates are the only thing entitled to that opinion.
