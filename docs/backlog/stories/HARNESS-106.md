---
id: HARNESS-106
title: The boundaries suite reads vendored story sections, not upstream story files
slug: the-boundaries-suite-reads-vendored-stor
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-106-the-boundaries-suite-reads-vendored-stor
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/boundaries.test.sh, .claude/tests/shipped-docs.test.sh, .claude/tests/fixtures/boundaries/.gitattributes, .claude/tests/fixtures/boundaries/HARNESS-089.md, .claude/tests/fixtures/boundaries/HARNESS-095.md, .claude/tests/fixtures/boundaries/HARNESS-099.md, .claude/tests/fixtures/boundaries/HARNESS-102.md, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the boundaries and shipped-docs suites under their selftest floors, which CI runs in full on the PR
---

## Context

A field defect, measured 2026-11-13 while refreshing two consumer projects to
release 123. The full self-test fails in both, in the `boundaries` suite, on
four assertions that pass upstream.

`.claude/tests/boundaries.test.sh` reads this repository's own story files at
run time, in two places (line numbers at `d686c39`):

- `k_real()` at 4191-4197 reads `"$REPO_ROOT/docs/backlog/stories/$1.md"` for
  HARNESS-089, HARNESS-095 and HARNESS-099: the three HARNESS-102 C-9 cases
  at 4198-4202, the fixtures "not written from this contract's reading".
- the R-3 twin (f) at 4369-4375 reads
  `"$REPO_ROOT/docs/backlog/stories/HARNESS-102.md"`.

The backlog is the project's own. `.claude/harness/docs-shipped.conf` declares
`docs/backlog/stories/` as `written`, and `scripts/refresh-harness.sh` never
ships a story. So in a consumer those files are either absent or somebody
else's:

- **Absent** (clean_calendar). `awk: fatal: cannot open file
  .../docs/backlog/stories/HARNESS-089.md`, and the same for 095, 099 and 102.
  The three C-9 assertions read `0 0 0 0 0` where `1 1 0 0 non-zero` is
  expected, the (f) twin reads `0 0` where `0 1` is expected, the suite prints
  `boundaries: 681 passed, 4 failed`, and the floor of 685 is missed.
  Evidence: `D:/clean_calendar/.claude/state/attest-logs/20261113T064207Z.5306.log`,
  lines 143-166.
- **Somebody else's** (trump-crime-family). That project has its own
  `docs/backlog/stories/HARNESS-089.md`, an unrelated local story whose id
  collides. The C-9 case reads it without complaint and judges the wrong
  text. Evidence: `D:/trump-crime-family/.claude/state/refresh-selftest.out`
  names its log.

The fix keeps what the C-9 fixtures are for - entries copied from real
stories, byte for byte, not written from the contract's reading of the
format - and moves the bytes to where the suite ships: `.claude/tests/fixtures/`,
which a refresh replaces along with the rest of `.claude/tests`. A new rule in
the `shipped-docs` suite then refuses any suite line that reads under
`$REPO_ROOT/docs/`, so the next fixture "read from the real tree" fails
upstream, on the PR that adds it, and not in a consumer after a release.

**Only these two reads exist.** Searched at `d686c39`: every `REPO_ROOT`
reference in `.claude/tests/*.sh` names `.claude/`, `scripts/`, `CLAUDE.md`,
`.github/workflows` or a temp path, except the two lines above. Every other
`docs/backlog` path in a suite is under a fixture root (`$FIX`, `$WORK`, ...).

**The required gate.** Every gate is unconfigured in this repository, so
`required_gates` stays empty, as on HARNESS-102 to 104. The artifact is judged
by the `boundaries` and `shipped-docs` suites under their self-test floors,
which CI runs in full on the PR.

**The epic.** `epic:` is empty, as on every HARNESS story.

## Acceptance criteria

