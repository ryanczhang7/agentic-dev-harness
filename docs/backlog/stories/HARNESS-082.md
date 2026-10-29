---
id: HARNESS-082
title: A stub added to source in GREEN or GATES is refused unless the story declares it
slug: a-stub-added-to-source-in-green-or-gates
epic: 
type: feature
status: in-progress
phase: RED
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
| `stub-throw` | `` Othrow[[:space:]]+(new[[:space:]]+)?(NotImplementedError[[:space:]]*\(|Error[[:space:]]*\([[:space:]]*["'`][^"'`]*([Nn]ot[[:space:]]*([Yy]et[[:space:]]*)?[Ii]mplemented|NOT[[:space:]]*IMPLEMENTED|TODO|[Uu]nimplemented)) `` | `throw new Error("not implemented")` |
| `stub-todo` | `O(todo\|unimplemented\|unreachable)!\(` | `todo!()` and `unimplemented!("later")` |
| `stub-raise` | `Oraise[[:space:]]+NotImplementedError([[:space:](]\|$)` | `raise NotImplementedError` |
| `stub-gd` | `O(push_error\|assert)\([[:space:]]*(false([^A-Za-z0-9_]\|$)\|"[Nn]ot[[:space:]]+implemented)` | `push_error("not implemented")` |
| `empty-handler` | `Ocatch([[:space:]]*\([^)]*\))?[[:space:]]*[{][[:space:]]*[}]` | `} catch (e) {}` |
| `empty-handler` | `^[[:space:]]*except([[:space:]]+[^:]+)?:[[:space:]]*(pass\|\.\.\.)[[:space:]]*(#.*)?$` | `except: pass` |

*Amended on the return to RED from GATES (2026-10-29, diff review round 1,
findings 2-4; approved by the user, "Fix 1, 2, 3, 5" and "Add rows here").*
`stub-throw` was `["'`][[:space:]]*(...)`, which missed TypeScript's own
quick-fix stub `throw new Error("Method not implemented.")`, and
`'not yet implemented'` and `"NOT IMPLEMENTED"`; the message may now carry a
prefix inside the quotes and a `yet`. `stub-gd` was `(false|"not implemented")`,
with no tail guard, so `assert(false_positives == 0)` was refused, and
`push_error("Not implemented")` was missed. The two `empty-handler` rows are
the **one-line** empty handler, which the C-3 window cannot see because its
opener must end in `{` or `:`; they carry the same rule id as the window, so
one `## Suppressions` line declares either shape. A one-line handler with a
body (`} catch (e) { log(e) }`, `except KeyError: retry()`) matches neither.
C-5's "RED may tighten, never widen" is overridden for these rows by that
approval.

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
case of C-3; and, from the return to RED, `assert(false_positives == 0)`,
`assert(falseCount === 0);`, `except KeyError: retry()` and
`throw new Error("could not open the file")`.

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
  In practice no row matches those lines. **An opener is armed whether or
  not its line hit a row** - only the *closer* test is skipped on a hit. So
  `except:  # noqa: E722` / `    pass` prints both `noqa` and
  `empty-handler`, each at the opener's line, and declaring `[noqa]` does not
  declare the empty handler. *(Amended on the return to RED from GATES,
  2026-10-29, diff review round 1 finding 1: GREEN armed an opener only on a
  line that hit no row, so one approved lint suppression silently approved
  the empty handler it sat on. This states what the precedence bullet
  already implied; the AC text is unchanged.)*
  **The same holds for every line of a handler** *(amended on the second
  return to RED, 2026-10-29, diff review round 2 finding 1, under the user's
  round-1 approval of closing this hole; supersedes "only the closer test is
  skipped on a hit" and "a `pass` or `}` that also matched a row is already
  reported and is not reported twice")*. "In practice no row matches those
  lines" was false: `pass  # noqa: S110` and `} // eslint-disable-line` are
  real closers, and `} catch {} // eslint-disable-line no-empty` is the
  standard deliberate empty catch. So:
  (a) the **closer** test runs whether or not the closer's line hit a row -
  the row's refusal stays at the closer's line, and `empty-handler` is
  printed at the opener's;
  (b) a line whose winning row is **not** `empty-handler` is still tested
  against the two one-line `empty-handler` rows, and a match prints a second
  line, `<n>|empty-handler|<line, trimmed>`, after the winning row's;
  (c) **no duplicate**: a line that already reported `empty-handler` through
  a one-line row and is also armed as an opener (`} catch (A e) {} catch (B
  e) {` over `}`) does not get a second `empty-handler` from the window.
  The AC text is unchanged.

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

**DV-1, DV-2 and DV-2b re-run (GATES after return 1, 2026-10-29, on
2fc8ba9).** The tree changed, so all three ran again. DV-1 against the
regenerated subset (`sub2.test.sh`, confirmed a verbatim slice of the
committed suite by `diff`, 187 assertions): exactly the same two assertions
red, restored and green.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by /^      pk = ""$/d) ===
  801 -       pk = ""
    FAIL HARNESS-082 control: an except whose next added line is a statement (src/app.py) is not refused
    FAIL HARNESS-082 controls: the branch - rc|FAIL lines|summary(6)
boundaries: 185 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261029T185750Z.141457.bak) ===
##### the same subset, restored
boundaries: 187 passed, 0 failed
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

DV-2: unmutated, 3j printed nothing. Widened to `harness`, every quoted
example fired its own row, the new `} catch (e) {}` example (line 706) as
`empty-handler`; the rest are prose or test-table lines quoting a stub or a
directive (C-1's accepted false positive). Restored, no refusal. DV-2b:
unchanged, `322|empty-handler|} catch (error) {` only under the mutation.

```
##### DV-2 second half: category test widened to harness
  859 +     case "$(classify "$f")" in source|config|harness) sup_paths="$sup_paths $f" ;; esac
FAIL  ... commit 2fc8ba9 (GREEN) ... 'scripts/check-boundaries.sh' line 706 [empty-handler]: #   } catch (e) {}
FAIL  ... commit 2fc8ba9 (GREEN) ... 'scripts/check-boundaries.sh' line 720 [empty-handler]: # rows are the ONE-line shape the window cannot see, `} catch (e) {}` and
FAIL  ... commit 2fc8ba9 (GREEN) ... 'scripts/check-boundaries.sh' line 772 [noqa]: # opener, so `except:  # noqa: E722` over `pass` prints both `noqa` and
FAIL  ... commit 8bf26af (RED, after GATES) ... '.claude/tests/boundaries.test.sh' lines 2188-2193, 2589, 2600, 2601 [stub-throw x3, stub-gd, empty-handler x2, eslint-disable, noqa, coverage-ignore]: the return-1 test table rows
FAIL  ... commit 31a3195 (GREEN) ... 'scripts/check-boundaries.sh' line 701 [stub-throw]: #   throw new Error("not implemented")
FAIL  ... commit 31a3195 (GREEN) ... line 702 [stub-todo]: #   todo!()
FAIL  ... commit 31a3195 (GREEN) ... line 703 [stub-todo]: #   unimplemented!("later")
FAIL  ... commit 31a3195 (GREEN) ... line 704 [stub-raise]: #   raise NotImplementedError
FAIL  ... commit 31a3195 (GREEN) ... line 705 [stub-gd]: #   push_error("not implemented")
FAIL  ... commit 31a3195 (GREEN) ... lines 696, 697 [stub-todo]: prose quoting todo!()
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261029T191556Z.191363.bak) ===
##### DV-2 restored
(3j printed no refusal)
##### DV-2b unmutated
all hits over .claude/skills/security-audit/validate-findings.cjs (773 lines): 0
(no empty-handler line)
##### DV-2b with line 323 (the catch body) deleted
all hits over .claude/skills/security-audit/validate-findings.cjs (772 lines): 1
322|empty-handler|} catch (error) {
=== mutate: command exited 0; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_skills_security-audit_validate-findings.cjs.20261029T191817Z.197215.bak) ===
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

(Lines condensed from the raw log at the scratchpad's `dv2-082r1.log`;
the refusal tails are elided.) The widened run also judged the RED-return
commit 8bf26af, labelled `RED, after GATES`: HARNESS-081's parent-phase arm
judges any commit whose first parent was GATES, which includes a return to
RED, not only the GATES -> REVIEW step it was written for. No refusal changes
under the real category test - the lock keeps source and config out of a RED
commit - but the label and the judged count are wrong. Follow-up list, not
this story (C-4 freezes the walk).

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
- GATES diff review round 1 - fresh `feature-developer`, planned `opus`, resolved **claude-opus-5-5** (2026-10-29); no override.
- RED (return 1) - `test-developer`, planned `opus`, resolved **claude-opus-5-5** (2026-10-29); no override.
- GREEN (return 1) - `feature-developer`, planned `opus`, resolved **claude-opus-5-5** (2026-10-29); no override.

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

### Return 1 - from GATES, after diff review round 1 (2026-10-29)

**What was wrong.** No test was wrong; the suite was *missing* cases, so
GREEN passed with four real gaps the review found and the orchestrator
reproduced (`## Diff review`, round 1, with the reproduction):

1. an opener on a line that also hits a row (`except:  # noqa: E722` /
   `pass`) was never armed, so no `empty-handler` - nothing in the suite
   puts a directive on an opener;
2. `stub-throw` missed `throw new Error("Method not implemented.")`
   (TypeScript's quick fix), `'not yet implemented'`, `"NOT IMPLEMENTED"`;
3. `stub-gd` refused `assert(false_positives == 0)` and missed
   `push_error("Not implemented")`;
4. a one-line empty handler (`} catch (e) {}`, `except: pass`) was not seen.

The user approved fixing 1-3 and adding rows for 4 in this story; finding 5
(a comment) is GREEN's; finding 6 goes to the follow-up list. C-1, C-2 and
C-3 are amended in place, each marked. The acceptance criteria are not
changed: every new row is AC-2's "every row of C-1's table", and finding 1 is
C-3's precedence bullet.

**What RED adds.** Positive rows for 2, 3 and 4 in `AC2_ROWS`; corpus lines
from C-2's amendment in `C3_ROWS`; a finding-1 case wherever the
empty-handler describe can count it (two refusals at the opener's line,
`noqa` and `empty-handler`). The floor rises to the measured count.

**What earns it.** Each new positive row and the finding-1 case are red
against the shipped GREEN (the code they need does not exist), which is an
ordinary RED; the output is pasted below by the test-developer. Corpus lines
that pass on arrival are earned by GREEN mutating the row or rule they pin.

#### Return 1, RED - test-developer (resolved claude-opus-5-5, no override)

**Files touched:** `.claude/tests/boundaries.test.sh` (additions only; no
existing assertion edited or reordered), `.claude/tests/floors.conf`
(`boundaries` 304 -> 328, with a comment entry), `.claude/tests/selftest.test.sh`
(its copy of the floor, 304 -> 328), and this section. No source file.

**How the rows were checked before they went in.** Not with the shipped
`suppression_needles` - that is the OLD table. The six C-1 EREs were copied
from the amended story text (markdown `\|` unescaped, `O` expanded to
`` (^|[^A-Za-z0-9_"'`]) ``) into a file and applied with `awk` dynamic regexes,
first row wins, after HARNESS-081's twelve rows from the shipped table; and the
two C-3 opener EREs the same way. gawk 5 only (mawk is not on this host).
Result: every new `AC2_ROWS` line hits exactly the rule id it is listed under
and no HARNESS-081 row first; every new `C3_ROWS` line hits nothing;
`except:  # noqa: E722` hits `noqa` and is a colon opener;
`} /* istanbul ignore next */ catch (e) {` hits `coverage-ignore` and is a
brace opener.

**New assertions, and the finding each covers** (all marked "HARNESS-082's
return 1" in the file):

| # | where | assertion | finding | on arrival |
|---|---|---|---|---|
| 1-6 | AC-2 table | `[stub-throw]` refused by whole line, GREEN and GATES: `throw new Error("Method not implemented.");`, `throw new Error('not yet implemented')`, `throw new Error("NOT IMPLEMENTED")` | 2 | red |
| 7-8 | AC-2 table | `[stub-gd]` `push_error("Not implemented")`, GREEN and GATES | 3 | red |
| 9-16 | AC-2 table | `[empty-handler]` one-line: `} catch (e) {}`, `} catch {}`, `except: pass`, `    except Exception: ...  # swallowed`, GREEN and GATES | 4 | red |
| 17 | C-2 corpus | `assert(false_positives == 0)` not refused | 3 | red (refused today) |
| 18 | C-2 corpus | `assert(falseCount === 0);` not refused | 3 | red (refused today: shipped `stub-gd` has no tail guard) |
| 19 | C-2 corpus | `except KeyError: retry()` not refused | 4 (control) | **passes** |
| 20 | C-2 corpus | `throw new Error("could not open the file")` not refused | 2 (control) | **passes** |
| 21 | AC-3 describe | `except:  # noqa: E722` / `    pass`: `[noqa]` at the opener's line, quoting the opener | 1 | **passes** |
| 22 | AC-3 describe | same commit: `[empty-handler]` at the opener's line, quoting the same text | 1 | red |
| 23 | AC-3 describe | `} /* istanbul ignore next */ catch (e) {` / `}`: `[coverage-ignore]` at the opener's line | 1 | **passes** |
| 24 | AC-3 describe | same commit: `[empty-handler]` at the opener's line | 1 | red |

Existing branch counts that now go red because the data grew (unedited): AC-2's
table branch (78 refusals expected, 62 today), the C-2 corpus branch (exit 0
and no FAIL; today two corpus lines are refused), and AC-3's handler branch
(17 refusals expected, 15 today).

**Deviation from the brief, for the orchestrator.** The brief asked for a brace
case `} catch (e) { // eslint-disable-line no-empty` / `}` refused as both
`[eslint-disable]` and `[empty-handler]`. Under C-3 as written that line is
**not an opener** - the brace opener ERE ends `[{][[:space:]]*$`, and this line
ends in `no-empty` (checked with awk: brace=0). Pinning it as `empty-handler`
would widen C-3 past its text, which is an amendment, not a test; pinning it as
NOT refused would assert a gap the review may want closed. So it is in
neither direction. The brace half of finding 1 is pinned instead with a
directive that leaves the line ending in `{`: `} /* istanbul ignore next */
catch (e) {` (`coverage-ignore`). If the trailing-directive brace form should
be an opener, that is a C-3 decision for the PO, and a later RED adds the row.

**The red, against the shipped GREEN** (release 101, f6c6447's 3j):
`bash .claude/tests/boundaries.test.sh`, local, 22m02s, rc 1. The summary line
and every FAIL line (the `expected/actual` detail lines elided except for the
three counts); no bash error anywhere in the output:

```
    FAIL AC-2 [stub-throw] (GREEN): the added line is refused by its whole line, naming stub-throw - src/main.ts: throw new Error("Method not implemented.");
    FAIL AC-2 [stub-throw] (GATES): the added line is refused by its whole line, naming stub-throw - src/main.ts: throw new Error("Method not implemented.");
    FAIL AC-2 [stub-throw] (GREEN): the added line is refused by its whole line, naming stub-throw - src/main.ts: throw new Error('not yet implemented')
    FAIL AC-2 [stub-throw] (GATES): the added line is refused by its whole line, naming stub-throw - src/main.ts: throw new Error('not yet implemented')
    FAIL AC-2 [stub-throw] (GREEN): the added line is refused by its whole line, naming stub-throw - src/main.ts: throw new Error("NOT IMPLEMENTED")
    FAIL AC-2 [stub-throw] (GATES): the added line is refused by its whole line, naming stub-throw - src/main.ts: throw new Error("NOT IMPLEMENTED")
    FAIL AC-2 [stub-gd] (GREEN): the added line is refused by its whole line, naming stub-gd - src/player.gd: push_error("Not implemented")
    FAIL AC-2 [stub-gd] (GATES): the added line is refused by its whole line, naming stub-gd - src/player.gd: push_error("Not implemented")
    FAIL AC-2 [empty-handler] (GREEN): the added line is refused by its whole line, naming empty-handler - src/main.ts: } catch (e) {}
    FAIL AC-2 [empty-handler] (GATES): the added line is refused by its whole line, naming empty-handler - src/main.ts: } catch (e) {}
    FAIL AC-2 [empty-handler] (GREEN): the added line is refused by its whole line, naming empty-handler - src/main.ts: } catch {}
    FAIL AC-2 [empty-handler] (GATES): the added line is refused by its whole line, naming empty-handler - src/main.ts: } catch {}
    FAIL AC-2 [empty-handler] (GREEN): the added line is refused by its whole line, naming empty-handler - src/app.py: except: pass
    FAIL AC-2 [empty-handler] (GATES): the added line is refused by its whole line, naming empty-handler - src/app.py: except: pass
    FAIL AC-2 [empty-handler] (GREEN): the added line is refused by its whole line, naming empty-handler - src/app.py: except Exception: ...  # swallowed
    FAIL AC-2 [empty-handler] (GATES): the added line is refused by its whole line, naming empty-handler - src/app.py: except Exception: ...  # swallowed
    FAIL AC-2: the table branch - rc|refusals (one per added line)|summary
         expected: 1|78|0
         actual:   1|62|0
    FAIL AC-2 control: 'assert(false_positives == 0)' in src/player.gd is not refused
    FAIL AC-2 control: 'assert(falseCount === 0);' in src/main.ts is not refused
    FAIL AC-2 control: the corpus branch - rc|refusals|summary(26)
    FAIL HARNESS-082 AC-3: GREEN, 'except:  # noqa: E722' then 'pass' in src/app.py, AND empty-handler at the opener although it hit [noqa] - refused by its whole line
    FAIL HARNESS-082 AC-3: GREEN, '} /* istanbul ignore next */ catch (e) {' then '}' in src/main.ts, AND empty-handler at the opener although it hit [coverage-ignore] - refused by its whole line
    FAIL HARNESS-082 AC-3: the handler branch - rc|refusals (one per handler or raise)|summary
         expected: 1|17|0
         actual:   1|15|0

boundaries: 305 passed, 23 failed
```

The two corpus FAILs' `actual` is the shipped refusal, e.g. `... added a
suppression to 'src/player.gd' line 2 [stub-gd]: assert(false_positives == 0).
...` - refused by the untailed `stub-gd`, which is finding 3 itself.

**Controls that pass on arrival, and the mutation that earns each** (GREEN or
GATES runs them against the shipped fix, through `scripts/mutate.sh`, against
`bash .claude/tests/boundaries.test.sh` or a subset holding the describe; the
exact sed text is GREEN's to write against its own lines - these name the
behaviour to break and what must go red):

| # | control | expected on arrival | measured | mutation that earns it | must go red |
|---|---|---|---|---|---|
| 19 | `except KeyError: retry()` clean | not refused | not refused (and awk: no row hits) | widen the one-line `except` row's body from `(pass\|\.\.\.)` to `.*` | this corpus line, and the corpus branch count |
| 20 | `throw new Error("could not open the file")` clean | not refused | not refused (awk: no row hits) | drop `([Yy]et[[:space:]]*)?[Ii]mplemented` from `stub-throw`'s `[Nn]ot` alternative, leaving `[Nn]ot` | this corpus line, and the corpus branch count |
| 21 | `[noqa]` at the opener of `except:  # noqa: E722` / `pass` | refused, line = opener | refused, whole line matched | make a row hit on an opener line NOT print (e.g. guard the row's `printf` with "not an opener") - the wrong way to fix finding 1 | #21 and #23, and the handler branch count |
| 23 | `[coverage-ignore]` at the opener of `} /* istanbul ignore next */ catch (e) {` / `}` | refused, line = opener | refused, whole line matched | the same mutation as #21 | as #21 |

And the "defect put back" for finding 1 itself (#22, #24): restore
`if (hit) pk = ""` as the only arming path, i.e. arm the opener only on a line
that hit no row - #22, #24 and the handler branch count go red. That is the
shipped GREEN as of f6c6447, so the red above is that mutation's output today.

**Floor:** `boundaries` 304 -> 328 (+24: 16 table, 4 corpus, 4 finding-1),
in `floors.conf` and in `selftest.test.sh`'s copy. Measured executed count
328 = 305 + 23. Until GREEN lands the suite sits below its floor (305 < 328) -
expected in RED.

#### Return 1, GREEN - feature-developer (resolved claude-opus-5-5, no override)

**What changed, all in block 3j of `scripts/check-boundaries.sh`.** No test
file touched (`git diff --quiet HEAD -- .claude/tests` exits 0). `VERSION`
stays `101 (2026-10-29)`.

- `suppression_needles()`: the `stub-throw` and `stub-gd` rows replaced by
  C-1's amended EREs, and the two `empty-handler` rows appended after
  `stub-gd`, copied from C-1 with markdown's `\|` unescaped and `O` expanded.
- `suppression_hits()`: the `if (hit) pk = "" else { ... }` is gone. The closer
  test is now `if (!hit && (...closer...)) printf ... empty-handler`; then, for
  every added line, `pk = ""` and the opener tests run unconditionally (C-3
  Precedence, amended). The `stub-raise` `@abstractmethod` exclusion is
  untouched (it still sets `hit` and breaks without printing).
- Review finding 5: the comment above `suppression_hits` now says a context
  line (and a hunk header or `diff --git` line) clears the window, and a `-`
  line or a `\ No newline` marker does not; and it states that a row hit is
  still tested as an opener.
- 3j's block comment: `#   } catch (e) {}` added to the verbatim example list,
  one line, after `#   push_error("not implemented")`; a paragraph on the
  widened `stub-throw` message and `stub-gd`'s tail guard; the empty-handler
  paragraph now says the one-line shape is two rows under the same id.
  **For DV-2's widened rerun:** the new prose lines quote
  `throw new Error("Method not implemented.")` and `} catch (e) {}` in
  backticks, so expect `stub-throw` and `empty-handler` refusals on those prose
  lines too - the same accepted comment false positive as the `todo!()` prose.

**Subset is still a verbatim slice.** `sub2.test.sh` (scratch, 847 lines) is
`HEAD:.claude/tests/boundaries.test.sh` lines 1-109 plus 1984-2721 (the whole
3j section, from the HARNESS-081 fixture `describe` to `summary`), with line 9
replaced by the absolute `_lib.sh` path:

```
$ { git show HEAD:.claude/tests/boundaries.test.sh | sed -n '1,109p'; git show HEAD:.claude/tests/boundaries.test.sh | sed -n '1984,2721p'; } | sed '9s#.*#. /d/agentic-dev-harness/.claude/tests/_lib.sh#' > sub2.expected; diff sub2.expected sub2.test.sh && echo IDENTICAL
IDENTICAL: sub2 == HEAD boundaries.test.sh 1-109 + 1984-2721, line 9 _lib path absolute
$ bash sub2.test.sh      # unmutated, against this GREEN
boundaries: 187 passed, 0 failed
```

**Controls earned.** Each through `bash scripts/mutate.sh
scripts/check-boundaries.sh '<expr>' -- bash sub2.test.sh`, output filtered to
the mutate lines, FAILs and the summary (`actual:` detail lines kept where the
suite printed them). Every expression was first dry-run on a scratch copy and
changes exactly one line.

Control #19 (`except KeyError: retry()` clean). The one-line `except` row's
body widened to `.*`. #19 and the corpus branch count go red, as the RED table
predicted. It also turns the bare colon openers (`except Exception:`,
`except ValueError:`) into row hits, because `.*` matches the empty tail, so
the AC-3 colon cases and the statement control go red too. That is a wider
mutation than one control, and it is the one the table named.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 752s/(pass|.*$/.*/) ===
  752 - empty-handler|^[[:space:]]*except([[:space:]]+[^:]+)?:[[:space:]]*(pass|\.\.\.)[[:space:]]*(#.*)?$
  752 + empty-handler|^[[:space:]]*except([[:space:]]+[^:]+)?:[[:space:]]*.*
    FAIL AC-2 control: 'except KeyError: retry()' in src/app.py is not refused
         actual:   FAIL  story T-1: commit a475962 (GREEN) added a suppression to 'src/app.py' line 6 [empty-handler]: except KeyError: retry(). GREEN and GATES may not silence a tool ...
    FAIL AC-2 control: the corpus branch - rc|refusals|summary(26)
    FAIL HARNESS-082 AC-3: GREEN, 'except Exception:' then 'pass' in src/app.py - refused by its whole line
    FAIL HARNESS-082 AC-3: GATES, 'except Exception:' then 'pass' in src/app.py - refused by its whole line
    FAIL HARNESS-082 AC-3: GREEN, 'except:' then '...' in src/app.py - refused by its whole line
    FAIL HARNESS-082 AC-3: GREEN, 'except Foo as e:' then 'pass  # swallowed on purpose' in src/app.py - refused by its whole line
    FAIL HARNESS-082 AC-3: the handler branch - rc|refusals (one per handler or raise)|summary
    FAIL HARNESS-082 control: an except whose next added line is a statement (src/app.py) is not refused
         actual:   FAIL  story T-1: commit bbeb41f (GREEN) added a suppression to 'src/app.py' line 1 [empty-handler]: except ValueError:. GREEN and GATES may not silence a tool ...
    FAIL HARNESS-082 controls: the branch - rc|FAIL lines|summary(6)
boundaries: 178 passed, 9 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261029T174822Z.1618.bak) ===
```

Control #20 (`throw new Error("could not open the file")` clean).
`stub-throw`'s implemented alternative cut to `[Nn]ot`. Exactly #20 and the
corpus branch count go red.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 747s/\[Nn\]ot\[\[:space:\]\]\*(\[Yy\]et\[\[:space:\]\]\*)?\[Ii\]mplemented/[Nn]ot/) ===
  747 - stub-throw|(^|[^A-Za-z0-9_"'`])throw[[:space:]]+(new[[:space:]]+)?(NotImplementedError[[:space:]]*\(|Error[[:space:]]*\([[:space:]]*["'`][^"'`]*([Nn]ot[[:space:]]*([Yy]et[[:space:]]*)?[Ii]mplemented|NOT[[:space:]]*IMPLEMENTED|TODO|[Uu]nimplemented))
  747 + stub-throw|(^|[^A-Za-z0-9_"'`])throw[[:space:]]+(new[[:space:]]+)?(NotImplementedError[[:space:]]*\(|Error[[:space:]]*\([[:space:]]*["'`][^"'`]*([Nn]ot|NOT[[:space:]]*IMPLEMENTED|TODO|[Uu]nimplemented))
    FAIL AC-2 control: 'throw new Error("could not open the file")' in src/main.ts is not refused
         actual:   FAIL  story T-1: commit 4657696 (GREEN) added a suppression to 'src/main.ts' line 12 [stub-throw]: throw new Error("could not open the file"). GREEN and GATES may not silence a tool ...
    FAIL AC-2 control: the corpus branch - rc|refusals|summary(26)
boundaries: 185 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261029T175326Z.13092.bak) ===
```

Controls #21 and #23 (the row's own refusal at an opener). A row hit no longer
prints when its line is a brace or colon opener (the wrong fix for finding 1).
Exactly #21, #23 and the handler branch count go red.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 796s@printf "%d|%s|%s@if (s !~ bo \&\& s !~ /^[[:space:]]*except([[:space:]]+[^:]+)?:[[:space:]]*(#.*)?$/) printf "%d|%s|%s@) ===
  796 -         printf "%d|%s|%s\n", ln, id[k], t
  796 +         if (s !~ bo && s !~ /^[[:space:]]*except([[:space:]]+[^:]+)?:[[:space:]]*(#.*)?$/) printf "%d|%s|%s\n", ln, id[k], t
    FAIL HARNESS-082 AC-3: GREEN, 'except:  # noqa: E722' then 'pass' in src/app.py, the row's own refusal [noqa] at the opener - refused by its whole line
    FAIL HARNESS-082 AC-3: GREEN, '} /* istanbul ignore next */ catch (e) {' then '}' in src/main.ts, the row's own refusal [coverage-ignore] at the opener - refused by its whole line
    FAIL HARNESS-082 AC-3: the handler branch - rc|refusals (one per handler or raise)|summary
boundaries: 184 passed, 3 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261029T175943Z.25554.bak) ===
```

Finding 1 put back (#22, #24). An opener is armed only on a line that hit no
row, which is f6c6447's behaviour. Exactly #22, #24 and the handler branch count
go red.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by /^      if (s ~ bo) pk = "brace"$/s/if (s ~ bo)/if (hit) ; else if (s ~ bo)/) ===
  802 -       if (s ~ bo) pk = "brace"
  802 +       if (hit) ; else if (s ~ bo) pk = "brace"
    FAIL HARNESS-082 AC-3: GREEN, 'except:  # noqa: E722' then 'pass' in src/app.py, AND empty-handler at the opener although it hit [noqa] - refused by its whole line
    FAIL HARNESS-082 AC-3: GREEN, '} /* istanbul ignore next */ catch (e) {' then '}' in src/main.ts, AND empty-handler at the opener although it hit [coverage-ignore] - refused by its whole line
    FAIL HARNESS-082 AC-3: the handler branch - rc|refusals (one per handler or raise)|summary
boundaries: 184 passed, 3 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261029T180705Z.38201.bak) ===
##### restored
check-boundaries.sh identical to the GREEN copy
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

**Measured against RED's controls table:** all four "expected on arrival" values
hold on the shipped module. #19 and #20 are not refused, and no row hits them
(the driver below prints `(none)`). #21 and #23 are refused at the opener's line
by their own row. No divergence, except that mutation #19 reaches further than
the table's "must go red" column says, for the reason given above.

**mawk vs gawk.** `suppression_needles` and `suppression_hits` were eval'd out
of a copy of this GREEN's script. A driver fed them 31 cases, each as one
all-added hunk: every new `AC2_ROWS` line, every C-2 corpus line (old and
amended), the finding-1 pairs, and the orchestrator's F1-F4 inputs. It ran once
under gawk on Git Bash and once under WSL with `awk` symlinked to
`/usr/bin/mawk`. The outputs are identical:

```
/tmp/mawkbin/awk
mawk 1.3.4 20240123
GNU Awk 5.4.1, API 4.1, PMA Avon 8-g1, (GNU MPFR 4.2.2, GNU MP 6.3.0)
gawk and mawk output IDENTICAL (31 cases, 34 result lines)
```

The output (identical under both), one `=== case` line then its hits:

```
=== ts quickfix          1|stub-throw|throw new Error("Method not implemented.");
=== not yet              1|stub-throw|throw new Error('not yet implemented')
=== NOT IMPL             1|stub-throw|throw new Error("NOT IMPLEMENTED")
=== orig throw           1|stub-throw|throw new Error("not implemented")
=== Not yet cap          1|stub-throw|throw new Error('Not yet implemented')
=== pe cap               1|stub-gd|push_error("Not implemented")
=== pe lower             1|stub-gd|push_error("not implemented")
=== assert false         1|stub-gd|assert(false)
=== catch one-line       1|empty-handler|} catch (e) {}
=== catch bare one-line  1|empty-handler|} catch {}
=== except pass          1|empty-handler|except: pass
=== except dots          1|empty-handler|except Exception: ...  # swallowed
=== except KeyError pass 1|empty-handler|except KeyError: pass
=== C corpus msg / C let / C fn / C my_todo / C catch body / C except 3 lines /
    C no such user / C subclass / C abstract / C false_positives / C falseCount /
    C retry / C could not                        (none), each
=== F1 noqa              1|noqa|except:  # noqa: E722
                         1|empty-handler|except:  # noqa: E722
=== F1 istanbul          1|coverage-ignore|} /* istanbul ignore next */ catch (e) {
                         1|empty-handler|} /* istanbul ignore next */ catch (e) {
=== F1 orch              3|noqa|except Exception:  # noqa: BLE001
                         3|empty-handler|except Exception:  # noqa: BLE001
=== two-line brace       1|empty-handler|} catch (err) {
=== finally closer       1|empty-handler|} catch (e) {
```

(Two columns here for length; the raw output is one line per row.)

**Full suite and checks, on this GREEN's working tree (uncommitted):**

```
$ bash .claude/tests/boundaries.test.sh        # local, 1136 s, no FAIL line anywhere
boundaries: 328 passed, 0 failed
rc=0
$ bash scripts/gates.sh --fast
All required gates passed (0 ran, 5 unconfigured, 0 known).    # not recorded: partial run
$ bash scripts/check-sigpipe.sh
check-sigpipe: scanned 56 shell file(s), 51 with pipefail, 0 finding(s)
$ bash scripts/check-grep-count.sh
check-grep-count: scanned 56 shell file(s), 0 finding(s)
$ bash scripts/mutate.sh --check
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

The full `bash scripts/gates.sh` run is not done here. It records a stamp
against the commit, so it belongs after the GREEN commit, and the
orchestrator does the committing.

### Return 2 - from GATES, after diff review round 2 (2026-10-29)

**What was wrong.** Again no test was wrong; the suite was missing cases.
Return 1 closed "an approved directive approves the empty handler" for the
**opener** line only. Round 2 found it open on the two other lines of a
handler, and the orchestrator reproduced it on different inputs
(`## Diff review`, round 2): a directive on a **one-line** handler
(`} catch {} // eslint-disable-line no-empty` reports only
`eslint-disable`), and a directive on a **closer** (`except ValueError:` /
`pass  # noqa: SIM105` reports only `noqa`). Plus a duplicate: a two-catch
line `} catch (A e) {} catch (B e) {` / `}` prints `empty-handler` twice at
the same line. C-3's Precedence bullet is amended in place, (a)-(c); the
acceptance criteria are unchanged.

**What RED adds.** For (a): a directive on a closer, both brace and colon
(`catch (err) {` / `} // eslint-disable-line`, `except ValueError:` /
`    pass  # noqa: SIM105`) - the directive's refusal at the closer's line
AND `empty-handler` at the opener's. For (b): a directive on a one-line
handler, both kinds (`} catch {} // eslint-disable-line no-empty`,
`except OSError: ...  # noqa: S112`) - the directive's refusal AND
`empty-handler`, both at that line. For (c): `} catch (IOException e) {}
catch (Exception e) {` / `}` - exactly ONE `empty-handler` refusal for that
line. Each assertion by whole line, and a branch count. The floor rises to
the measured count.

**What earns it.** Every (a) and (b) assertion and the (c) count are red
against 02e4b15, where the code does not exist; the test-developer pastes
that output below.

#### Return 2, RED - test-developer (resolved claude-opus-5-5, no override)

**Files touched:** `.claude/tests/boundaries.test.sh` (one new describe,
inserted between the AC-3 empty-handler describe and the AC-2/AC-3 controls
describe; no existing assertion edited or reordered), `.claude/tests/floors.conf`
(`boundaries` 328 -> 340, with a comment entry), `.claude/tests/selftest.test.sh`
(its copy of the floor, 328 -> 340), and this block. No source file.

**Why a describe of its own.** A branch of its own (`_src_branch`, cut from
the same main the AC-3 describe uses, so `src/main.ts` is one line and
`src/app.py` is absent) keeps every existing branch count where it was; none
of the existing fixtures holds a closer or a one-line handler that also hits a
row, so (a)-(c) move no existing count (checked against the AC-2 table, the
corpus, `EH_ROWS` and return 1's rows). The new branch's count is exact: 9
refusals, two per (a) and (b) commit and one for (c).

**New assertions, and the clause each covers** (all marked "HARNESS-082's
return 2" in the file; every one GREEN, one commit each):

| # | assertion | clause | on arrival |
|---|---|---|---|
| 1 | `catch (err) {` / `} // eslint-disable-line` in src/main.ts: `[eslint-disable]` at the closer's line (3), quoting `} // eslint-disable-line` | (a) control | **passes** |
| 2 | same commit: `[empty-handler]` at the opener's line (2), quoting `catch (err) {` | (a) | red |
| 3 | `except ValueError:` / `    pass  # noqa: SIM105` in src/app.py: `[noqa]` at the closer's line (2), quoting `pass  # noqa: SIM105` | (a) control | **passes** |
| 4 | same commit: `[empty-handler]` at the opener's line (1), quoting `except ValueError:` | (a) | red |
| 5 | `} catch {} // eslint-disable-line no-empty` in src/main.ts: `[eslint-disable]` at its line, quoting it | (b) control | **passes** |
| 6 | same commit: `[empty-handler]` at the same line, quoting it | (b) | red |
| 7 | `except OSError: ...  # noqa: S112` in src/app.py: `[noqa]` at its line, quoting it | (b) control | **passes** |
| 8 | same commit: `[empty-handler]` at the same line, quoting it | (b) | red |
| 9 | #5's line: the `[eslint-disable]` refusal comes before the `[empty-handler]` one in the output ("after the winning row's") | (b) | red (no empty-handler) |
| 10 | #7's line: the same order for `[noqa]` | (b) | red (no empty-handler) |
| 11 | `} catch (IOException e) {} catch (Exception e) {` / `}` in src/main.ts: the empty-handler whole line occurs exactly once (`sup_count` = 1) | (c) | red (2 today) |
| 12 | the branch: `rc|refusals|summary` = `1|9|0` | (a)-(c) | red (`1|6|0`) |

Every refusal is pinned by its whole line through `want_3j` (`grep -cxF`),
the order by the line number of the first output line *equal* to each
(`awk` on `ENVIRON`, no pipe, no escape processing). Commits are listed
newest first by `rev-list`, so ordering is only asserted within one line of
one commit, which is what (b) states.

**The red, against the shipped 02e4b15** (release 101):
`bash .claude/tests/boundaries.test.sh`, local, 24m08s, rc 1. The summary
line and the new describe verbatim; no other FAIL in the run, and no bash
error anywhere in the output:

```
  HARNESS-082's return 2: a directive on a closer or on a one-line handler does not approve the empty handler, and a two-catch line is refused once
    FAIL HARNESS-082's return 2: (a) 'catch (err) {' then '} // eslint-disable-line' in src/main.ts, AND empty-handler at the opener although the closer hit [eslint-disable] - refused by its whole line
         expected: 1
         actual:   0
    FAIL HARNESS-082's return 2: (a) 'except ValueError:' then 'pass  # noqa: SIM105' in src/app.py, AND empty-handler at the opener although the closer hit [noqa] - refused by its whole line
         expected: 1
         actual:   0
    FAIL HARNESS-082's return 2: (b) '} catch {} // eslint-disable-line no-empty' in src/main.ts, AND empty-handler at the same line although it hit [eslint-disable] - refused by its whole line
         expected: 1
         actual:   0
    FAIL HARNESS-082's return 2: (b) 'except OSError: ...  # noqa: S112' in src/app.py, AND empty-handler at the same line although it hit [noqa] - refused by its whole line
         expected: 1
         actual:   0
    FAIL HARNESS-082's return 2 (b): '} catch {} // eslint-disable-line no-empty' in src/main.ts: [eslint-disable] - the row's refusal is printed, then empty-handler after it
         expected: before
         actual:   directive at line 12, empty-handler at line <none>
    FAIL HARNESS-082's return 2 (b): 'except OSError: ...  # noqa: S112' in src/app.py: [noqa] - the row's refusal is printed, then empty-handler after it
         expected: before
         actual:   directive at line 11, empty-handler at line <none>
    FAIL HARNESS-082's return 2 (c): '} catch (IOException e) {} catch (Exception e) {' then '}' is refused as empty-handler exactly once, by its whole line
         expected: 1
         actual:   2
    FAIL HARNESS-082's return 2: the branch - rc|refusals (two per (a) and (b) commit, one for (c))|summary
         expected: 1|9|0
         actual:   1|6|0

boundaries: 332 passed, 8 failed
```

(The `line 12` / `line 11` in #9 and #10 are positions in that branch's
`check-boundaries.sh` output, the same in the full run and the subset; the
assertion compares two positions in one output.)

**Controls that pass on arrival (#1, #3, #5, #7), and the mutation that
earns them - run now, in RED, against the shipped code.** These assert the
directive's own refusal, which 02e4b15 already prints; the risk they guard
is a GREEN that fixes (a)/(b) by *replacing* the directive's refusal with
`empty-handler` instead of adding to it. The mutation stops the table's
`printf` for the two directive ids, so the row's refusal disappears:

    $ bash scripts/mutate.sh scripts/check-boundaries.sh \
        's/printf "%d|%s|%s.n", ln, id\[k\], t/if (id[k] != "eslint-disable" \&\& id[k] != "noqa") &/' \
        -- bash <scratchpad>/sub3.test.sh
    ...
      HARNESS-082's return 2: a directive on a closer or on a one-line handler does not approve the empty handler, and a two-catch line is refused once
        FAIL HARNESS-082's return 2: (a) 'catch (err) {' then '} // eslint-disable-line' in src/main.ts, the row's own refusal [eslint-disable] at the closer - refused by its whole line
             expected: 1
             actual:   0
        FAIL HARNESS-082's return 2: (a) 'except ValueError:' then 'pass  # noqa: SIM105' in src/app.py, the row's own refusal [noqa] at the closer - refused by its whole line
             expected: 1
             actual:   0
        FAIL HARNESS-082's return 2: (b) '} catch {} // eslint-disable-line no-empty' in src/main.ts, the row's own refusal [eslint-disable] - refused by its whole line
             expected: 1
             actual:   0
        FAIL HARNESS-082's return 2: (b) 'except OSError: ...  # noqa: S112' in src/app.py, the row's own refusal [noqa] - refused by its whole line
             expected: 1
             actual:   0
        ... (#2, #4, #6, #8-#12 red as in the unmutated run; branch actual 1|2|0)
    boundaries: 149 passed, 50 failed
    === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261029T202812Z.38853.bak) ===

`sub3.test.sh` is lines 1-109 of the edited suite plus its whole 3j section
(from the HARNESS-081 fixture describe to the end), with an absolute
`_lib.sh` path; it lives in the session scratchpad, never in the tree. The
other 42 reds in that run are the existing 3j rows the mutation also
silenced. `mutate.sh --check` was clean afterwards.

| # | control | expected on arrival | measured (02e4b15) | mutation | went red |
|---|---|---|---|---|---|
| 1 | `[eslint-disable]` at closer line 3 | refused, whole line | refused, count 1 | above | yes (0) |
| 3 | `[noqa]` at closer line 2 | refused, whole line | refused, count 1 | above | yes (0) |
| 5 | `[eslint-disable]` at the one-line handler | refused, whole line | refused, count 1 | above | yes (0) |
| 7 | `[noqa]` at the one-line handler | refused, whole line | refused, count 1 | above | yes (0) |

GREEN should re-run the same mutation (adjusted to its own `printf` line if
it moves) against the shipped fix and confirm #1, #3, #5, #7 still go red -
that is the "replaced, not added" mutation once the fix exists. The "defect
put back" for the story's central claim here is GREEN's: restore `!hit &&`
on the closer test (a) and drop the one-line re-test (b) - #2, #4, #6, #8-#10
and the branch count go red; and for (c), remove the duplicate guard - #11
goes red (2) and the branch count reads 10.

**`gates.sh --fast`:** rc 0, `All required gates passed (0 ran, 5
unconfigured, 0 known)` - this repository's project.conf is not bootstrapped,
so it judges nothing here; the suite above is the evidence.

**Floor:** `boundaries` 328 -> 340 (+12), in `floors.conf` and in
`selftest.test.sh`'s copy. Measured executed count 340 = 332 + 8. Until GREEN
lands the suite sits below its floor (332 < 340) - expected in RED.

**One observation for GREEN, not a contract change.** (c)'s rule as written
("a line that already reported `empty-handler` through a one-line row ... does
not get a second from the window") is per *line*. Under (b), a line whose
winning row is a directive can also report `empty-handler` through the
one-line re-test; if that line is armed as an opener too (it must end in
`{`, e.g. `} catch {} /* eslint-disable-line */ catch (e) {` over `}`), (c)
applies to it as well - one `empty-handler`, not two. Not pinned (contrived),
but the dedup flag should be set by the one-line match whichever path
reported it.

## Diff review

### Round 1 (2026-10-29, on f6c6447) - fresh `feature-developer`, resolved **claude-opus-5-5**, no override

Method: both functions eval'd out of the shipped script and run on hand-built
diffs under gawk 5.4.1 and mawk 1.3.4 20240123; identical output under both.
Checked and correct: multiple hunks, opener followed by opener, CRLF diffs,
`\ No newline` marker, `-` lines before `+` lines, the `%c`-built quote.

**Must fix**

1. *An opener that also matches a table row is never armed.* `if (hit) pk = ""
   else { ... }` tests openers only on lines that hit no row, so
   `except:  # noqa: E722` / `pass` reports only `noqa`; once `[noqa]` is
   declared, the empty catch-all passes. C-3 says only a *closer* that hit a
   row is not reported twice. Fix: arm the opener regardless of `hit`; needs a
   RED control first.
2. *`stub-throw` misses TypeScript's own quick-fix stub*
   `throw new Error("Method not implemented.")` (typescript.js
   `Method_not_implemented`), and `'not yet implemented'`, `"NOT IMPLEMENTED"`.
   Fix: allow a message prefix inside the quotes; a C-1 change, PO decision.

**Should fix**

3. *`stub-gd` has no tail guard*: `assert(false_positives == 0)` and
   `assert(falseCount === 0)` are refused; `push_error("Not implemented")` is
   missed. Fix: `(false([^A-Za-z0-9_]|$)|"[Nn]ot implemented")` plus a corpus
   line.
4. *A one-line empty handler is not an opener*: `} catch (e) {}`,
   `} catch {}`, `except: pass`, `except Exception: pass` print nothing, and
   (unverified, no Prettier here) Prettier prints an empty catch on one line.
   PO question: a table row each, or Out of scope.

**Nice to have**

5. The comment above `suppression_hits` says any non-added line clears the
   window; `-` and `\` lines do not (the code is right, C-3 agrees).
6. `except(ValueError):`, `except* ValueError:` missed; an abstract method
   with a docstring between `def` and `raise` is refused (as AC-2 specifies).

Verdict: fix 1 and 2 first.

**Orchestrator's reproduction (different inputs, not the reviewer's code):**

```
--- F1: opener carrying a directive
3|noqa|except Exception:  # noqa: BLE001
--- F2: TS quick-fix stub and variants          (all three lines: nothing)
--- F3: stub-gd tail
1|stub-gd|assert(false_alarm_count == 0)
3|stub-gd|assert(false)
--- F4: one-line empty handlers
3|empty-handler|} catch (err) {
```

Inputs: F1 `try:` / `    f()` / `except Exception:  # noqa: BLE001` /
`    pass`; F2 `throw new Error("Method not implemented.");`,
`throw new Error('Not yet implemented')`, `throw new Error("no such user")`;
F3 `assert(false_alarm_count == 0)`, `push_error("Not implemented")`,
`assert(false)`; F4 `} catch (err) {}`, `except KeyError: pass`,
`} catch (err) {` / `}`. All four findings reproduce: F1 has no
`empty-handler`, F2 prints nothing for the two stubs, F3 refuses the
identifier and misses the capital N, F4 sees only the two-line form.

### Round 2 (2026-10-29, on 02e4b15) - fresh `feature-developer`, resolved **claude-opus-5-5**, no override

Method: both shipped functions over a 41-line all-added input under gawk
5.4.1 and mawk 1.3.4 20240123, byte-identical; a 200,000-character line per
ERE matched nothing in 0.97 s (gawk) / 0.11 s (mawk) - no backtracking.
Round 1's fixes checked correct: the armed opener on a row hit; closer and
opener on one line (`} catch (f) {` between two others) reported at both;
the `stub-throw` prefix (`"Method not implemented."`, `"NOT  IMPLEMENTED"`,
`` `Unimplemented opcode ${op}` `` refused; `"could not open the file"`,
`"This is not important"` clean); the `stub-gd` tail guard; the one-line
rows (`prefetch {}`, `dispatch() {}` clean). Judged right against C-1's
intent, not findings: `"feature not implemented for this region"` refused
(Out of scope: declared in one line); `const s = "} catch (e) {}"` refused
(the accepted line-not-token false positive); `x.catch(function (e) {})`
refused (a true positive).

**Must fix**

1. *A directive on a one-line handler, or on a closer, still approves the
   empty handler.* First row wins and the directive rows come first, so
   `except: pass  # noqa`, `} catch (e) {} // eslint-disable-line no-empty`,
   `except Exception:` / `pass  # noqa: S110`, and `} catch (e) {` /
   `}  // eslint-disable-line` print only the directive. C-3's "in practice
   no row matches those lines" is false. Fix: test the one-line
   `empty-handler` rows when another row won, and test the closer whatever
   the hit was; C-3's precedence wording changes, then RED.

**Nice to have**

2. *Two catches on one line print `empty-handler` twice*:
   `} catch (A e) {} catch (B e) {` / `}` gives two identical refusals at the
   same line. Harmless (both empty, one declaration clears both) but noisy.
3. *`stub-throw`'s prefix stops at any quote*, so
   `"can't do that: not implemented"` and `'Method "foo" not implemented'`
   are missed; `[Nn]ot` has no left boundary (`"knot implemented"`, contrived).
4. *`stub-gd` is narrower than `stub-throw`*: `push_error("NOT IMPLEMENTED")`,
   `push_error("not yet implemented")` missed.

Verdict: fix 1 first.

**Orchestrator's reproduction (different inputs):**

```
--- one-line handler with a directive
1|eslint-disable|} catch {} // eslint-disable-line no-empty
2|noqa|except OSError: ...  # noqa: S112
--- closer with a directive
2|noqa|pass  # noqa: SIM105
4|eslint-disable|} // eslint-disable-line
--- multi-catch on one line
1|empty-handler|} catch (IOException e) {} catch (Exception e) {
1|empty-handler|} catch (IOException e) {} catch (Exception e) {
```

Inputs: `} catch {} // eslint-disable-line no-empty`,
`except OSError: ...  # noqa: S112`; `except ValueError:` /
`    pass  # noqa: SIM105`, `catch (err) {` / `} // eslint-disable-line`;
`} catch (IOException e) {} catch (Exception e) {` / `}`. Findings 1 and 2
reproduce. **Decision (PO, 2026-10-29):** finding 1 is the hole the user
approved closing in round 1, on lines that fix did not reach, so it is fixed
here under that approval - C-3's precedence bullet amended in place, (a)-(c),
and a second return to RED; finding 2 is folded into the same fix as (c).
Findings 3 and 4 change C-1's settled EREs again and go to the follow-up
list.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-29T19:19:06Z
    commit: 2fc8ba9
    tree:   064a7c6e8eb8ccaaad7ed28fb2ae2b6d931a71df
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


**Follow-up list (not this story; for the story that follows HARNESS-081's list):**

- Diff review round 1, finding 6: `except(ValueError):` and `except* ValueError:`
  are not colon openers; an abstract method with a docstring between `def` and
  `raise` is refused (AC-2 as specified).
- An Allman-brace or promise `.catch(() => {})` empty handler, and a brace
  opener with a trailing directive (`} catch (e) { // eslint-disable-line`),
  are not seen (C-3, Out of scope).
- Diff review round 2, findings 3 and 4: `stub-throw`'s message prefix stops
  at any quote character (`"can't do that: not implemented"` missed), and
  `stub-gd` lacks `stub-throw`'s `NOT IMPLEMENTED` / `not yet implemented`.
- HARNESS-081's parent-phase arm judges a RED commit whose parent was GATES,
  labelled `RED, after GATES` (seen in DV-2's re-run); it was meant for the
  GATES -> REVIEW step only.
