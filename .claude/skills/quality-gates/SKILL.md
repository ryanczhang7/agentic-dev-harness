---
name: quality-gates
description: What each quality gate means in this harness, how to run them, and how to triage a failure without weakening the tests. Use when a story reaches the GATES phase, when a gate fails, or when configuring gates for a new stack.
---

# Quality gates

The gate names are stable across every project; the commands behind them are
per-stack and live in `.claude/harness/project.conf`. Agents talk about "the
coverage gate"; the manifest knows whether that means `pytest --cov`,
`vitest --coverage` or `cargo llvm-cov`.

    bash scripts/gates.sh              # everything
    bash scripts/gates.sh --list       # what is configured
    bash scripts/gates.sh --gate unit  # one gate
    bash scripts/gates.sh --required   # required only
    bash scripts/gates.sh --audit      # check the manifest itself, run nothing

Failures write their output to `.claude/state/gate-logs/<gate>.log`.

## The gates

| Gate | Required | Answers |
|---|---|---|
| `format` | optional | Is the code formatted to the project standard? |
| `lint` | required | Does it violate the project rules? |
| `typecheck` | required | Do the types hold? |
| `unit` | required | Does the behaviour hold in isolation? |
| `coverage` | required | Is anything shipped unexercised? |
| `integration` | optional | Do the seams hold against real dependencies? |
| `build` | required | Does a production artefact come out? |
| `mutation` | optional | Would the tests notice if the code were wrong? |

A gate marked required with no command configured is a warning before the
bootstrap story lands (`BOOTSTRAPPED=no`) and a hard failure after it. That is
deliberate: an unconfigured gate must never silently look like a passing one.

## The vacuous pass

**Exit 0 is not proof that a gate did anything.** It is the absence of a
complaint, and a tool with nothing to do does not complain. A gate can run, exit
0, be recorded as `PASS`, be pasted into a story as evidence, and have tested
nothing whatsoever.

This has happened for real. A `cargo test` in a workspace whose root is also a
package tests only the root package and skips every member crate; the gate ran
in under a second, printed `running 0 tests`, exited 0, and passed. The crate it
skipped was the one holding the product's data-integrity code.

Which tools are honest about having no work is not guessable:

| Gate command | With zero work to do | Safe? |
|---|---|---|
| `cargo test` at a workspace root | exit 0, `running 0 tests` | **no** |
| `biome lint <dir with no source>` | exit 0, "Checked 1 file" | **no** |
| `mypy <target resolving empty>` | exit 0, "no issues found in 0 source files" | **no** |
| Coverage threshold on a glob matching no files | satisfied silently | **no** |
| Anything with `--passWithNoTests` | exit 0 | **no** |
| `vitest run` with no matching test files | non-zero | yes |
| `pytest` collecting nothing | exit 5 | yes |
| `tsc --noEmit` with an empty `include` | exit 2, `TS18003` | yes |
| `playwright test` with no specs | non-zero | yes |

So each gate declares what evidence of work it must produce, in `project.conf`:

    gate     | unit | required | . | cargo test --workspace
    evidence | unit | test result: ok\. [1-9]

After a gate exits 0, its captured output must match its regex or it fails with
`ran but produced no evidence of work`, at the gate's own severity. The regex
asserts **volume of work observed, never success** - success is the exit code's
job, and conflating the two makes the regexes fragile against tool versions.

A gate with no `evidence` line behaves exactly as before, so this is safe to
adopt late; once `BOOTSTRAPPED=yes`, a required gate without one is reported as
a warning. `bash scripts/gates.sh --audit` lists what is missing without running
anything. Canonical regexes per ecosystem are in the `stack-profiles` skill.

## WARN must mean something changed

Optional gates report rather than block, which is not the same as ignorable -
a WARN on `integration` has to be read. That only works if WARN is rare. An
optional gate that is *known* to fail - a mutation tool the stack cannot run
yet, an end-to-end suite waiting on a service - would otherwise WARN on every
run for the life of the project, the next agent learns to skip past WARNs, and
the day `integration` regresses its WARN sits in a list next to one that has
been noise for sixty stories.

So a known failure is declared, with its reason, in `project.conf`:

    gate   | mutation | optional | . | pnpm exec stryker run
    waiver | mutation | stryker needs a TS compiler API TS 7 lacks; stack.md s4

`gates.sh` then reports it as `KNOWN`, with the reason inline, and `WARN` is
reserved for a failure nobody declared. A waived gate still runs; when it
passes, the summary says the waiver is no longer needed and to remove it.
Waivers are refused on required gates - that would be a bypass with a nicer
name. Leaving a gate unconfigured is not an alternative: a required gate with
no command fails once `BOOTSTRAPPED=yes`, deliberately.

## The gate record is written by the tool

A full run of `gates.sh` writes its own summary into the active story's
`## Gate results` (or `--story <id>`): a marker line, the UTC time, the commit,
a hash of every source, test, config and harness file as it was on disk when
the gates ran, and the summary. `--gate` and `--required` runs are not recorded,
because a partial run is not evidence that the story passes its gates.

Nobody pastes it and nobody edits it. `check-boundaries.sh` refuses a PR whose
section has no marker, whose recorded result is not `pass`, or whose recorded
hash does not match the code being merged - which means changing source after
the last full run forces another full run before the PR is acceptable. In CI
the hash is recomputed at the PR head commit, so base-branch drift does not
false-fail it. That turns law 3 from "run it and paste the result" - a step an
agent motivated to finish could fake without anything noticing - into a record
the tool wrote and the code has to match.

## A gate that has never been observed to fail is not a gate

The first law says no production code without a failing test that demanded it,
and `rules.md` says a test never observed to fail is not a test. The same
applies to the gates themselves - they are the mechanism the whole discipline
rests on, and they are code like anything else.

**When a story adds or changes a gate: break the thing it guards, watch the gate
fail, record the output, and revert.** This is RED, applied to a gate. Write it
into the story's `## Gate probes` section.

It is not ceremony. A lint rule forbidding `core/` from importing `ui/` was
probed this way and turned out to catch the aliased import `@ui/App` but not the
relative `../../ui/App` - which is the form somebody actually crosses a boundary
with by accident. Nothing but breaking it on purpose would have found that.

What to break, per gate: delete or rename the test files (`unit`); remove a test
covering a branch (`coverage`); write the violation the rule forbids (`lint`);
introduce a type error (`typecheck`); break an import (`build`). Revert every
probe before moving on, and say in the story that you did.

## Rules for triage

1. Read the actual output before forming a theory. It is in the log file.
2. Fix the cause, not the symptom. A type error that disappears when you widen
   a type to `any` has not been fixed.
3. Never reach green by weakening a test, loosening a lint rule, lowering the
   coverage threshold, or adding a suppression comment - unless the user agrees
   the rule itself is wrong, and it is recorded in the story.
4. If a gate failure means a **test** is wrong, the story returns to RED. Say so
   and record why.

5. A gate that fails because it produced no evidence of work is **not** fixed by
   deleting its `evidence` line. Fix the command so it does the work, or - if
   the regex is genuinely wrong for this tool version - correct the regex and
   say so in the story. Removing the line is the gate equivalent of deleting a
   failing test.

`reference/triage.md` has the per-gate playbook, including what a coverage
failure actually tells you and when a suppression is legitimate.
`reference/configuring.md` covers wiring gates for a new stack.