- **AC-1** — Given a repository root whose `docs/backlog/stories/` holds no
  `HARNESS-095.md`, `HARNESS-099.md` or `HARNESS-102.md` (the first consumer's
  state) and holds a `HARNESS-089.md` that is an unrelated story (the second
  consumer's state), when the `boundaries` suite takes the story sections for
  its three C-9 cases and for the R-3 twin (f) with that root as its
  `REPO_ROOT`, then each case gives the result it gives upstream: the three
  C-9 assertions read `1 1 0 0 non-zero` and the (f) assertion reads `0 1`.
  The four assertions are executed on every run, upstream and in a consumer
  alike; none is skipped or made conditional on a file existing.
  *The bug this reproduces:* with the readers as they are at `d686c39`, the
  three C-9 assertions fail under such a root (`0 0 0 0 0` where a file is
  absent) and (f) reads `0 0`, which is the first consumer's log line for
  line. *Control:* with the two readers pointed back at
  `$REPO_ROOT/docs/backlog/stories/`, all four assertions must fail (DV-1).
- **AC-2** — Given the vendored copies under
  `.claude/tests/fixtures/boundaries/` (`HARNESS-089.md`, `HARNESS-095.md`,
  `HARNESS-099.md`, `HARNESS-102.md`), when the `boundaries` suite runs, then
  it checks each file's bytes against the checksum and size of that story's
  `## Regressions` and `## Amendments` sections as they stand in this
  repository at `d686c39` (Contract C-2 holds the four values), and one byte
  changed, added or removed in any of the four files fails that assertion,
  naming the file. The copies are the real entries, not a rewriting of them,
  and stay so in every tree the suite is shipped to.
- **AC-3** — Given the harness tree, when the `shipped-docs` suite runs, then
  a rule over every `.claude/tests/*.sh` file reports no line that reads under
  `$REPO_ROOT/docs/`; and given a fixture tree whose suites hold such lines,
  then the rule reports each one as `<file>:<line number>`, in the spellings
  `"$REPO_ROOT/docs/..."`, `"${REPO_ROOT}/docs/..."`, `"$REPO_ROOT"/docs/...`
  and `"$TESTS_DIR/../../docs/..."`, in a suite and in `_lib.sh`; and it
  reports nothing for a whole-line comment that quotes such a path, for a
  `docs/` path under another root (`$FIX/docs/...`, `$root/docs/...`), or for
  `$REPO_ROOT/.claude/harness/docs-shipped.conf`.
  *Control:* the rule is probed against a real line of this tree, not only its
  fixtures: with a reader in `boundaries.test.sh` pointed back at
  `$REPO_ROOT/docs/backlog/stories/`, the real-tree assertion must fail naming
  that file and line (DV-1).

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `.claude/tests/boundaries.test.sh`, `.claude/tests/shipped-docs.test.sh`, `.claude/tests/fixtures/boundaries/.gitattributes`, `.claude/tests/fixtures/boundaries/HARNESS-089.md`, `.claude/tests/fixtures/boundaries/HARNESS-095.md`, `.claude/tests/fixtures/boundaries/HARNESS-099.md`, `.claude/tests/fixtures/boundaries/HARNESS-102.md`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

**Who writes which.** Every path above classifies as `harness`, so the lock
divides nothing and this block does. The defect is in a test suite, so the fix
is a test-file change and belongs to RED (test-developer): the two suites and
the five files under `fixtures/boundaries/`. GREEN (feature-developer) writes
the floor records and `VERSION` (C-7), and touches no suite. HARNESS-099 is
the precedent for a story whose subject is a suite.

**C-1. RED works in two steps, and pastes the red of step 1.** The subject of
the fix and the tests of it live in the same file, so "watched to fail" has to
be arranged rather than assumed:

- *Step 1, the traps, with the readers still reading the real tree.* Write the
  decoy root and the swap (C-3), the checksum assertion (C-2) and the rule
  with its assertions (C-5). In this step `k_real` and the new `k_real_reg`
  (C-4) still read `"$REPO_ROOT/docs/backlog/stories/$1.md"`, and no file
  exists under `fixtures/boundaries/`. Run
  `bash scripts/selftest.sh boundaries shipped-docs`. Expected, and pasted
  into the handoff with the actual values: `boundaries` 5 failed - the three
  C-9 assertions and (f), with the consumer's values (`0 0 0 0 0` for 095 and
  099, `0 0` for (f); 089 reads whatever the decoy yields), and the checksum
  assertion (no files yet); `shipped-docs` 1 failed - the real-tree assertion,
  naming the two reader lines of `boundaries.test.sh`.
