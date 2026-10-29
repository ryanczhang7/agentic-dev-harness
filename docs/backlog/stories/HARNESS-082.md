---
id: HARNESS-082
title: A stub added to source in GREEN or GATES is refused unless the story declares it
slug: a-stub-added-to-source-in-green-or-gates
epic: 
type: feature
status: in-progress
phase: GATES
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

**C-1. Rows appended to `suppression_needles()`** (HARNESS-081 C-2). The
anchor for a stub is not HARNESS-081's comment-opener class: a stub is an
expression, so it follows `(`, `=`, `>`, `,`, `|` as readily as whitespace.
`O` for every row below is `` (^|[^A-Za-z0-9_"'`]) `` - anything but an
identifier character or a quote (double, single or backtick) - so `foo(todo!())`, `_ => todo!()` and
`x = todo!();` are caught, `const msg = "todo!()"` and `my_todo!(` are not.
(Refined at PLANNED → RED from `(^|[[:space:]])`; see Notes, PO decision 2.)

| rule id | ERE (after `O`, where shown) | example added line |
|---|---|---|
| `stub-throw` | `` Othrow[[:space:]]+(new[[:space:]]+)?(NotImplementedError[[:space:]]*\(|Error[[:space:]]*\([[:space:]]*["'`][[:space:]]*([Nn]ot[[:space:]]*[Ii]mplemented|TODO|[Uu]nimplemented)) `` | `throw new Error("not implemented")` |
| `stub-todo` | `O(todo\|unimplemented\|unreachable)!\(` | `todo!()` and `unimplemented!("later")` |
| `stub-raise` | `Oraise[[:space:]]+NotImplementedError([[:space:](]\|$)` | `raise NotImplementedError` |
| `stub-gd` | `O(push_error\|assert)\([[:space:]]*(false\|"not implemented")` | `push_error("not implemented")` |

The `stub-throw` row takes `throw Error(` without `new`, a `TypeError`-free
spelling (a custom `NotImplementedError(` class, any message), and
`Not implemented` / `NotImplemented` in any case, because those are the
spellings a project actually writes and a row that misses the common one is
not a rule. `unreachable!()` is in the `stub-todo` row because it is the same
panic with a different name on it, and the case where it is right (an
exhaustive match the compiler cannot prove) is one `## Suppressions` line.
The `stub-raise` row has one legitimate use, the abstract method, and that is
AC-2's control: C-3 says how it is excluded.

**Known false positives, accepted, not controlled:** a *comment* quoting a
stub (`// TODO: replace the todo!() below`, `# raise NotImplementedError was
here`) is refused, because the rows read a line, not a token stream, and a
`## Suppressions` line clears it. No corpus line may assert the opposite.

**C-2. The non-matching corpus:** `const msg = "todo!()"` (the `(` is there,
but `O` is not: the `t` follows `"`); `let unimplemented = 0;`;
`fn todo_later()`; `my_todo!(x)`; `} catch (e) { log(e) }`; `except ValueError:`
followed by `    retries += 1` and then `    pass` (the `pass` is the third
line, not the second); `throw new Error("no such user")`;
`raise NotImplementedErrorSubclass()` (the tail guard); the `@abstractmethod`
case of C-3.

**C-3. The two-line matcher, `empty-handler`.** Not a table row:
`suppression_hits`' awk keeps a one-line window over the **added** lines of
the file it is reading - the previous `+` line's text and line number - and
emits `<opener line no>|empty-handler|<opener text, trimmed>` when the
previous added line is an **opener** and the current added line is its
**closer**. Exact pins:

- **Brace opener:** `Ocatch([[:space:]]*\([^)]*\))?[[:space:]]*\{[[:space:]]*$`
  - `} catch (e) {`, `catch {`, `catch (e: unknown) {`, `catch (Exception e) {`.
  **Brace closer:** `^[[:space:]]*\}` - a line that *begins* with `}` after
  whitespace, whatever follows it, because `} finally {` directly under a
  `catch (e) {` is the same empty handler as a lone `}`.
- **Colon opener:** `^[[:space:]]*except([[:space:]]+[^:]+)?:[[:space:]]*(#.*)?$`
  - `except:`, `except Foo as e:`, `except (A, B):  # noqa`.
  **Colon closer:** `^[[:space:]]*(pass|\.\.\.)[[:space:]]*(#.*)?$`.
- **Allman braces** (`catch (e)` / `{` / `}`): an opener whose line does not
  end in `{` is **not** an opener. A `.catch(() => {` / `})` promise handler
  is likewise not matched - both are out of scope here, and a row for either
  is a later story's. The parenthetical "a lone `{`" in the first cut of this
  block is withdrawn; two consecutive added lines means exactly two.
- **Adjacency** is in the diff, not the file: the two `+` lines follow one
  another in one hunk. Only a hunk header (`@@`) or the end of the diff
  clears the window; a `-` line never sits between two `+` lines, because
  `--unified=0` prints a hunk's `-` lines before its `+` lines, so two added
  lines that replace two removed ones are still adjacent `+` lines. An
  opener that is context (not added) is never in the window, so a closer
  added under it is not refused (AC-3's control), and `catch (e) { log(e) }`
  on one line matches no opener.
- **The refusal** names the opener's line number and quotes the opener's
  trimmed text; its rule id is `empty-handler`; it is declared like any row,
  `path [empty-handler] approved by`.
- **Precedence:** a line is tested against the table rows first (first row
  wins, as HARNESS-081 pins) and then as an opener/closer; a `pass` or `}`
  that also matched a row is already reported and is not reported twice.
  In practice no row matches those lines.

**The `@abstractmethod` exclusion** is the same window, two lines deep: a
`stub-raise` hit on added line *n* is suppressed when added line *n-1*
matches `^[[:space:]]*(async[[:space:]]+)?def[[:space:]]` and added line
*n-2* matches `^[[:space:]]*@(abc\.)?abstractmethod`, all three adjacent `+`
lines in one hunk. **Added lines only**, as everything in 3j: a `raise
NotImplementedError` that replaces a `pass` under a pre-existing decorator is
refused, because the decorator is not in the diff, and is declared in one
line. RED may propose a narrower spelling; it may not drop the exclusion,
because an abstract base class is the one idiom in which the needle is the
correct implementation.

**C-4. What does not change.** 3j's walk, phase test, category test,
`--unified=0` reading, `## Suppressions` matching and the **refusal text**
are HARNESS-081's and this story does not edit those lines. The refusal for a
stub therefore reads `added a suppression to '<path>' line <n> [stub-todo]:
<line>. GREEN and GATES may not silence a tool...` - the word *suppression*
stays, byte for byte, so `want_3j` in the suite pins every row the same way
(PO decision 1 in Notes; rewording the message is a later story's, with
every pinned line in the suite moving with it). `plan.sh conflicts` calls
this story and HARNESS-083 a `CONFLICT` on `check-boundaries.sh`, which is
correct - they run one after the other, and both after HARNESS-081.

**C-5. Oracle partition.** All **mechanical**. The rows and ids in C-1 are
**settled**; RED may tighten an ERE and must not drop a row, a corpus line
or the `abstractmethod` exclusion. No criterion has a measured number.

**C-6. Self-test and floor.** New positive rows go into `AC2_ROWS` and new
corpus lines into `C3_ROWS` in `boundaries.test.sh` (the table-driven loops
HARNESS-081 left for exactly this); AC-3 and the `@abstractmethod` control
get their own `describe` blocks because their fixtures add two or three
lines in one commit, which `source_story`'s one-line shape cannot. AC-4 and
AC-5 reuse `source_story`. `floors.conf`'s `boundaries` floor rises in RED
to the measured count, with the measured line pasted in the comment as every
raise before it. `VERSION` bumps to 101 in GREEN.

**C-7. Callers of what changes.** No exported name or signature changes.
`suppression_needles` gains rows; `suppression_hits` gains state inside its
awk and keeps its output shape `<line no>|<rule id>|<text>`; both are called
only at `scripts/check-boundaries.sh:772` and `:812`, and nothing else in the
tree names them (`grep -rn suppression_ --include=*.sh --include=*.md`,
checked 2026-10-29: the only other mention is this story). The suite drives
the script, never the functions.

**Test-only dependencies:** none.

## Deferred verifications

**DV-1 (defect put back; central claim; AC-3). Owner: GATES.** With GREEN in
the tree, `bash scripts/mutate.sh scripts/check-boundaries.sh '<expr>' --
bash scripts/selftest.sh boundaries`, where `<expr>` removes the adjacency
requirement from the `empty-handler` matcher, so that an opener stays armed
across later added lines (the window is not cleared by an added line that is
not a closer). The control of
`describe "HARNESS-082 AC-2/AC-3 controls: ..."` named
`an except whose next added line is a statement` **must** go red, and so must
that branch's `rc|FAIL lines|summary` assertion; no positive assertion may
go red. Paste the red, the restore, and a green run. RED cannot run this; the
matcher does not exist yet.

*Corrected in RED (2026-10-29).* The first cut said AC-3's context-opener
control would go red. It cannot: 3j reads `git show --unified=0`
(`scripts/check-boundaries.sh:807`, frozen by C-4), so a context line never
reaches the awk, and no adjacency rule can see the opener that control
leaves on main. The test-developer reported this from a scratch 3j; the
orchestrator confirmed it independently from the shipped reading at line
807, not by re-running that scratch. The context-opener control stays in the
suite and is earned by what it pins (only added lines are read), which
HARNESS-081's AC-4 already earned for the same reading.

**DV-1 result (GATES, 2026-10-29, on 31a3195).** Run against the 3j subset
of the frozen suite (`boundaries.test.sh` lines 1-109 plus its whole 3j
section, verbatim but for an absolute `_lib.sh` path; 163 assertions), the
narrowest command holding the assertion. Exactly the two named assertions
went red, nothing else; restored and green.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by /^        pk = ""$/d) ===
  788 -         pk = ""
    FAIL HARNESS-082 control: an except whose next added line is a statement (src/app.py) is not refused
         actual:   FAIL  story T-1: commit 2debb48 (GREEN) added a suppression to 'src/app.py' line 2 [empty-handler]: retries += 1. GREEN and GATES may not silence a tool ...
    FAIL HARNESS-082 controls: the branch - rc|FAIL lines|summary(6)
boundaries: 161 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261029T141011Z.1033.bak) ===
##### the same subset, restored
boundaries: 163 passed, 0 failed
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

**DV-2 (the rule against a real line; needle rule). Owner: GATES.** The
table's own rows are EREs, not stubs - `(todo|unimplemented|unreachable)!\(`
does not match itself - so the real lines are the **example lines GREEN
quotes in 3j's block comment** when it documents the new rows (it must quote
each of C-1's four examples and C-3's two openers verbatim, one per line, so
that this probe has a real line per rule). They are added by this story's
GREEN commit to `scripts/check-boundaries.sh`, a `harness` path, which 3j's
category test skips. Run `GITHUB_HEAD_REF= PR_HEAD_SHA= bash
scripts/check-boundaries.sh origin/main` on this branch and paste that 3j
prints no `FAIL`. Then, with `mutate.sh` widening the category test at
`case "$(classify "$f")" in source|config)` to `source|config|harness`, the
same command **must** refuse each quoted example by path and line, and the
paste shows **which rule id** fired on each - the check that `stub-throw`'s
ERE, which quotes `Error(` and a quote character, names its own row and not
another. Restore (`mutate.sh` verifies it), re-run, paste the clean run.
An example line the widened rule does *not* refuse is a row that cannot see
the spelling it documents, and is a defect, not a WAIVED. Expect also one
`stub-todo` on the prose line quoting `foo(todo!())` (C-1's accepted comment
false positive).

*Corrected in GREEN (2026-10-29): the two opener examples cannot fire, and
`empty-handler` gets its own real line.* An opener alone is never a hit, and
a closer must begin with `}`, `pass` or `...`, which no `#` comment line can
(`s ~ /^[[:space:]]*[}]/` in `suppression_hits`), so the quoted
`} catch (e) {` and `except Exception:` lines are documentation, not probes.
The feature-developer reported this; the orchestrator confirmed it from the
closer patterns in the shipped awk. The part above therefore covers the four
`stub-*` rows only. **DV-2b (`empty-handler` against a real line). Owner:
GATES.** The tree's real handler is
`.claude/skills/security-audit/validate-findings.cjs:322-324`, a
`} catch (error) {` with a one-line body. 3j judges commits, so this probe
feeds `suppression_hits` directly: extract the function from
`scripts/check-boundaries.sh`, give it the table, a `--8<-- diff` line and the
real file as one all-added hunk (`@@ -0,0 +1,N @@` and every line prefixed
`+`). Unmutated it **must** print no `empty-handler` line (both of the file's
catches have bodies). Under `bash scripts/mutate.sh
.claude/skills/security-audit/validate-findings.cjs '323d' -- <that command>`
it **must** print exactly `322|empty-handler|} catch (error) {` and no other
`empty-handler` line. Paste both and the restore.

**DV-2 and DV-2b result (GATES, 2026-10-29, on 31a3195).** Every quoted
example fired its own row (`stub-throw` at 701 names `stub-throw`); the two
extra `stub-todo` lines, 696 and 697, are prose quoting `todo!()` - C-1's
accepted comment false positive. Refusal tails elided.

```
##### DV-2 first half: the branch as it stands
(3j printed nothing matching)
##### DV-2 second half: category test widened to harness
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s/in source|config) sup_paths=/in source|config|harness) sup_paths=/) ===
  847 -     case "$(classify "$f")" in source|config) sup_paths="$sup_paths $f" ;; esac
  847 +     case "$(classify "$f")" in source|config|harness) sup_paths="$sup_paths $f" ;; esac
FAIL  story HARNESS-082: commit 31a3195 (GREEN) added a suppression to 'scripts/check-boundaries.sh' line 696 [stub-todo]: # backtick), spelled out in every stub row - so `foo(todo!())` and. [refusal tail elided]
FAIL  story HARNESS-082: commit 31a3195 (GREEN) added a suppression to 'scripts/check-boundaries.sh' line 697 [stub-todo]: # `_ => todo!()` are caught, and `"todo!()"` and `my_todo!(` are not. The rows read a line, not a token stream, so a COMMENT. [refusal tail elided]
FAIL  story HARNESS-082: commit 31a3195 (GREEN) added a suppression to 'scripts/check-boundaries.sh' line 701 [stub-throw]: #   throw new Error("not implemented"). [refusal tail elided]
FAIL  story HARNESS-082: commit 31a3195 (GREEN) added a suppression to 'scripts/check-boundaries.sh' line 702 [stub-todo]: #   todo!(). [refusal tail elided]
FAIL  story HARNESS-082: commit 31a3195 (GREEN) added a suppression to 'scripts/check-boundaries.sh' line 703 [stub-todo]: #   unimplemented!("later"). [refusal tail elided]
FAIL  story HARNESS-082: commit 31a3195 (GREEN) added a suppression to 'scripts/check-boundaries.sh' line 704 [stub-raise]: #   raise NotImplementedError. [refusal tail elided]
FAIL  story HARNESS-082: commit 31a3195 (GREEN) added a suppression to 'scripts/check-boundaries.sh' line 705 [stub-gd]: #   push_error("not implemented"). [refusal tail elided]
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261029T142128Z.21280.bak) ===
##### DV-2 restored
(3j printed no refusal)
##### DV-2b unmutated
all hits over .claude/skills/security-audit/validate-findings.cjs (773 lines): 0
(no empty-handler line)
##### DV-2b with line 323 (the catch body) deleted
=== mutate: .claude/skills/security-audit/validate-findings.cjs (1 line(s) changed by 323d) ===
  323 -           errors.push(`${p}.pattern: invalid regular expression`);
all hits over .claude/skills/security-audit/validate-findings.cjs (772 lines): 1
322|empty-handler|} catch (error) {
=== mutate: command exited 0; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_skills_security-audit_validate-findings.cjs.20261029T142245Z.23642.bak) ===
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

DV-2b's driver (scratch, not in the tree) evals `suppression_needles` and
`suppression_hits` straight out of `scripts/check-boundaries.sh` as shipped,
builds `diff --git` / `+++` / `@@ -0,0 +1,N @@` and the file with every line
prefixed `+`, and greps the output for `|empty-handler|`.

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
- PLANNED → RED refinement - `lead-po` (the orchestrating session), resolved **claude-fable-5-1** (2026-10-29): C-1's anchor and `stub-throw` widened, C-3 pinned line by line, C-7 and DV-2 rewritten against the shipped 3j.
- RED - `test-developer`, planned `opus`, resolved **claude-opus-5-5** (2026-10-29), as the agent reported; no override.
- GREEN - `feature-developer`, planned `opus`, resolved **claude-opus-5-5** (2026-10-29), as the agent reported; no override.

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
- **Allman-brace handlers** (`catch (e)` / `{` / `}`) and **promise handlers**
  (`.catch(() => {` / `})`) - three-line and call-shaped; C-3 says why.
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

One level: integration, through the script. Every test builds a real
two-branch fixture repository (HARNESS-081's spike fixture at REVIEW, so a
branch 3j does not refuse exits 0) and runs `bash scripts/check-boundaries.sh
main` in it; the suite never calls `suppression_needles` / `suppression_hits`
directly (C-7). Every refusal is pinned as a WHOLE output line (`whole_line`,
`grep -cxF`), every clean branch by `rc 0`, no `FAIL` line, and 3j's summary
over the exact number of commits it judged.

| Test (describe / loop) | Level | AC |
|---|---|---|
| `AC2_ROWS` +15 rows, refused by whole line in GREEN and GATES (HARNESS-081's AC-2 loop) | integration | AC-2 |
| `C3_ROWS` +10 lines, each not quoted in the output; branch rc 0, no FAIL, summary over 22 | integration | AC-2 control |
| `HARNESS-082 AC-1` - one branch, GREEN then GATES commit of `throw new Error("not implemented")` | integration | AC-1 |
| `HARNESS-082 AC-3` - `EH_ROWS`, 10 empty handlers (2 at GATES), plus 3 `stub-raise` pins of the exclusion's edges | integration | AC-3, AC-2 (exclusion edges) |
| `HARNESS-082 AC-2/AC-3 controls` - closer under a context opener (brace, colon), `except`/statement/`pass`, the two `@abstractmethod` spellings, a two-hunk commit | integration | AC-3 control, AC-2 control |
| `HARNESS-082 AC-4` - the AC-1 line declared `[stub-throw] approved by` | integration | AC-4 |
| `HARNESS-082 AC-5` - a removed `todo!()`, a replaced `unimplemented!()` | integration | AC-5 |

## Handoff: RED -> GREEN

Written by `test-developer`, running as **claude-opus-5-5** (no override in
the dispatch), 2026-10-29.

**Command:** `bash .claude/tests/boundaries.test.sh` (what `bash
scripts/selftest.sh boundaries` runs). Local, this host: 9m40s for the file.
There is no subset switch in the suite or in `selftest.sh` (its argument
selects a suite, not a describe); for iteration I ran a scratch copy holding
lines 1-109 (helpers, fixture) plus the HARNESS-081/082 section, which is
self-contained from its "known baseline on main" commit onward - 163
assertions, about 4 minutes. That scratch file is not in the tree.

**Failure output, full file, against the shipped `check-boundaries.sh`
(HARNESS-081's 3j, no stub rows):**

```
boundaries: 255 passed, 49 failed        (rc 1; 304 executed)

    FAIL AC-2 [stub-throw] (GREEN): the added line is refused by its whole line, naming stub-throw - src/main.ts: throw new Error("not implemented")
    ... one FAIL per new AC2_ROWS row and phase: 30 lines, the 15 rows below x GREEN/GATES
    FAIL AC-2: the table branch - rc|refusals (one per added line)|summary
         expected: 1|62|0
         actual:   1|32|0
    FAIL HARNESS-082 AC-1 (GREEN): the refusal names stub-throw, src/main.ts, line 2, the commit and GREEN
         expected: 1
         actual:   0
    FAIL HARNESS-082 AC-1 (GATES): the refusal names stub-throw, src/main.ts, line 3, the commit and GATES
    FAIL HARNESS-082 AC-1: rc|refusals|summary - refused twice, exit 1, and nothing calls it clean
         expected: 1|2|0
         actual:   0|0|1
    FAIL HARNESS-082 AC-3: GREEN, '} catch (e) {' then '}' in src/main.ts - refused by its whole line
    FAIL HARNESS-082 AC-3: GREEN, 'except Exception:' then 'pass' in src/app.py - refused by its whole line
    FAIL HARNESS-082 AC-3: GATES, '} catch (e) {' then '}' in src/main.ts - refused by its whole line
    FAIL HARNESS-082 AC-3: GATES, 'except Exception:' then 'pass' in src/app.py - refused by its whole line
    FAIL HARNESS-082 AC-3: GREEN, 'catch (e) {' then '} finally {' in src/main.ts - refused by its whole line
    FAIL HARNESS-082 AC-3: GREEN, 'catch {' then '}' in src/main.ts - refused by its whole line
    FAIL HARNESS-082 AC-3: GREEN, '} catch (e: unknown) {' then '}' in src/main.ts - refused by its whole line
    FAIL HARNESS-082 AC-3: GREEN, 'catch (Exception e) {' then '}' in src/main.ts - refused by its whole line
    FAIL HARNESS-082 AC-3: GREEN, 'except:' then '...' in src/app.py - refused by its whole line
    FAIL HARNESS-082 AC-3: GREEN, 'except Foo as e:' then 'pass  # swallowed on purpose' in src/app.py - refused by its whole line
    FAIL HARNESS-082 AC-3: stub-raise under a decorator and def that are context - refused by its whole line
    FAIL HARNESS-082 AC-3: stub-raise under an added def with no decorator - refused by its whole line
    FAIL HARNESS-082 AC-3: stub-raise under an added @staticmethod and def - refused by its whole line
    FAIL HARNESS-082 AC-3: the handler branch - rc|refusals (one per handler or raise)|summary
         expected: 1|13|0
         actual:   0|0|1
    FAIL HARNESS-082 AC-4: and the rule says the stub is declared
         expected: 1
         actual:   0
```

**Why it is the right failure.** Every red is an assertion about 3j's
output: a whole refusal line counted 0 where it must be 1, or a branch's
`rc|refusals|summary` reading `0|0|1` (exit 0, nothing refused, 3j calling
the branch clean) where it must be `1|N|0`. No fixture errors, no bash
errors: the same file run against a scratch 3j with the rows and matcher
(below) is `163 passed, 0 failed` for the section. The 49 reds are exactly the
48 new positive assertions plus HARNESS-081's AC-2 branch count, which moves
because the table it counts grew. Nothing outside the 3j section changed
state: the other 203 assertions pass as before.

`bash scripts/gates.sh --fast`: `All required gates passed (0 ran, 5
unconfigured, 0 known)` - every gate on this repository is UNCONFIGURED
(BOOTSTRAPPED=no), so it judges nothing; it is not a pass. `check-sigpipe.sh`
and `check-grep-count.sh` tree-wide: 0 findings.

**Files touched (RED):**

- `.claude/tests/boundaries.test.sh` - 15 rows appended to `AC2_ROWS`, 10
  to `C3_ROWS` (each block marked as HARNESS-082's), the AC-2 loop's
  assertion name now carries `<path>: <line>` so a failing row says which
  line (names only; the assertion is unchanged), and five new describes before
  `summary`. The section commits five files to the fixture's `main` and removes
  them at its end, leaving main as it found it.
- `.claude/tests/floors.conf` - `boundaries` 236 -> 304, measured line in the
  comment block.
- `.claude/tests/selftest.test.sh` - its hand-copied floor table, 236 -> 304.
- this story - `## Test plan`, this section.

**One line per test:**

- `AC2_ROWS` (AC-2), each refused in GREEN and in GATES by its whole line:
  `stub-throw` - `throw new Error("not implemented")`, `throw Error('Not Implemented')`,
  `  throw new NotImplementedError()`, ``const f = () => { throw new Error(`TODO: wire the cache`) }``,
  `throw new Error("unimplemented")`; `stub-todo` - `todo!()`, `unimplemented!("later")`,
  `    Some(todo!())`, `    _ => unreachable!(),`, `let x = todo!();`; `stub-raise` -
  `raise NotImplementedError`, `    raise NotImplementedError("later")`; `stub-gd` -
  `push_error("not implemented")`, `assert(false)`, `    assert( false, "unreachable")`.
  Paths: `src/main.ts`, `src/lib.rs`, `src/app.py`, `src/player.gd` - all
  `source` by `classify.sh` (checked).
- `C3_ROWS` (AC-2 control), each NOT quoted anywhere in the output, branch
  `rc 0`, no FAIL, summary over 22 commits: `const msg = "todo!()"`,
  ``const t = `unimplemented!()` ``, `let s = 'todo!()';`, `let unimplemented = 0;`,
  `fn todo_later()`, `my_todo!(x)`, `} catch (e) { log(e) }`,
  `throw new Error("no such user")`, `raise NotImplementedErrorSubclass()`,
  `assert(is_ready)`. No comment quoting a stub (C-1's accepted false positive).
- `HARNESS-082 AC-1` (AC-1): the GREEN commit's whole line at line 2, the GATES
  commit's at line 3, and `rc|refusals|summary` = `1|2|0`.
- `HARNESS-082 AC-3` (AC-3): ten `<opener>`/`<closer>` pairs appended as two
  consecutive lines in one commit, each refused by
  `want_3j <c> <PHASE> <path> <OPENER's line> empty-handler '<opener, trimmed>'`;
  plus three `stub-raise` pins (C-3 edges of the exclusion): a raise added
  under a decorator and def that are context on main (`src/iface.py` line 4),
  a raise under an added `def` with no decorator (`src/base.py` line 3), a
  raise under an added `@staticmethod`/`def` (`src/base.py` line 6); branch
  `rc|refusals|summary` = `1|13|0`.
- `HARNESS-082 AC-2/AC-3 controls` (AC-3 control, AC-2 control): five commits
  each NOT refused (`'<path>' line` absent from the output) - `}` added under a
  context `} catch (e) {`; `    pass` under a context `except Exception:`;
  `except ValueError:`/`    retries += 1`/`    pass`; `@abstractmethod`/`def
  area(self):`/`raise NotImplementedError` all added; `@abc.abstractmethod`/
  `async def load(self):`/`raise NotImplementedError("subclass")` all added -
  and one two-hunk commit (`} catch (e) {` at the top, `}` at the bottom, three
  unchanged lines between); branch `rc|FAIL lines|summary(6)` = `0||1`.
- `HARNESS-082 AC-4` (AC-4): the AC-1 line with
  `` - `src/main.ts` [stub-throw] approved by ryan: feature-flagged, the test asserts it throws ``
  - `rc|refusals` = `0|`, and the whole line
  `ok    suppression [stub-throw] in 'src/main.ts' is declared in ## Suppressions`.
- `HARNESS-082 AC-5` (AC-5): `src/stubs.rs` on main holds `todo!()` and
  `unimplemented!()`; one GREEN commit deletes the `todo!()` line, a second
  replaces `unimplemented!()` with `2`; `rc|refusals` = `0|` and the whole line
  `ok    GREEN/GATES added no suppression (2 commit(s) judged)`.

**Export shape the suite pins (stated as fact):**

- Rule ids, exactly: `stub-throw`, `stub-todo`, `stub-raise`, `stub-gd`,
  `empty-handler`. Each appears in the refusal as `[<id>]`.
- The refusal is HARNESS-081's, byte for byte (C-4): `FAIL  story T-1: commit
  <c7> (<PHASE>) added a suppression to '<path>' line <n> [<id>]: <text>.
  GREEN and GATES may not silence a tool to reach green; if this one is
  needed, declare it in ## Suppressions - one line carrying the path, the rule
  id and 'approved by <who>', with the reason - and say why in that line.`
- `suppression_hits` output keeps `<line no>|<rule id>|<text, trimmed>`; for
  `empty-handler`, `<line no>` is the **opener's** line number in the file as
  committed and `<text>` is the **opener's** text with leading and trailing
  whitespace removed (e.g. `} catch (e) {`, `catch (Exception e) {`,
  `except Foo as e:`). One emission per handler: each EH row draws exactly one
  refusal (the `1|13|0` count).
- A table row hit on a line is one refusal; the AC-2 count (`62`) is one per
  added line, so no stub line may also emit `empty-handler`.
- The `@abstractmethod` exclusion: suppressed when the two preceding ADDED
  lines in the same hunk are `^[[:space:]]*(async[[:space:]]+)?def[[:space:]]`
  then (above it) `^[[:space:]]*@(abc\.)?abstractmethod`; not suppressed when the
  decorator is context, absent, or `@staticmethod`.
- A hunk header clears the window (two-hunk control); a non-closer added line
  between opener and closer disarms it (`except`/statement/`pass` control).

**Not constrained** (implementer's choice): the awk's internal state names; a
flag versus a lookback for the exclusion; where in the table the four rows go
(they match lines no HARNESS-081 row does, so order among the rows is free);
whether the opener/closer EREs live in the awk or in the needle stream;
whether the `diff --git` line also clears the window (one file per
`git show` call); what happens to a docstring between `def` and `raise` (the
contract says n-1/n-2 exactly; the suite does not pin a docstring case either
way); whether `except (A, B):  # noqa` is reported as `noqa`, `empty-handler`
or both (not tested - C-3's precedence covers it, but no AC needs it).

**Controls that pass on arrival, and what earns each.** In RED the module
"exists" (HARNESS-081's 3j), so these ran and passed; they pass because 3j
has no stub rows yet, which says nothing. Each was earned outside the tree by
a scratch candidate - a copy of `scripts/check-boundaries.sh` with C-1's four
rows and a C-3 matcher in `suppression_hits`, copied into the fixture over the
shipped script (never into the tree) - first unmutated, then with one
mutation each. Section run (163 assertions), local:

| Control | Expected (shipped 3j) | Candidate | Mutation that earns it | Measured under the mutation |
|---|---|---|---|---|
| C3 corpus, 10 lines | pass | pass | `O` loses the quote exclusion (`[^A-Za-z0-9_]`) | 3 red: the three quoted-stub lines + corpus branch count |
| `except`/statement/`pass` | pass | pass | opener not disarmed by a non-closer added line (`pk = ""` -> `pk = pk`) | 2 red: that control + branch count |
| two-hunk commit | pass | pass | `@@` does not clear the window | 2 red: that control + branch count |
| `@abstractmethod`, both spellings | pass | pass | exclusion deleted | 3 red: both + branch count |
| (positive) raise under undecorated def / `@staticmethod` | red | pass | exclusion keyed on `def` only, decorator ignored | 3 red: both + AC-3 branch count |
| closer under a context opener (brace, colon) | pass | pass | none of the above: see "DV-1" below | - |
| AC-4 rc and refusals, AC-5 both | pass | pass | AC-5: reading `-` lines (not run in RED); AC-4: the `ok` line half is red today | - |

```
candidate (unmutated)        boundaries: 163 passed, 0 failed
m4  O without quotes         FAIL AC-2 control: 'const msg = "todo!()"' in src/main.ts is not refused
                             FAIL AC-2 control: 'const t = `unimplemented!()`' in src/main.ts is not refused
                             FAIL AC-2 control: 'let s = 'todo!()';' in src/lib.rs is not refused
                             FAIL AC-2 control: the corpus branch - rc|refusals|summary(22)
                             boundaries: 159 passed, 4 failed
m1a no disarm                FAIL HARNESS-082 control: an except whose next added line is a statement (src/app.py) is not refused
                             FAIL HARNESS-082 controls: the branch - rc|FAIL lines|summary(6)
                             boundaries: 161 passed, 2 failed
m1b @@ keeps window          FAIL HARNESS-082 control: an opener and a closer in two hunks of one commit are not refused
                             FAIL HARNESS-082 controls: the branch - rc|FAIL lines|summary(6)
                             boundaries: 161 passed, 2 failed
m2  exclusion deleted        FAIL HARNESS-082 control: an abstract method, all three lines added (src/shapes.py) is not refused
                             FAIL HARNESS-082 control: an abc.abstractmethod on an async def, all three lines added (src/shapes.py) is not refused
                             FAIL HARNESS-082 controls: the branch - rc|FAIL lines|summary(6)
                             boundaries: 160 passed, 3 failed
m2b exclusion on def only    FAIL HARNESS-082 AC-3: stub-raise under an added def with no decorator - refused by its whole line
                             FAIL HARNESS-082 AC-3: stub-raise under an added @staticmethod and def - refused by its whole line
                             FAIL HARNESS-082 AC-3: the handler branch - rc|refusals (one per handler or raise)|summary
                             boundaries: 160 passed, 3 failed
```

These were measured against MY candidate, not the shipped module: they are
claims about the suite's discrimination until GREEN's 3j is in and the same
mutations are rerun against it. The candidate's diff is not a suggestion of
how to write the matcher.

**DV-1 and DV-2: not runnable in RED, not claimed.** Both need GREEN's 3j in
the tree. **DV-1 as written will not see what it expects**, and this is a
finding for the orchestrator, not a change I have made: it says removing the
adjacency requirement makes "AC-3's control - closer added under a context
opener - go red, and nothing else". 3j reads `git show --unified=0`, so a
context line is never in the input: under the candidate with adjacency
removed (m1a) the context-opener control stayed GREEN, and the control that
went red was C-2's `except ValueError:`/`retries += 1`/`pass`. The
context-opener control can only be killed by an implementation that sees
context (a wider `--unified`, or reading the file), which C-4 freezes. Proposed
reading for DV-1: "the `except`/statement/`pass` control and the controls
branch count go red, and nothing else" - for the PO to decide; DV-1 is not a
Contract block and I have not edited it.

**Contract amendments:** none. Every C-1 ERE was exercised unchanged by the
candidate against every row and corpus line, under gawk 5.4.1 (local). CI's
mawk 1.3.4 was NOT available here; GREEN should note that the `O` class holds
both quote kinds and a backtick inside a single-quoted shell string.

**Floor:** `boundaries` 236 -> 304 (`floors.conf` and `selftest.test.sh`'s
copy). Measured: `boundaries: 255 passed, 49 failed` - 304 executed, local,
9m40s. The suite sits below its floor (255 < 304) until GREEN lands.

**For GREEN:** C-6 also asks for `VERSION` 101 in GREEN. DV-2 obliges you to
quote C-1's four example lines and C-3's two openers verbatim in 3j's block
comment, one per line.

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

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-29T14:23:15Z
    commit: 31a3195
    tree:   81ce29f69a312037e435ec57f6fee885df4682b2
    result: pass (0 ran, 7 unconfigured, 0 known)

    UNCONFIGURED format
    UNCONFIGURED lint
    UNCONFIGURED typecheck
    UNCONFIGURED unit
    UNCONFIGURED coverage
    UNCONFIGURED integration
    UNCONFIGURED build
    ON REQUEST   mutation (not run: per-story cost the user declined (HARNESS-015); run it with /audit-mutations; bash scripts/gates.sh --gate mutation)

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

**PO decisions at PLANNED → RED (2026-10-29):**

1. **The refusal keeps HARNESS-081's wording**, "added a suppression to",
   for a stub and an empty handler. A stub is not a suppression in the plain
   sense, but AC-1 asks for HARNESS-081's `FAIL` shape and C-4 freezes that
   text; rewording it means moving every `want_3j` line in the suite and is a
   story of its own. The user can overrule this before GREEN.
2. **The stub anchor is wider than the comment anchor.** HARNESS-081 anchors a
   directive on its comment opener; a stub is an expression and sits after
   `(`, `=>`, `=`, `,`. `O` became "anything but an identifier character or a
   quote", which keeps the string-literal control clean and catches
   `foo(todo!())`. The cost is a comment that quotes a stub, accepted in C-1.
3. **DV-2 as first cut could not run**: the table rows are EREs and do not
   match themselves, and the only lines this story adds to a non-`harness`
   path are fixtures the suite writes. It now reads the example lines GREEN
   quotes in the block comment, which obliges GREEN to quote them.
4. **Gate:** every gate in `project.conf` is unconfigured on this repository
   (`gates.sh --list`), as for every HARNESS story; the artifact is judged by
   `bash scripts/selftest.sh boundaries`, which CI's `gates` job runs, so it
   is required in the sense that matters. `required_gates` stays empty.
5. `epic:` is empty; there is no done-when to check against.

**GREEN (feature-developer, claude-opus-5-5, no override; 2026-10-29).**

Full run: `boundaries: 304 passed, 0 failed`, rc 0. The four rows are C-1's
EREs unchanged. The `empty-handler` window lives in `suppression_hits`' awk
(state `p1`, `p2`, `pk`, `pln`, `pt`); the brace opener is C-3's ERE with
`\{` spelled `[{]` and the closer `^[[:space:]]*[}]` (same language, no brace
escape for mawk to read as an interval); the opener anchor `O` is built in
`BEGIN` with `sprintf("%c", 39)` for the single quote, because the program is
a single-quoted shell string. Choices the handoff left open: a line that hit a
row is neither an opener nor a closer (it disarms the window); `diff --git`
and any non-`+`/`-`/`\` line clear the window as `@@` does; `-` lines do not.

mawk: CI's `mawk 1.3.4 20240123` was available through WSL. The two functions,
extracted from this tree and run under mawk and gawk 5.4.1 over one diff
holding every AC2/C3/EH line of the handoff, printed byte-identical output.
The suite itself ran under gawk only (Git Bash).

**Controls confirmed against the shipped 3j** (scratch subset of the suite:
lines 1-109 plus 1984-2673, 163 assertions, `163 passed, 0 failed`
unmutated; each mutation through `scripts/mutate.sh`, restored and verified):

| Row | Mutation (sed on `scripts/check-boundaries.sh`) | RED's number | Measured |
|---|---|---|---|
| m4 | `s/A-Za-z0-9_"[^]]*\]/A-Za-z0-9_]/g` (the four stub rows lose the quote exclusion) | 159/4 | 159/4, the same four |
| m1a | `s/^        pk = ""$/        if (0) pk = ""/` (no disarm) | 161/2 | 161/2, the same two |
| m1b | `/^    \/\^@@ \//s/ clear();//` (`@@` keeps the window) | 161/2 | 161/2, the same two |
| m2 | `/id\[k\] == "stub-raise"/d` (exclusion deleted) | 160/3 | 160/3, the same three |
| m2b | `s/ \&\& p2 ~ \/[^/]*\///` (exclusion on `def` only) | 160/3 | 160/3, the same three |
| AC-5 | `s#^    /^[\\][+]/ {$#    /^[-+]/ {#` (`-` lines read as added) | not run in RED | 159/4: AC-5's two and HARNESS-081's AC-4 two |

```
m4   FAIL AC-2 control: 'const msg = "todo!()"' in src/main.ts is not refused
     FAIL AC-2 control: 'const t = `unimplemented!()`' in src/main.ts is not refused
     FAIL AC-2 control: 'let s = 'todo!()';' in src/lib.rs is not refused
     FAIL AC-2 control: the corpus branch - rc|refusals|summary(22)
     boundaries: 159 passed, 4 failed
m1a  FAIL HARNESS-082 control: an except whose next added line is a statement (src/app.py) is not refused
     FAIL HARNESS-082 controls: the branch - rc|FAIL lines|summary(6)
     boundaries: 161 passed, 2 failed
m1b  FAIL HARNESS-082 control: an opener and a closer in two hunks of one commit are not refused
     FAIL HARNESS-082 controls: the branch - rc|FAIL lines|summary(6)
     boundaries: 161 passed, 2 failed
m2   FAIL HARNESS-082 control: an abstract method, all three lines added (src/shapes.py) is not refused
     FAIL HARNESS-082 control: an abc.abstractmethod on an async def, all three lines added (src/shapes.py) is not refused
     FAIL HARNESS-082 controls: the branch - rc|FAIL lines|summary(6)
     boundaries: 160 passed, 3 failed
m2b  FAIL HARNESS-082 AC-3: stub-raise under an added def with no decorator - refused by its whole line
     FAIL HARNESS-082 AC-3: stub-raise under an added @staticmethod and def - refused by its whole line
     FAIL HARNESS-082 AC-3: the handler branch - rc|refusals (one per handler or raise)|summary
     boundaries: 160 passed, 3 failed
AC-5 FAIL AC-4: a removed # noqa and an #[allow] left as context - rc|refusals
     FAIL AC-4: and the summary counts the two GREEN commits it judged
     FAIL HARNESS-082 AC-5: a removed todo!() and a replaced unimplemented!() - rc|refusals
     FAIL HARNESS-082 AC-5: and the summary counts both GREEN commits as judged
     boundaries: 159 passed, 4 failed
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

m1a is the same mutation DV-1 describes, run here against the subset only as
the handoff's control row; DV-1's run under `selftest.sh boundaries` is still
GATES'. The context-opener control has no mutation in this shape, as the
handoff says: `--unified=0` never delivers the context opener.

**For GATES - DV-2 cannot see `empty-handler` from a comment line.** The six
example lines are quoted one per line in 3j's block comment. Run over that
comment as added lines (the two functions, extracted, in a scratch harness;
not DV-2 itself), the four stub examples fire their own rows, and the two
opener examples fire nothing:

```
46|stub-throw|#   throw new Error("not implemented")
47|stub-todo|#   todo!()
48|stub-todo|#   unimplemented!("later")
49|stub-raise|#   raise NotImplementedError
50|stub-gd|#   push_error("not implemented")
```

An opener alone is not a hit, and a closer must *begin* with `}` or `pass`,
which no `#` comment line does, so no comment can carry an `empty-handler`
pair. DV-2's "an example line the widened rule does not refuse is a defect"
will therefore read two lines as defects that are the rule working as C-3
pins it. That is a DV-2 wording question for the PO, not a matcher change;
the empty-handler half is already pinned by AC-3's ten fixture pairs. Also
expect one extra `stub-todo` refusal under DV-2's widening, on the prose line
quoting `foo(todo!())` (C-1's accepted comment false positive).

