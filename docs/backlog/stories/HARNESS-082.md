---
id: HARNESS-082
title: A stub added to source in GREEN or GATES is refused unless the story declares it
slug: a-stub-added-to-source-in-green-or-gates
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-082-a-stub-added-to-source-in-green-or-gates
depends_on: [HARNESS-081]      # the 3j walk, the needle table and ## Suppressions are its
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/tests/floors.conf, .claude/harness/VERSION]
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

GitHub issue #132, second cut. HARNESS-081 built the per-commit walk over
GREEN and GATES commits in `scripts/check-boundaries.sh` (block 3j), a needle
table of one-line comment directives, and the `## Suppressions` escape hatch.
The issue's fourth family is different in kind: **stubs standing in for an
implementation** - `throw new Error("not implemented")`, `todo!()`,
`unimplemented!()`, `raise NotImplementedError`, and an empty `catch {}` or
`except: pass`. These are statements, not comments; two of them span lines;
and the claim they break is law 4 ("full coverage of the behaviour the story
claims") rather than law 2. A GREEN that reaches green with a `todo!()` in a
branch the tests do not reach has shipped a panic, and the gates are green.

This story appends rows to HARNESS-081's table for the single-line stubs and
adds the one thing the table cannot express: a **two-line** matcher for an
empty handler, where the opener and the closer are consecutive added lines.
Everything else - the walk, the phases judged, the classifier's choice of
files, the refusal shape, the escape hatch - is HARNESS-081's and is not
changed here. The gate that fails if this breaks is `bash scripts/selftest.sh
boundaries`.

## Acceptance criteria

- **AC-1** — Given a GREEN commit adding `throw new Error("not implemented")`
  to a file `classify.sh` calls `source`, when `bash scripts/check-boundaries.sh
  main` runs, then it exits non-zero and prints HARNESS-081's `FAIL` shape
  naming rule id `stub-throw`, the path, the line number, the short commit and
  `GREEN`; the same at `GATES`.
- **AC-2** — Given one GREEN commit per row of C-1's table, each adding that
  row's example line, when `check-boundaries.sh` runs, then every row is
  refused with its rule id. *Control:* the C-2 corpus - `todo!` inside a
  string, `unimplemented` as an identifier, a `catch (e) { log(e) }` with a
  body, an `except ValueError: pass` whose next added line is not the end of
  the block but another statement, `raise NotImplementedError` inside an
  abstract base class method whose body is **only** that raise under a
  `@abstractmethod` decorator on the previous added line - is not refused.
- **AC-3** — Given a GREEN commit whose added lines include, consecutively,
  `} catch (e) {` and `}` (nothing between them but whitespace), and another
  whose added lines include `except Exception:` followed by `    pass`, when
  `check-boundaries.sh` runs, then each is refused with rule id `empty-handler`
  naming the line of the **opener**. *Control:* the same two lines when only
  the closer is added (the opener is context, so the handler pre-existed) are
  not refused.
- **AC-4** — Given the AC-1 commit and a `## Suppressions` line carrying the
  path, `[stub-throw]` and `approved by`, when `check-boundaries.sh` runs, then
  it is accepted with HARNESS-081's `ok` line; nothing about the escape hatch
  is re-specified here, and this AC pins only that a new row is discharged by
  the existing mechanism.
- **AC-5** — Given a GREEN commit that *removes* a `todo!()` line, when
  `check-boundaries.sh` runs, then it is not refused and the 3j `ok` line
  counts the commit as judged.

## Contract

**Writes:** `scripts/check-boundaries.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/floors.conf`, `.claude/harness/VERSION`

RED may amend any block in place, with a reason; GREEN builds what the
amended block says. Blocks of HARNESS-081's contract that this story relies
on are cited, not copied; where this story needs one changed it says so.

**C-1. Rows appended to `suppression_needles()`** (HARNESS-081 C-2; `O` is
`(^|[[:space:]])`):

| rule id | ERE | example added line |
|---|---|---|
| `stub-throw` | `throw[[:space:]]+new[[:space:]]+Error\([[:space:]]*["'`](not[[:space:]]+implemented\|TODO\|unimplemented)` | `throw new Error("not implemented")` |
| `stub-todo` | `O(todo\|unimplemented\|unreachable)!\(` | `todo!()` and `unimplemented!("later")` |
| `stub-raise` | `Oraise[[:space:]]+NotImplementedError([[:space:](]\|$)` | `raise NotImplementedError` |
| `stub-gd` | `O(push_error\|assert)\([[:space:]]*(false\|"not implemented")` | `push_error("not implemented")` |

`unreachable!()` is in the `stub-todo` row because it is the same panic with
a different name on it, and the case where it is right (an exhaustive match
the compiler cannot prove) is one `## Suppressions` line. The `stub-raise`
row has one legitimate use, the abstract method, and that is AC-2's control:
C-3 says how it is excluded.

**C-2. The non-matching corpus:** `const msg = "todo!()"` (the `(` is there,
but `O` is not: the `t` follows `"`); `let unimplemented = 0;`;
`fn todo_later()`; `} catch (e) { log(e) }`; `except ValueError:` followed by
`    retries += 1` and then `    pass` (the `pass` is the third line, not the
second); the `@abstractmethod` case of C-3.

**C-3. The two-line matcher, `empty-handler`.** Not a table row: 3j's
per-file awk keeps the previous added line and its line number, and refuses
when the previous added line matches an **opener** and the current added line
is a **closer**, both from the same file, with nothing but whitespace (or a
lone `{` on the opener's line) between. Openers: `O(catch\|except)\b[^{:]*(\{|:)[[:space:]]*$`
(a `catch (e) {`, `catch {`, `except:`, `except Foo as e:`). Closers:
`^[[:space:]]*\}[[:space:]]*$` after a `{`-opener, `^[[:space:]]*pass[[:space:]]*(#.*)?$`
after a `:`-opener. Two consecutive **added** lines means the diff's `+` lines
are adjacent with no hunk header between them; an opener added with the
closer as context is pre-existing shape and is not refused (AC-3's control),
and so is `catch (e) { log(e) }` on one line. The refusal names the opener's
line and the rule id `empty-handler`. The `@abstractmethod` exclusion:
when the previous added line matches `O@(abc\.)?abstractmethod`, a following
`def` line's `stub-raise` on the line after that is not refused - a
three-line window, decorator / def / raise, and the only context-sensitive
rule in the block. RED may propose a narrower spelling; it may not drop the
exclusion, because an abstract base class is the one idiom in which the
needle is the correct implementation.

**C-4. What does not change.** 3j's walk, phase test, category test,
`--unified=0` reading, refusal text and `## Suppressions` matching are
HARNESS-081's and this story does not edit those lines; `plan.sh conflicts`
will call this story and HARNESS-083 a `CONFLICT` on `check-boundaries.sh`,
which is correct - they run one after the other, and both after HARNESS-081.

**C-5. Oracle partition.** All **mechanical**. The rows and ids in C-1 are
**settled**; RED may tighten an ERE and must not drop a row or the
`abstractmethod` exclusion.

**C-6. Self-test and floor.** New rows go into HARNESS-081's table-driven
loops in `boundaries.test.sh` (positive and negative); AC-3 gets its own
`describe` because its fixture adds two lines. `floors.conf`'s `boundaries`
floor rises in RED to the measured count. `VERSION` bumps in GREEN.

**Test-only dependencies:** none.

## Deferred verifications

**DV-1 (defect put back; central claim; AC-3). Owner: GATES.** With GREEN in
the tree, `bash scripts/mutate.sh scripts/check-boundaries.sh '<expr>' --
bash scripts/selftest.sh boundaries`, where `<expr>` removes the adjacency
requirement from the `empty-handler` matcher (so an opener anywhere earlier in
the file arms it). AC-3's control - closer added under a context opener -
**must** go red, and nothing else. Paste the red, the restore, and a green
run. RED cannot run this; the matcher does not exist yet.

**DV-2 (the rule against a real line; needle rule). Owner: GATES.** The
real line is `scripts/check-boundaries.sh` itself after GREEN: it contains
every stub spelling inside the table, on `harness`-classified lines. Run
`GITHUB_HEAD_REF= PR_HEAD_SHA= bash scripts/check-boundaries.sh origin/main`
on this branch and paste that 3j prints no `FAIL`. Then, with `mutate.sh`
widening 3j's category test to include `harness`, the same command **must**
refuse the real table lines by path and line - and the paste shows **which
rule id** fired on them, which is also a check that the ERE for `stub-throw`
does not match the table's own quoting of it in a way that names the wrong
row. Restore, re-run, paste.

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. check-boundaries.sh fails a PR whose criteria differ
     from their last committed PLANNED state (else the base branch) without an
     entry here. Omit the section if unused.
     Where the change came from a subagent's claim that the criterion was
     wrong, record the ORCHESTRATOR'S OWN reproduction of it - different
     inputs, not the subagent's code. That claim is also what an agent says
     when it wants to stop failing. -->

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-082` from `.claude/harness/models.conf`.
A PLAN, not a record: a session setting or an explicit override can beat both
this and the agent's own `model:` field, and nothing here can see which won.
The orchestrator still writes down the model each dispatch **resolved** to, by
name, below the table.

| Phase | Agent | Planned | Why |
|---|---|---|---|
| PLANNED | `lead-po` | `fable` | planning is the judgement phase - decomposition, the oracle partition, the contract - and planning is what fable is judged best at |
| RED | `test-developer` | `opus` | writing the failing tests, the negative controls and the handoff is development work, and opus is judged the stronger model for it |
| GREEN | `feature-developer` | `opus` | the failure mode of a weaker model here is reaching green by weakening a test, which is the one thing this harness exists to prevent |
| GATES | `feature-developer` | `opus` | same risk as GREEN, and a gate failure is where "make it stop complaining" is most tempting |
| REVIEW | `lead-po` | `fable` | reading review feedback against the contract is orchestration judgement, and a wrong call here ships; a fix it finds goes back to GATES or RED, on opus |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation - code, with no failing test in front of any of it, so the stronger development model |

**Resolved:**

- PLANNED - `lead-po`, planned `fable`, resolved **claude-fable-5-1** (2026-10-28). The story was cut and the Contract, Deferred verifications and Out of scope written in this dispatch; no override reported.

**Oracle partition:** every criterion is mechanical (an exact message, an exit status, a table row); the needle/finding tables are settled and RED may tighten but not drop a row. See the Contract.

## Out of scope

- **Comment directives** - HARNESS-081's rows; nothing in that table is
  edited here.
- **A gate loosened in `project.conf`** - HARNESS-083.
- **Stubs that are tested.** A `todo!()` the suite reaches fails the suite; a
  `throw new Error("not implemented")` behind a feature flag with a test
  asserting it throws is a legitimate design, and is declared in
  `## Suppressions` in one line. This rule cannot tell the two apart and does
  not try; it makes the line visible.
- **`TODO` and `FIXME` comments**, `console.log`, `debugger`, `dbg!()`,
  `print(` - noise, not weakening; a linter's job.
- **Handlers that swallow with a comment** (`catch (e) { /* ignore */ }`) -
  the comment is a body, and the matcher stops at "nothing but whitespace".
  Widening to "a body that is only a comment" is a decision for the user, not
  for this story, because it is exactly where the false positives start.
- **Pre-existing stubs** on `main`, and stubs removed or moved; only added
  lines are read, as in HARNESS-081.
- **Other languages' stubs** (`NotImplementedException`, `panic("TODO")`) -
  a project's bootstrap story adds its row.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

## Handoff: RED -> GREEN

<!-- Filled by the Test Developer at the end of RED. This is the ONLY channel
     to the Feature Developer, whose context is fresh. Must contain:
       * the exact command that runs the new tests
       * the failure output, and why it is the RIGHT failure
       * every file touched, and which AC each test covers
       * the EXPORT SHAPE the tests already pin: every module they import, the
         exact exported names and signatures, and the types the assertions
         destructure. Not a suggestion - a test already imports them, so a
         wrong guess is a compile error. Say what the tests do NOT constrain
         too, so it stays the implementer's choice.
       * any test that passed on arrival, and the probe or negative control
         that earns it
       * the EXPECTED VALUE of every negative control, as a table: threshold,
         candidate range, and the number the control measured. In RED the
         suite fails at import, so no assertion in it has run - the controls
         are claims until GREEN confirms them against the shipped module
       * anything discovered that changes the approach -->

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. A test that is wrong is never edited into passing, and the
     return is not a footnote - it is the story failing to be one clean cycle,
     and the next person needs to know why. One block per return:
       * which test, what it asserted, and what was wrong with it
       * how the defect was found
       * what it asserts now
       * what earns it, since "watched it fail" cannot apply once the
         implementation exists - the corrected assertion passes on its first
         run and every run after, whether or not it asserts anything: either a
         PROBE (mutate the specific behaviour the test pins, paste the red,
         confirm the revert) or, where the defect was cost rather than
         correctness, a BEFORE/AFTER measurement taken under the gate command -
         not the plain test command, which is the faster one.
         PASTE THE OUTPUT. check-boundaries.sh refuses a PR whose Regressions
         or Gate probes section describes a failure without showing one.
         A result counts only as a block: a line beginning with three
         backticks or three tildes (a fence), or a line indented by exactly
         four spaces. Prose does not count, nor inline code in backticks, nor
         a tab, nor anything inside an HTML comment
       * whether GREEN was a no-op, and the command output proving the source
         was untouched and still passes -->

## Gate results

<!-- Written by scripts/gates.sh itself on every full run, stamped with the
     commit and a hash of the code it ran against. Do not paste or edit it:
     check-boundaries.sh refuses a PR whose recorded run does not match the
     code being merged. -->

## Gate probes

<!-- REQUIRED if this story adds or changes a gate, its command, or its
     evidence line. Omit the section entirely otherwise.
     A gate that has never been observed to fail is not a gate: break the thing
     it guards, run the gate, paste the failure, revert. A result counts
     only as a block: a line beginning with three backticks or three tildes
     (a fence), or a line indented by exactly four spaces. Prose does not
     count, nor inline code in backticks, nor a tab, nor anything inside an
     HTML comment. One block per gate:
       * what was broken, and where
       * the gate output proving it failed
       * confirmation the probe was reverted -->

## Scaffold inventory

<!-- REQUIRED for a bootstrap or chore story that writes production code under
     SCAFFOLD, where nothing forces a test to exist first, and for a spike that
     commits its throwaway code. Omit otherwise.
     One line per production file written, and for anything with behaviour
     rather than configuration, the test that covers it:
       src/core/palette.ts        - src/core/palette.test.ts
       vite.config.ts             - configuration, no behaviour
     check-boundaries.sh refuses the PR if any changed source file is not
     named here. -->

## Notes