- *Step 2, the fix.* Create the five files (C-2), point the two readers at
  them (C-4), rewrite the two comments (C-4). Run the same command: 0 failed
  in both, `boundaries` 686 passed, `shipped-docs` 18 passed (C-7).

RED therefore ends green. That is this story's shape, not an omission: the
handoff carries step 1's output as the observed failure, and DV-1 puts the
defect back at GATES against the committed tree.

**C-2. The vendored copies.** Directory `.claude/tests/fixtures/boundaries/`.
Each copy is the story's `## Regressions` section followed by its
`## Amendments` section, each from its heading line to the line before the
next line beginning `## `, byte for byte, nothing added (no header, no
provenance line: the bytes are the oracle). Generated with, from the
repository root, at a tree whose four story files are those of `d686c39`:

    for id in HARNESS-089 HARNESS-095 HARNESS-099 HARNESS-102; do
      for s in Regressions Amendments; do
        awk -v h="## $s" 'index($0, h) == 1 { on = 1; print; next } on && /^## / { exit } on { print }' "docs/backlog/stories/$id.md"
      done > ".claude/tests/fixtures/boundaries/$id.md"
    done

Measured by the PO at `d686c39` (2026-11-13, Windows host, Git Bash awk),
`cksum < file` on the generated bytes. These are **settled**: read them out,
do not re-derive them from whatever the files turn out to hold.

| File | CRC | Bytes | `## Amendments` heading at line |
|---|---|---|---|
| `HARNESS-089.md` | 679495376 | 6306 | 99 |
| `HARNESS-095.md` | 1572516679 | 6026 | 81 |
| `HARNESS-099.md` | 2058360084 | 6957 | 93 |
| `HARNESS-102.md` | 3699688268 | 16374 | 223 |

Also measured: none of the four holds a carriage return; each holds exactly
two lines beginning `## `; `k_real` over a copy prints the same bytes as
`k_real` over the story file (same CRC and size as the table, for 089, 095
and 099); the (f) awk program over the copy of HARNESS-102 prints the same
bytes as over the story file (CRC 1265526490, 15659 bytes). So the two readers
need no change beyond the path.

`.claude/tests/fixtures/boundaries/.gitattributes` holds `* -text` under a
comment saying why, as `.claude/tests/fixtures/manifest/.gitattributes` does:
a consumer's own attributes and `core.autocrlf` must not convert a
byte-for-byte oracle on checkout (the root `.gitattributes` is not shipped by
a refresh).

The checksum assertion (AC-2), in `boundaries.test.sh` directly before the
C-9 loop: **one** `assert_eq`. Its value is four lines, one per file in the
table's order, each `<CRC> <bytes> <file name>`, from `cksum <` the file with
the name appended; the expected value is the table, as literals. A missing
file yields a line that does not match, never a skipped line. Name it without
any head-shaped text (C-6).

HARNESS-102's `## Amendments` section is in its copy and no case reads it; it
is there so that one generation rule covers all four files.

**C-3. The decoy root (AC-1).** Built once, before the checksum assertion, in
a temp directory of its own (`K_DECOY`), removed where the block removes
`$KB`: `"$K_DECOY/docs/backlog/stories/HARNESS-089.md"`, a story file with
frontmatter and a `## Context` paragraph and **no** `## Regressions` or
`## Amendments` section; no other file. A helper runs one command with
`REPO_ROOT` set to the decoy and puts it back:

    k_at_decoy() { local r="$REPO_ROOT" e; REPO_ROOT="$K_DECOY"; "$@"; e=$?; REPO_ROOT="$r"; return "$e"; }

The swap wraps the **reader call only**: `k_at_decoy k_real "$real" > "$KB"`,
then `k_branch T-113` under the real root. `k_branch` reaches `k_models`,
which reads `"$REPO_ROOT/.claude/harness/models.conf"` and must keep doing so.
No subshell: `$out` and `$rc` are globals (the comment above `KB=` says why).

The four assertions keep their names, their expected values and their number.
What changes is where their bytes come from and that the reader runs under
the decoy. After step 2 the readers do not mention `REPO_ROOT`, so the swap
changes nothing they do; it is there so that a reader which goes back to the
repository's own backlog fails upstream as it would in a consumer.

**C-4. The two readers.** The path is spelled inside each function body,
exactly `"$TESTS_DIR/fixtures/boundaries/$1.md"`, so that it is expanded when
the function runs (under the swap) and so that DV-1's expression matches both.

- `k_real <story>`: body unchanged except `local f=...`, which becomes
  `local f="$TESTS_DIR/fixtures/boundaries/$1.md" s`.
- `k_real_reg <story>`, new, beside it: the (f) awk program, unchanged, over
  `"$TESTS_DIR/fixtures/boundaries/$1.md"`. Case (f) becomes
  `k_at_decoy k_real_reg HARNESS-102 > "$KB"; k_branch T-117`.
  **The trap this avoids:** (f) today passes the path as an argument to an
  inline `awk`. Wrapped as `k_at_decoy awk '...' "$REPO_ROOT/..."` the
  argument would be expanded before the swap, the real root would be read, and
  DV-1 could not make (f) fail upstream. The path must be inside a function.
- The comment above `k_real` (4186-4190) and the one above (f) (4369-4371) say
  the sections are read from the real story file at run time. Rewrite both:
  copied byte for byte from this repository's story files at `d686c39`, held
  under `.claude/tests/fixtures/boundaries/`, pinned by checksum, and never
  read from `docs/backlog`, which a consumer does not have (HARNESS-106).
- One comment there names each of the five paths in full,
  repository-relative (`.claude/tests/fixtures/boundaries/HARNESS-089.md`,
  and so on, and `.claude/tests/fixtures/boundaries/.gitattributes`), each
  followed by a comma or a space. `scripts/selftest-needed.sh --suites` maps a
  changed path to the suites whose source holds it (rule R3); without the
  mention a change to a copy is "mapped by no rule" and selects every suite.

**C-5. The rule (AC-3), in `.claude/tests/shipped-docs.test.sh`.** That suite
already owns "what the harness ships under `docs/`, and what it never may".
A function beside `shipped_docs_problems`, in the same style:

    suite_docs_reads <root>

prints one line `<path relative to root>:<line number>` for each line of each
`<root>/.claude/tests/*.sh` (top level only: the suites, `_lib.sh`,
`_spawns.sh`; files in `LC_ALL=C` name order, lines in file order) that

1. is not a whole-line comment (first non-blank character `#`), and
2. matches the ERE `(REPO_ROOT|TESTS_DIR/\.\./\.\.)[}"]*/docs(["'/ ]|$)`.

What each part of the pattern is for: `REPO_ROOT` and `TESTS_DIR/../..` are
the two names `_lib.sh` gives the real checkout; `[}"]*` admits
`${REPO_ROOT}/docs` and `"$REPO_ROOT"/docs`; the tail requires `docs` to be a
whole path component, so `docs-shipped.conf` and a `docsy/` never match.

**No exception for a `ship` entry.** `docs/wiki/audits/TEMPLATE.md` is added
by a refresh only where the project has none and is never overwritten, so its
content in a consumer is the consumer's. A suite may not read it either. The
existing rule checks such a file through `$root`, which this pattern does not
match and need not.

**The rule's written limit**, to be stated in the function's comment: it reads
text, not data flow. A path built in a variable first (`d="$REPO_ROOT"`, then
`"$d/docs/..."`), a `cd "$REPO_ROOT"` followed by a relative `docs/...`, and
`git -C "$REPO_ROOT" show HEAD:docs/...` are not seen. Both reads this story
removes are seen (C-1 step 1 shows it, DV-1 shows it again).

**It must not match itself.** `shipped-docs.test.sh` is one of the scanned
files and its fixtures hold offending lines as data. Spell the two root names
in pieces wherever they are followed by `/docs` (for instance a variable
holding `'REPO''_ROOT'`), so that no non-comment line of the suite matches the
pattern. No file is exempted by name: an exemption by name is a hole. The
real-tree assertion is the check that this was done.

Four assertions, in a new `describe` before `summary "shipped-docs"`:

1. *Real tree:* `suite_docs_reads "$REPO_ROOT"` prints nothing. Red in step 1.
2. *Not vacuous:* the rule scanned at least 30 files of the real tree (36 at
   `d686c39`), in the `_ok`/`_bad` form the suite's "at least 24" check uses.
3. *Fixture, offending:* a fixture tree `<g>/.claude/tests/` holding
   `a.test.sh` and `_lib.sh`; expected output, exactly,
   `.claude/tests/_lib.sh:1`, `.claude/tests/a.test.sh:3`,
   `.claude/tests/a.test.sh:4`, `.claude/tests/a.test.sh:5`,
   `.claude/tests/a.test.sh:8`, one per line. `_lib.sh` line 1 assigns
   `"$REPO_ROOT/docs"`. `a.test.sh`: line 1 the shebang; 2 a whole-line
   comment quoting `"$REPO_ROOT/docs/backlog/stories/T-1.md"`; 3 `cat` of that
   path; 4 an assignment of `"${REPO_ROOT}/docs/wiki/architecture.md"`; 5 `ls
   "$REPO_ROOT"/docs/backlog`; 6 `cat "$FIX/docs/backlog/stories/T-1.md"
   "$root/docs/wiki/stack.md"`; 7 `cat
   "$REPO_ROOT/.claude/harness/docs-shipped.conf"`; 8 `cat
   "$TESTS_DIR/../../docs/backlog/README.md"`.
4. *Fixture, twin:* the same tree with `_lib.sh` line 1 and `a.test.sh` lines
   3, 4, 5 and 8 removed (lines 2, 6 and 7 kept): prints nothing.

**C-6. What must not be pasted where block 3k reads.** As HARNESS-103 C-4,
which applies here in full: assertion names carry no head-shaped text, no
comment opener or closer and no fence marker; nothing in this story's
`## Regressions` or `## Amendments`, if it ever writes them, begins a line
with an entry head that is not a real entry. One thing is particular to this
story: **never paste the contents of a vendored copy into this story file.**
The copies hold unrecorded `R-1` and `AM-1` heads by design. Refer to them by
file name, CRC and size.

**C-7. The floors and the release (GREEN).** At `d686c39`:
`floor | boundaries    | 685` (`floors.conf` line 40) and `boundaries 685`
(`selftest.test.sh` line 531); `floor | shipped-docs  | 14` (line 66) and
`shipped-docs 14` (line 558). GREEN raises all four, in one commit, to the
executed counts it measures with
`bash scripts/selftest.sh boundaries shipped-docs`: expected `boundaries` 686
(685, the four cases unchanged in number, plus the one checksum assertion)
and `shipped-docs` 18 (14 plus C-5's four), with a dated comment in
`floors.conf` in the form the HARNESS-103 and HARNESS-104 entries use.
If RED added or dropped an assertion, the measured count is the floor and the
handoff says which.
`.claude/harness/VERSION` goes to `125` with the real calendar date of the
change. Release 124 belongs to HARNESS-105, in flight on
`story/HARNESS-105-mutate-sh-counts-lines-past-the-windows-path-limit`
(`## Notes`).

**C-8. Oracle partition.** All three criteria are **mechanical**: pin the
values, the names and the output lines exactly; invent no metric. Within
them, the four CRC and size pairs of C-2 and the four expected results of
AC-1 are **settled** - read out, not re-measured to fit. If a generated copy
does not match C-2's table, the copy is wrong (or the story files moved off
`d686c39`); stop and report, do not edit the table.

**C-9. Changed signatures: none.** `k_real <story>` keeps its name, argument
and output. Its callers: the C-9 loop only. `k_real_reg` and `k_at_decoy` are
new. Nothing outside `boundaries.test.sh` calls any of them.

**C-10. Commands.**

    bash scripts/selftest.sh boundaries shipped-docs
    bash scripts/attest.sh -- bash scripts/selftest.sh boundaries shipped-docs
    bash scripts/selftest-needed.sh --suites
    bash scripts/check-sigpipe.sh && bash scripts/check-grep-count.sh
    bash scripts/gates.sh --fast

`boundaries` alone is slow on a loaded host: a run started at PLANNED on
2026-11-13, with another session's self-test running, had not finished after
35 minutes and was stopped. Plan each phase around few runs of it, and run
`shipped-docs` on its own while shaping the rule. After step 2 RED records what
`selftest-needed.sh --suites` prints for its diff (a list is expected; `all`
is not a failure, and the handoff says which path caused it), and runs the
two tree-wide checkers, since the copies carry pasted shell from four stories.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story": one mutation, which is
both the defect put back for the central claim and the probe of the new rule
against a real line of this tree. DV-2 is not a mutation. C-6 applies to what
is pasted here.

- **DV-1, the defect put back (AC-1, AC-3).** With both readers pointed back
  at the repository's own backlog, the suite is again the one that fails in a
  consumer. `mutate.sh` must report 2 lines changed. `boundaries` **must**
  report exactly 4 failed: the three C-9 assertions and the (f) twin, with
  the first consumer's values for 095, 099 and (f) (`0 0 0 0 0`, `0 0 0 0 0`,
  `0 0`) and, for 089, whatever the decoy yields, pasted rather than
  predicted; the checksum assertion still passes. `shipped-docs` **must**
  report exactly 1 failed: the real-tree assertion, its actual value the two
  mutated lines of `.claude/tests/boundaries.test.sh`. If the four `boundaries`
  failures do not appear on this (upstream) tree, the decoy swap is not doing
  its work and AC-1 is unmet. RED cannot run this against the committed
  fix: until step 2 there is nothing to point back, and step 1's red is an
  observation of the unfixed tree, not a mutation of the fixed one.
  **Owner: GATES.**

      bash scripts/mutate.sh .claude/tests/boundaries.test.sh 's|"\$TESTS_DIR/fixtures/boundaries/\$1\.md"|"$REPO_ROOT/docs/backlog/stories/$1.md"|' -- bash scripts/selftest.sh boundaries shipped-docs

  RED's handoff restates this expression against the readers as built.

- **DV-2, a consumer-shaped run (AC-1, at full scale, once).** The decoy in
  the suite covers the readers; this covers the whole run the field report
  was about. In a clone of the committed story branch, with every
  `docs/backlog/stories/HARNESS-*.md` deleted and an unrelated
  `HARNESS-089.md` written in their place, `bash scripts/selftest.sh
  boundaries shipped-docs` **must** report 0 failed for both suites, the same
  passed counts as in this tree, and both floors met. It needs the floors of
  C-7 and a commit to clone, so it cannot run before GREEN. **Owner: GATES.**

      T="$(mktemp -d)" && git clone -q --no-hardlinks . "$T/c" && rm -f "$T"/c/docs/backlog/stories/HARNESS-*.md
      printf -- '---\nid: HARNESS-089\ntitle: An unrelated local story\n---\n\n## Context\n\nNot the upstream story.\n' > "$T/c/docs/backlog/stories/HARNESS-089.md"
      ( cd "$T/c" && bash scripts/selftest.sh boundaries shipped-docs ); rm -rf "$T"

  Paste the two summary lines and the floors line. If the clone fails for a
  reason that is not a story file, paste that and say so; do not adjust the
  clone until it passes.

Not owed, and stated so that nobody adds one: a mutation earning the checksum
assertion (it is red in step 1 with no files, and its expected values are the
PO's, measured independently of RED), or one per fixture line of C-5.

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. check-boundaries.sh fails a PR whose criteria differ
     from their last committed PLANNED state (else the base branch) without an
     entry here. Omit the section if unused.
     Head each entry AM-<n> (`- **AM-1 (AC-2).** ...`), and give it its
     adjudication record, a line of its own in this section, outside any
     comment or fence - check-boundaries.sh refuses a new entry without one:
       - **Adjudicated AM-<n>:** `fable` (resolved <name>), <date>, <what it reproduced>
     A claim that a criterion is wrong is also what an agent says when it
     wants to stop failing, so it is judged by a fresh `fable` dispatch - a
     `lead-po` on the ADJUDICATE row of models.conf, on different inputs, not
     the claimant's code - and that dispatch writes the judgement and the
     record line; the judgement is never the orchestrator's. An entry that
     follows a diff-review or PR-feedback finding routed RED or AMEND was
     judged by that review, so the orchestrator writes its record, naming the
     round and finding (or the PR-feedback item) and the model the review was
     planned on and resolved to:
       - **Adjudicated AM-<n>:** `fable` (resolved <name>), <date>, diff review round <r>, finding <f>
     Its being upheld does not replace the user's approval; both go in the
     entry. A change
     the user asked for unprompted is not a claim: `- **Adjudicated AM-<n>:**
     requested by the user, <date>`. -->

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. check-boundaries.sh refuses any lint, type, coverage or
     mutation suppression a GREEN or GATES commit adds to source or config
     unless one line here names it. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-106` from `.claude/harness/models.conf`.
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
| DIFF-REVIEW | `lead-po` | `fable` | reading a whole diff for the defect no test was written for is judgement against the contract, and it is where a wrong call ships; a finding it labels goes back to GATES or RED, on opus |
| REVIEW | `lead-po` | `fable` | reading review feedback against the contract is orchestration judgement, and a wrong call here ships; a fix it finds goes back to GATES or RED, on opus |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation - code, with no failing test in front of any of it, so the stronger development model |
| ADJUDICATE | `lead-po` | `fable` | a claim that an acceptance criterion, a threshold or a frozen test is wrong is judged against the contract by a fresh dispatch on different inputs, never by the orchestrator that wants the answer; needed in any phase, so it is last |

**Resolved:**

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->

- PLANNED (2026-11-13, `/plan-story`): `lead-po`, planned `fable`, resolved **claude-fable-5-2** (Fable 5.2). Dispatched as a subagent by the orchestrating session; no override was reported to it, and the agent declares `model: fable`.
- No departure from the plan. All three criteria are mechanical, with settled values inside them (Contract, C-8).

## Out of scope

- **`scripts/check-boundaries.sh`.** Block 3k and every other block are
  unchanged. No story that passes today is refused and none that is refused
  passes.
- **The four cases themselves.** Their names, expected values and number stay.
  No new C-9 specimen is added, and none is rewritten by hand.
- **A run-time comparison of a copy against the story file it came from.**
  Considered and rejected: it could only run where the upstream file exists,
  so it is either a conditional assertion that does nothing in a consumer (and
  makes the executed count differ between trees, which the floor forbids) or
  an assertion that always passes there. The checksum of AC-2 pins the same
  bytes in every tree, and a DONE story's sections are a historical specimen
  whether or not the story file is later edited.
- **Reads of the real tree outside `docs/`.** `$REPO_ROOT/.github/workflows`
  (`ci-local.test.sh`), `$REPO_ROOT/CLAUDE.md` and the like are not judged by
  the new rule. Neither consumer's log shows a failure from them. A separate
  story if one is ever measured.
- **Data-flow analysis in the rule.** It reads text; C-5 states the limit.
- **`.claude/harness/docs-shipped.conf`, `scripts/refresh-harness.sh`,
  `.claude/tests/_lib.sh`.** Not changed. In particular `_lib.sh` is read by
  every suite, and editing its header to restate the rule would select the
  whole self-test for one sentence.
- **The story files `HARNESS-089`, `-095`, `-099`, `-102`.** Read once to
  make the copies; not edited.
- **Fixing the consumers.** They are repaired by refreshing to the release
  this story ships; nothing is edited in either project from here.
- **`rules.md`, `CLAUDE.md`, the skills.** No new prose rule; the suite
  carries it.

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
     and the next person needs to know why. One block per return, headed
     R-<n> (`### R-1 (the count test)`), and carrying its adjudication
     record - a line of its own, outside any comment or fence, written by
     the fresh `fable` dispatch (a `lead-po` on the ADJUDICATE row of
     models.conf) that judged the claim the test is wrong; the judgement is
     never the orchestrator's. check-boundaries.sh refuses a new entry
     without one:
       - **Adjudicated R-<n>:** `fable` (resolved <name>), <date>, <what it reproduced>
     A return that follows a diff-review or PR-feedback finding routed RED
     or AMEND was judged by that review, so the orchestrator writes the
     record, naming the round and finding (or the PR-feedback item) and the
     model the review was planned on and resolved to:
       - **Adjudicated R-<n>:** `fable` (resolved <name>), <date>, diff review round <r>, finding <f>
     Then:
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

- **Planned 2026-11-13 on `main` at `d686c39`.** The id was checked free on
  `origin/main`, remote branches and PR titles by the orchestrating session,
  and `docs/backlog/stories/HARNESS-106.md` did not exist.
- **HARNESS-105 is in flight and shares three files.** Branch
  `story/HARNESS-105-mutate-sh-counts-lines-past-the-windows-path-limit`
  (worktree `.claude/worktrees/loving-elbakyan-3fe420`), not merged. It sets
  `VERSION` to 124, raises the `mutate` floor 322 -> 328 in `floors.conf` and
  in `selftest.test.sh`, and appends a paragraph at the end of `floors.conf`.
  `plan.sh conflicts` may call the pair a CONFLICT on those three paths, and
  it is right about the files. The expected merge is trivial: `VERSION` is one
  line (take 125); the `floors.conf` rows differ (`mutate` against
  `boundaries` and `shipped-docs`) and both stories append a comment paragraph
  at the end (keep both, 105's first); the `selftest.test.sh` rows are
  different lines. This story plans 125 on the assumption that 105 merges
  first. If 106 would merge first, the order is put to the user before the PR
  is reported ready; the second PR waits for the first and re-runs its gates
  on the merged tree.
- **Why the fix is in RED.** See Contract, "Who writes which" and C-1. The
  subject is a test suite; the feature-developer writes no test file.
- **Measured at PLANNED, not assumed:** the four CRC and size pairs, the
  equality of both readers' output over copy and original (C-2), the absence
  of any other `REPO_ROOT` read under `docs/` (Context), that
  `scripts/selftest.sh` accepts two suite names, and the first consumer's log.
  **Not measured:** what the decoy `HARNESS-089.md` yields under the old
  reader; whether a clone runs the two suites cleanly (DV-2 finds out); the
  second consumer's own log beyond the orchestrator's account of it; and the
  `boundaries` and `shipped-docs` counts on this tree today (685 and 14 are
  the floors and the HARNESS-103 record, not a run of mine: the PLANNED run
  was stopped unfinished, and it left no run lock behind). RED's step 1 is
  the first measurement; 5 failed of 686 and 1 failed of 18 are what C-1
  expects, and a different total is reported, not fitted.
