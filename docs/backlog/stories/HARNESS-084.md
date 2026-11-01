---
id: HARNESS-084
title: A subagent's verification run is recorded against the tree it ran on, and the orchestrator checks the record instead of re-running
slug: a-subagent-s-verification-run-is-recorde
epic: 
type: feature
status: in-progress
phase: RED
branch: story/HARNESS-084-a-subagent-s-verification-run-is-recorde
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/attest.sh, .claude/hooks/lib.sh, .claude/tests/attest.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/tests/settings.test.sh, .claude/state/README.md, .claude/settings.json, .claude/agents/test-developer.md, .claude/agents/feature-developer.md, .claude/agents/lead-po.md, .claude/commands/advance-story.md, .claude/commands/complete-story.md, CLAUDE.md, .claude/harness/VERSION]
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

First of four stories cutting the cost of verification (HARNESS-084..087).
The user's finding: the orchestrator (`/advance-story`, `/complete-story`,
`lead-po`, all on `fable`) re-runs every verification a subagent has already
run against an unchanged tree. In RED the test-developer runs the tests and
`gates.sh --fast` (test-developer.md step 7), then the orchestrator runs both
again (advance-story.md, PLANNED → RED and RED → GREEN paragraphs). In GREEN
the feature-developer runs the tests, the full suite, `--fast` **and the full
`gates.sh`** (feature-developer.md steps 6-7), then the orchestrator runs the
tests and `--fast` again, and GATES runs the full `gates.sh` a second time,
overwriting GREEN's record so GREEN's full run leaves nothing behind. Every
return to RED repeats the loop. Measured on HARNESS-083, where every gate is
unconfigured and the cost is the story suite: `bash scripts/selftest.sh
boundaries` took 2407 s, 1931 s and 50m51s, and was run by the subagent and
then re-run by the orchestrator in each phase. The cost is not only wall
clock: each re-run is extra orchestrator turns, each turn re-sends the whole
standing context, and a 30-50 minute wait outlasts the prompt cache.

The law stays intact. Law 1's "watched to fail" and GREEN's confirmation of
negative controls are **shown** in the handoff, not claimed; what changes is
that the orchestrator's check of "did that command run against this tree, and
what did it say" becomes a script's answer rather than a second run. The
mechanism follows `gates.sh`: a run is stamped with the hash of the gated
tree it ran on (`gate_tree_hash`, HARNESS-014), and a stamp that does not
match the tree is not evidence. The one difference is that the record here is
machine-local and never read by CI - it stands in for the orchestrator's
re-run, not for `## Gate results`, which `gates.sh` alone still writes.

Two side effects the user asked for come with it: the subagent's full
`gates.sh` in GREEN goes (GATES runs it; GREEN keeps `--fast`), and the
command's output lands in a log file with only its tail printed, so an
untrimmed suite run no longer lands in the orchestrator's context.

The gate that fails if this breaks is `bash scripts/selftest.sh attest` (a
new suite); the prose criteria are structural guards over the real tree, in
the shape of `procedure.test.sh` and `policy.test.sh`.

## Acceptance criteria

- **AC-1** — Given a project fixture and a command that prints two lines and
  exits 3, when `bash scripts/attest.sh -- <command>` runs, then it exits 3,
  prints the record it wrote followed by the command's last lines, and
  `.claude/state/attest.log` ends with a block carrying `command:` (the words
  joined by one space), `tree:` (the work hash, C-2), `status: ok`,
  `exit: 3`, `last:` (the command's last non-blank line), `duration:` and
  `log:` naming a file under `.claude/state/attest-logs/` that holds the
  command's full output. *Control:* a leading `NAME=value` word is exported to
  the command (the command prints `$NAME` and the log shows `value`) and is
  part of `command:`.
- **AC-2** — Given AC-1's record, when `bash scripts/attest.sh check --
  <the same words>` runs on the unchanged tree, then it prints that record
  and a last line `fresh`, exit 0. *Controls:* a different command, or the
  same words in another order, answers `none`, exit 1; after a tracked
  `source` file is edited, `stale`, exit 1, naming the recorded and the current
  hash; after an untracked, non-ignored `test` file is created, and again
  after its content changes, `stale`, exit 1; after only a `docs` file is
  edited, still `fresh`, exit 0.
- **AC-3** — Given a command that edits a tracked `source` file while it
  runs, when `attest.sh -- <command>` runs, then the command's exit status is
  passed through, the block carries `status: void` with the words `tree
  changed during the run`, and `attest.sh check` for it answers `void`, exit 1.
  *Control:* a command that writes only an ignored path (under
  `.claude/state/`) records `status: ok`.
- **AC-4** — Given a `mutations/*.active` marker in `.claude/state/`, when
  `attest.sh -- <command>` runs, then it refuses before running the command
  (the command's side effect does not appear), prints `mutate.sh --check`'s
  report and exits 2.
- **AC-5** — Given the real tree, when the suite's structural guard
  (`attest_problems <root>`, C-5) runs over `REPO_ROOT`, then it prints
  nothing; and over fixtures compliant by construction with one site
  regressed, it prints exactly the one line C-5 pins for that regression. The
  sites: feature-developer.md's `## Method` no longer runs the full
  `` `bash scripts/gates.sh` `` and runs `--fast` through `attest.sh`;
  test-developer.md's test and `--fast` steps run through `attest.sh`;
  advance-story.md's `**PLANNED → RED.**` and `**RED → GREEN.**` regions each
  name `bash scripts/attest.sh check` and neither says `run the tests
  yourself`; complete-story.md and lead-po.md's `## Orchestrating` name
  `bash scripts/attest.sh check`; both commands' `allowed-tools` carry
  `Bash(bash scripts/attest.sh check:*)` and no entry `Bash(bash
  scripts/attest.sh:*)`. This criterion can only be checked
  structurally: nothing executes the prose, and the suite pins that the
  instruction is present where the orchestrator reads it, not that a model
  follows it.
- **AC-6** — Given `.claude/state/README.md` and `.claude/settings.json`,
  when `bash scripts/selftest.sh settings` runs, then it passes with the two
  new rows: `attest.log` hand-editable `no` (it is read as evidence, so
  `Edit(./.claude/state/attest.log)` is denied) and `attest-logs/*.log`
  hand-editable `yes`.

## Amendments

**A-1 (2026-11-01, approved by the user, "Approve, fix all four"; from diff
review round 1, finding 2, reproduced by the orchestrator).** AC-5's last
site said: both commands' `allowed-tools` carry `Bash(bash
scripts/attest.sh:*)`. It now says: they carry `Bash(bash scripts/attest.sh
check:*)` and no entry `Bash(bash scripts/attest.sh:*)`. Why: the prefix
entry auto-approves `attest.sh -- <any command>`, and it was the only
allowed-tools entry in either command that runs arbitrary words
(orchestrator read `advance-story.md`'s list: `task.sh` runs named tasks
only, `mutate.sh` is not listed). The orchestrator needs only `check`; a
`stale` answer it re-runs directly.

**A-2 (2026-11-01, approved by the user, same answer; from diff review round
1, finding 1, reproduced by the orchestrator).** Not an acceptance criterion
but the Contract's C-2, which RED had amended to "stays on harness
markdown". It now says the work hash **moves** on harness markdown too
(`.claude/agents/*.md`, `.claude/commands/*.md`, `CLAUDE.md`, skills), and
stays only on `docs`, `vendor`, `ignored` and `.claude/state/`. Why: the
harness's own suites read those files, so a pass recorded before an
instructions edit stayed `fresh` after it. Reproduction, on a different file
from the reviewer's: `work_tree_hash` before, after appending a line to
`.claude/commands/status.md`, and after restoring it, was
`6c032341136e5bb1cd2c9611af5bcc29404c855c` all three times.
`gated_stdin` and `gate_tree_hash` are unchanged (C-10 stands).

Findings 3 and 4 (env assignments clobbering attest.sh's own variables; a
newline in a word forging a record) change no criterion: C-1 gains that a
word containing a newline or CR is a usage error (exit 2), and that
assignments reach the command only, never attest.sh's own shell. Finding 5
is out of scope (see `## Out of scope`).

## Contract

**Writes:** `scripts/attest.sh`, `.claude/hooks/lib.sh`, `.claude/tests/attest.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/tests/settings.test.sh`, `.claude/state/README.md`, `.claude/settings.json`, `.claude/agents/test-developer.md`, `.claude/agents/feature-developer.md`, `.claude/agents/lead-po.md`, `.claude/commands/advance-story.md`, `.claude/commands/complete-story.md`, `CLAUDE.md`, `.claude/harness/VERSION`

RED may amend any block in place, with a reason; GREEN builds what the
amended block says.

**C-1. `scripts/attest.sh` - the command surface.**

    bash scripts/attest.sh -- <word>...          run the words, record the run, exit with the command's status
    bash scripts/attest.sh check -- <word>...    is there a fresh record for exactly these words on this tree?
    bash scripts/attest.sh show                  every record whose tree: is the current work hash

The words after `--` are executed directly (`"$@"`), never through a shell:
no globbing, no quoting rules beyond the caller's. Leading words matching
`^[A-Za-z_][A-Za-z0-9_]*=` are exported into the command's environment and
stripped from what is executed, so `SELFTEST_JOBS=4 bash scripts/selftest.sh`
is one attestable command. The recorded `command:` is **all** the words,
assignments included, joined by one space; `check` compares that string for
equality, so `a b` and `b a` are different commands (AC-2's control).
Usage errors (no `--`, nothing after it, an unknown first word) exit 2.

*Amended on return 3 to RED (test-developer, 2026-11-01; diff review round 1,
findings 3 and 4; see `## Amendments`, the paragraph after A-2).*
- **Assignments reach the command only.** The leading `NAME=value` words are
  passed to the command through its environment (`env "${assigns[@]}" "$@"`),
  never set in attest.sh's own shell. So `ROOT=`, `ALOG=` and `HARNESS_ROOT=`
  (or any name attest.sh uses) change neither where the record and the log
  land, nor which tree is hashed, nor whether AC-4's mutation refusal runs; the
  command still sees the value. Pinned: `attest.sh -- ROOT=<dir> <cmd>` and
  `ALOG=<file> ...` record in this tree's `.claude/state/attest.log`, with the
  log under this tree's `.claude/state/attest-logs/`, nothing written at
  `<dir>`/`<file>`, and the command printing the value it was given;
  `HARNESS_ROOT=<dir> ...` records `status: ok` with `after:` this tree's work
  hash; with a `mutations/*.active` marker, `ROOT=<dir>` and `ALOG=<file>` are
  still refused, exit 2, the command not run.
- **A word containing a newline (LF) or a carriage return (CR) is a usage
  error**, exit 2, in both `--` and `check --`, assignment words included:
  nothing is run and nothing is appended to attest.log. A newline in a word
  otherwise writes extra lines into the record, so a forged `command:` line
  makes `check` answer `fresh` for a command that never ran. Pinned: after the
  refused attempts, `check -- bash scripts/gates.sh --fast` (the words the
  injection named) answers `none: no record for this command`, exit 1.

**C-2. The work hash.** `gate_tree_hash` (lib.sh) covers tracked and staged
gated files - the tree `git commit -a` would make - and leaves untracked
files out. A RED subagent's new test file is usually untracked, so a record
keyed only to that hash could not tell its edits apart. New lib.sh function,
appended at the end of the file:

    work_tree_hash   # stdout: one hash; the gate_tree_hash listing plus one
                     # `<blob>\t<path>` line per untracked_gated file, blob
                     # from `git hash-object`, through _hash_blob_listing.
                     # Prints `unavailable` and returns 1 when either part fails.

Semantics: the hash moves when any tracked, staged **or untracked** `source`,
`test` or `config` file changes content, and stays when only `docs`,
`harness`, `vendor` or `ignored` paths change (AC-2's docs control, AC-3's
ignored-path control). `gated_stdin` is the existing filter and defines
"gated" here; nothing new decides it. `unavailable` is never `fresh`.

*Amended in RED (test-developer, 2026-11-01).* "stays when only ...
`harness` ... paths change" contradicts the sentence after it: `gated_stdin`
KEEPS non-markdown `harness` files (hooks, scripts, `project.conf`) and drops
only harness **markdown** and `.claude/state/`. Since `gated_stdin` is the
settled definition, the semantics read: the hash stays when only `docs`,
harness **markdown**, `vendor`, `ignored` or `.claude/state/` paths change; a
change to a hook or a script moves it, as it moves `gate_tree_hash`. The suite
pins harness markdown (untracked `.claude/commands/new.md`) as not moving it
and pins nothing about non-markdown harness files. Also pinned, read out of
the listing shape: with no untracked gated file, `work_tree_hash` **equals**
`gate_tree_hash`; and an untracked file is hashed exactly as `gate_tree_hash`
hashes it once `git add`-ed. Outside a repository it prints `unavailable`
once (not twice) and returns 1.

*Amended on return 3 to RED (test-developer, 2026-11-01; A-2, approved by the
user).* The paragraph above is superseded where it speaks of harness markdown.
The semantics now read: **the work hash moves when any tracked, staged or
untracked `source`, `test`, `config` or `harness` file changes content -
harness markdown included (`.claude/agents/*.md`, `.claude/commands/*.md`,
`.claude/skills/**`, `CLAUDE.md`) - and stays only when `docs`, `vendor`,
`ignored` or `.claude/state/` paths change** (markdown under `.claude/state/`
included). `gated_stdin` and `gate_tree_hash` are **unchanged** (C-10 stands):
`work_tree_hash` gets its own filter - `gated_stdin`'s minus its
harness-markdown exclusion - and therefore cannot hash through
`_hash_blob_listing`, which applies `gated_stdin` itself; it builds the same
`<blob>  <path>` lines, `LC_ALL=C sort`, `git hash-object --stdin`, over its own
filter. The listing shape (line format, sort, hash) is still `_hash_blob_listing`'s,
read out. So the two pinned equalities with `gate_tree_hash` now hold **only
while the tree carries no harness markdown**, and the suite pins them on a
fixture that tracks none (make_project_fixture's one `.md` is `docs/notes.md`):
with nothing untracked, work hash == `gate_tree_hash`; an untracked `test` file
is hashed exactly as `gate_tree_hash` hashes it once staged. Also pinned: an
untracked `.claude/commands/new.md`, its content change, and an untracked
`.claude/skills/x/SKILL.md` each move it; committing `.claude/agents/role.md`
and `CLAUDE.md` moves it while `gate_tree_hash` stays put (C-10); an unstaged
edit to either tracked file moves it, and the undo returns it; and against
that tree, a docs edit, an untracked docs file, `dist/out.js`, an ignored
`scratch/out.ts` (source by name, gitignored) and writes under `.claude/state/`
leave it put. AC-2 pins the same through `check`: an edit to a tracked
`.claude/agents/role.md`, and to a tracked `CLAUDE.md`, answers `stale`, exit 1.

**C-3. The record.** Appended to `.claude/state/attest.log`, one block per
run, blank-line separated, fields in this order:

    run:      <RUN_STARTED_AT, UTC, the gates.sh stamp format>
    command:  <words joined by one space>
    tree:     <work hash before the command started>
    after:    <work hash when it exited>
    status:   ok | void: tree changed during the run | void: hash unavailable
    exit:     <the command's exit status>
    duration: <whole seconds>s
    last:     <last non-blank line of the command's combined output, or `(no output)`>
    log:      .claude/state/attest-logs/<run>.<pid>.log

The command's stdout and stderr go to the log file, not the terminal. After
it exits, attest.sh prints the block it wrote, then a line `--- last N lines
of <log> ---` and the last `ATTEST_TAIL` lines (default 20) of the log. It
never prints the whole output: that is the point. `status:` is `void` when
`tree:` and `after:` differ (AC-3) or either is `unavailable`; the command's
exit status is passed through regardless of status.

*Amended in RED (test-developer, 2026-11-01).*
- **The log's file name has no colons.** `<run>` in the gates.sh format
  contains `:`, which NTFS does not allow in a file name and git for Windows
  refuses to track. The name is `<run with every - and : removed>.<pid>.log`,
  i.e. `.claude/state/attest-logs/20261101T044441Z.1234.log` - mutate.sh's
  `STAMP` shape. The suite pins `^\.claude/state/attest-logs/[0-9]{8}T[0-9]{6}Z\.[0-9]+\.log$`
  and that its stamp equals `run:` with `-` and `:` removed.
- **The header names the `log:` path as written in the block** (relative,
  `.claude/state/attest-logs/...`): `--- last 20 lines of <log:> ---`. N is
  pinned only where the output is at least N lines long (30 lines, default 20;
  `ATTEST_TAIL=5`); for a shorter output N is unconstrained.
- **Padding** between `key:` and its value is not pinned (one or more
  spaces); the field names, their order, and that there are no others are.
- **The root is attest.sh's own** `scripts/..`, as gates.sh's is - not
  `CLAUDE_PROJECT_DIR`. The suite exports `CLAUDE_PROJECT_DIR` as the real
  repository while driving a fixture's attest.sh, so a script that read the
  variable would hash the wrong tree.
- **The printed block equals the block appended to attest.log**, byte for byte
  (a CR-free comparison of lines), and the command's output appears on stdout
  only once, in the tail; its stderr goes to the log, not to attest.sh's
  stderr.

**C-4. `check`.** Reads the log, takes the newest block whose `command:`
equals the joined words. Answers, as the last line of stdout:

| Case | Last line | Exit |
|---|---|---|
| no block for these words | `none: no record for this command` | 1 |
| newest block is `void` | `void: <its status text>` | 1 |
| its `tree:` differs from the current work hash | `stale: recorded on <tree> at <run>, the tree is now <hash>` | 1 |
| equal | the block, then `fresh` | 0 |

`fresh` says the command ran on this tree; it says nothing about whether it
passed. The orchestrator reads `exit:` and `last:`, and the log when it needs
more. That split is deliberate: a RED run is supposed to exit non-zero, and a
`check` that folded the exit status into its own would call a correct RED
`stale`.

Before running (AC-4), `attest.sh` runs `bash scripts/mutate.sh --check` and
refuses with its report, exit 2, when it is not clean - the same refusal
`gates.sh` makes (HARNESS-030): a run inside a mutation is a run on a tree
nobody will ever see again.

*Amended in RED (test-developer, 2026-11-01).*
- **The `void` row's last line is the block's `status:` value verbatim**:
  `void: tree changed during the run` (or `void: hash unavailable`), not
  `void: void: ...`. The table's `void: <its status text>` read both ways.
- **The rows are checked in the table's order, and `void` outranks the hash
  comparison**: a void record stays `void` after the tree is put back to its
  `tree:`. Pinned.
- **"Newest" is pinned**: when an older block for the same words matches the
  current tree and the newest does not, the answer is `stale` against the
  newest.
- **A refusal (AC-4) and a usage error record nothing**: attest.log is
  byte-identical afterwards. `attest.sh true` (a command with no `--`) is a
  usage error, exit 2. `check` and `check --` are usage errors, exit 2.
- `fresh`'s preceding lines (trailing blank lines dropped) equal the block as
  it stands in attest.log.

**C-5. The structural guard and its sites.** `attest_problems <root>` in
`.claude/tests/attest.test.sh`, one line `<path>: <reason>` per violation,
silent on a compliant tree, modelled on `procedure_problems`. Regions are
the ones `reporting.test.sh` and `procedure.test.sh` already define: a phase
paragraph of advance-story.md runs from a line beginning `**X → Y.**` to the
next such line; `## Orchestrating` in lead-po.md runs to the next `## `;
`## Method` in feature-developer.md and test-developer.md is the numbered
list under that heading.

| Site | Must hold | Reported as |
|---|---|---|
| `.claude/agents/feature-developer.md` `## Method` | no line contains `` `bash scripts/gates.sh` `` (closing backtick directly after `.sh`) | `still runs the full gate run in GREEN` |
| same | a line contains `bash scripts/attest.sh -- bash scripts/gates.sh --fast` | `does not run --fast through attest.sh` |
| `.claude/agents/test-developer.md` `## Method` | a line contains `bash scripts/attest.sh --` and a line contains `bash scripts/attest.sh -- bash scripts/gates.sh --fast` | `does not run its tests through attest.sh` / `does not run --fast through attest.sh` |
| `.claude/commands/advance-story.md`, `**PLANNED → RED.**` region and `**RED → GREEN.**` region, each | contains `bash scripts/attest.sh check`; does not contain `run the tests yourself` | `<region> does not check the record` / `<region> still re-runs the tests` |
| `.claude/commands/complete-story.md` | contains `bash scripts/attest.sh check` | `does not check the record` |
| `.claude/agents/lead-po.md` `## Orchestrating` | contains `bash scripts/attest.sh check` | `does not check the record` |
| both commands' frontmatter `allowed-tools` | an entry equal to `Bash(bash scripts/attest.sh check:*)` (procedure's `has_entry` semantics: equal, trimmed, not contained) | `does not permit attest.sh check` |
| same | **no** entry equal to `Bash(bash scripts/attest.sh:*)` (same semantics) | `permits attest.sh to run any command` |

*The two `allowed-tools` rows are amended on return 3 to RED (A-1, approved by
the user).* Before A-1 the one row required `Bash(bash scripts/attest.sh:*)`,
reported as `does not permit attest.sh`. A command still carrying that old
entry alone fails both rows and prints both lines, check row first.

The needle `` `bash scripts/gates.sh` `` is anchored by its closing backtick:
it matches today's step 7 (`Run `bash scripts/gates.sh`. Fix what it
reports.`) and not `` `bash scripts/gates.sh --fast` ``. Step 7's guidance
about `## Gate results`, evidence lines and waivers is not deleted; it moves
out of the numbered list into a paragraph for a GATES dispatch and refers to
the full run as `` `scripts/gates.sh` without `--fast` ``, which the needle
does not match. Steps 8-9 renumber to 7-8; `briefs.test.sh` pins step 2's
pointer and the `## Reuse before you write` section, neither of which moves.

*Amended in RED (test-developer, 2026-11-01).*
- **test-developer's tests needle.** `bash scripts/attest.sh --` is a prefix
  of `bash scripts/attest.sh -- bash scripts/gates.sh --fast`, so "a line
  contains `bash scripts/attest.sh --`" is satisfied by the `--fast` line
  alone and cannot fail once the `--fast` row holds. The rule is: within the
  numbered list, `bash scripts/attest.sh --` occurs **more often** than the
  `--fast` needle - i.e. at least one attested run that is not the `--fast`
  one.
- **Regions.** "The numbered list" is: from the first `^[0-9]+\. ` line
  after `## Method`, taking step lines, indented continuation lines and blank
  lines, up to the first other line (an unindented paragraph) or the next
  `## `. A paragraph after the list, inside `## Method`, is outside it. The
  feature-developer and test-developer rows are judged **per line** (keep each
  needle on one line). The advance-story regions run from the line beginning
  `**X → Y.**` to the next line matching `^\*\*[^*]+ → [^*]+\.\*\*` - so a
  bold non-phase line such as `**Pin the `## Contract`.**` does not end
  `PLANNED → RED` - and are judged with their lines joined by one space, so a
  phrase wrapped over two lines is found. complete-story is the whole file,
  joined the same way; lead-po is `## Orchestrating` to the next `## `, joined.
- **`<region>`** in the advance-story reasons is the heading without its
  asterisks and period: `PLANNED → RED`, `RED → GREEN`. So:
  `.claude/commands/advance-story.md: PLANNED → RED does not check the record`.
- **Structural failures**, each one line: `<path>: file is missing`;
  `<path>: has no `## Method` section`; `.claude/commands/advance-story.md: has
  no `**PLANNED → RED.**` paragraph` (likewise `RED → GREEN`);
  `.claude/agents/lead-po.md: has no `## Orchestrating` section`; and, for a
  command without one, `<path>: has no `allowed-tools:` line in its frontmatter`
  (procedure's wording) in place of `does not permit attest.sh`.
- **Output order**: feature-developer (full run, then --fast), test-developer
  (tests, then --fast), advance-story (tool, then PLANNED → RED check / re-run,
  then RED → GREEN check / re-run), complete-story (tool, then check), lead-po.

*Amended on return 3 to RED (test-developer, 2026-11-01).*
- **Tool lines.** "tool" in the output order is now two checks, in this order:
  `does not permit attest.sh check`, then `permits attest.sh to run any
  command`.
- **complete-story is judged on its body, not the whole file.** The body is
  every line after the `---` that closes a first-line `---` (the whole file
  when there is no frontmatter). A-1's required entry `Bash(bash
  scripts/attest.sh check:*)` itself contains the needle `bash
  scripts/attest.sh check`, so a whole-file judgement could not fail while the
  entry stood; the existing `cs-check` fixture (needle removed from the body,
  entry kept) went silent on the first run of this return, which is how it was
  found. advance-story's regions and lead-po's section never include
  frontmatter, so they are unaffected.

**C-6. What the prose says, in substance.** GREEN writes the words; these are
the obligations. test-developer.md steps 4 and 7: run the test command and
`--fast` as `bash scripts/attest.sh -- <command>`, and paste the `last:`
line and the log path into the handoff beside the verbatim failure the law
already requires. feature-developer.md step 6: `bash scripts/attest.sh --
bash scripts/gates.sh --fast`; the full run is GATES' (the orchestrator
dispatches it there - HARNESS-085 moves that dispatch off the orchestrator).
advance-story.md: after each dispatch returns, read the files it wrote, then
`bash scripts/attest.sh check -- <command>` for the test command and for
`bash scripts/gates.sh --fast`; **run the command yourself only when the
answer is not `fresh`**, and say in the story which it was. The RED
verification "fail for the right reason" is read from the log the record
names, not from a re-run. lead-po.md `## Orchestrating`: the ladder's first
rung becomes "a report of success is a claim; `attest.sh check` is how you
check it without paying for the run twice; `stale` means you run it". CLAUDE.md
`## Running things` gains one line in the block's existing shape:
`bash scripts/attest.sh -- CMD        # run CMD, record it against the tree; `check -- CMD` instead of a re-run`.

**C-7. State and settings.** `.claude/state/README.md` rows, in the table's
existing shape: `attest.log` | `scripts/attest.sh` | `scripts/attest.sh check`,
and the orchestrator | **no**; `attest-logs/*.log` | `scripts/attest.sh` |
you, and the story that quotes it | yes. `settings.json` deny gains
`"Edit(./.claude/state/attest.log)"`, per file, like the two it joins.
`settings.test.sh` checks the table and the rules against each other in both
directions and needs no change. Both are `ignored` to the phase lock already
(`.claude/state/*` is gitignored and no `paths.conf` rule classifies it).

*Amended in RED (test-developer, 2026-11-01).* Measured, the last sentence is
not so: `bash scripts/classify.sh .claude/state/attest.log` prints `harness`
(a `paths.conf` rule classifies it before the gitignore is consulted). Nothing
turns on it: `harness` is writable in every phase, and `gated_stdin` drops
`.claude/state/` explicitly, so neither the lock nor the work hash cares.

*Amended on the return to RED (test-developer, 2026-11-01).* "`settings.test.sh`
... needs no change" is wrong. Besides the table/rule agreement it holds
HARNESS-050's `AC-1/C-1: the deny array is exactly the seven C-1 rules, in
order`, which pins the **whole** deny array; no `settings.json` can satisfy
both that and this story's AC-6. That one assertion now pins the eight rules,
in order, with `"Edit(./.claude/state/attest.log)"` directly after
`"Edit(./.claude/state/last-gate-run)"` - where GREEN put it. No other
assertion in the suite changes, and the assertion count does not move.
`.claude/tests/settings.test.sh` is added to `**Writes:**` and `touches:`.
See `## Regressions`.

**C-8. The suite.** `.claude/tests/attest.test.sh`, sourcing `_lib.sh`,
fixture from `make_project_fixture` (a git repository with the harness
scripts, `paths.conf` and a `src/`, `tests/` layout - RED confirms which
categories its fixture paths classify to with `bash scripts/classify.sh`
before asserting on them). Commands under test are tiny scripts the suite
writes (`printf` two lines and `exit 3`; one that appends to `src/x.sh`; one
that writes under `.claude/state/`). Floors: a `floor | attest | N` row in
`floors.conf` and the same N in `selftest.test.sh`'s table, N the executed
count read off a run. No suite other than `attest` and `settings` reads a
file this story writes, except `briefs` (feature-developer.md's step 2 and
reuse ladder, unchanged), `procedure` (allowed-tools membership and the
GATES → REVIEW steps, unchanged by this story), `reporting` (`## Orchestrating`
heading, unchanged), `phase` (`bash scripts/plan.sh after` in lead-po.md,
kept) and `mutate` (one exact CLAUDE.md line, kept).

**C-9. Oracle partition.** Every criterion is **mechanical**: pin exactly.
Settled values to read out, not re-derive: the stamp format and the
`gate_tree_hash` listing shape (`lib.sh`), `has_entry` semantics
(`procedure.test.sh`), the README table shape. Nothing is oracle-free.

**C-10. No existing export changes signature.** `gate_tree_hash`,
`untracked_gated` and `_hash_blob_listing` are called, not changed; their
callers (`gates.sh`, `check-boundaries.sh`, `selftest-needed.sh`) are
untouched.

## Deferred verifications

**DV-1 (defect put back). Owner: GATES.** With the `after:` comparison in
`attest.sh` disabled - a `mutate.sh` expression that makes the script treat
`tree:` and `after:` as equal - AC-3's `status: void` assertion **must** go
red and nothing else in the suite should. RED cannot run this: there is no
`attest.sh` to mutate. Run against `bash scripts/selftest.sh attest`; paste
the red, the count and the restore.

Result (GATES, 2026-11-01): red as required. Three assertions, all AC-3's
void block - its `status:`, `check`'s `void`, and void-after-restore - and
nothing else.

```
=== mutate: scripts/attest.sh (1 line(s) changed by s/elif \[ "\$TREE" != "\$AFTER" \]; then/elif false; then/) ===
  171 - elif [ "$TREE" != "$AFTER" ]; then
  171 + elif false; then
=== mutate: running bash scripts/selftest.sh attest ===
  AC-3  a command that edits a tracked source file: void, exit passed through
    FAIL status: void: tree changed during the run
    FAIL check answers void, with the status text
    FAIL void even once the tree is back to the recorded tree:
attest: 120 passed, 3 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_attest.sh.20261101T174310Z.623.bak) ===
  171: elif [ "$TREE" != "$AFTER" ]; then
```

**DV-2 (a rule probed against the tree it judges). Owner: GATES.** With a
real line of `.claude/agents/feature-developer.md` mutated to put
`` Run `bash scripts/gates.sh`. `` back into `## Method`, `attest_problems
"$REPO_ROOT"` **must** print exactly one line, `still runs the full gate
run in GREEN`, and nothing with the file restored. RED's fixtures say the
guard is right about what it imagined; this says it is right about the file
that is there.

Result (GATES, 2026-11-01): exactly the one line, and silent again once the
real file was restored (`bash scripts/selftest.sh attest` green beforehand).

```
=== mutate: .claude/agents/feature-developer.md (1 line(s) changed by 73s/^7\. /7. Run `bash scripts\/gates.sh`. /) ===
  73 - 7. If this story added or changed a gate, break what it guards, watch it fail,
  73 + 7. Run `bash scripts/gates.sh`. If this story added or changed a gate, break what it guards, watch it fail,
    FAIL attest_problems over REPO_ROOT prints nothing
         actual:   .claude/agents/feature-developer.md: still runs the full gate run in GREEN
attest: 122 passed, 1 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_agents_feature-developer.md.20261101T174718Z.7393.bak) ===
  73: 7. If this story added or changed a gate, break what it guards, watch it fail,
```

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-084` from `.claude/harness/models.conf`.
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

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

- Dispatching the full `gates.sh`, the self-test and `check-boundaries.sh`
  to an opus subagent: HARNESS-085, which builds on this record.
- Reading the story by section, and trimming `rules.md`: HARNESS-086 and
  HARNESS-087.
- `## Gate results`, `last-gate-run` and the Stop hook: unchanged. The
  attest record is never evidence to CI; `check-boundaries.sh` does not read
  it and must not start to.
- `ci-local.sh`: it mirrors the workflow files by construction
  (`ci-local.test.sh` derives its steps from them) and is not made to skip
  anything.
- A consuming project's `test` task in `project.conf`: the subagents attest
  whatever command the story names; no new `project.conf` grammar.
- Recording argument boundaries in `command:` (diff review round 1, finding
  5): `runner "a b"` and `runner a b` record the same string. Rare; the
  orchestrator still reads `exit:` and `last:`. A follow-up if wanted.
- Pruning the attest log. It is machine-local exhaust; the README says it is
  safe to delete.

## Test plan

One suite, `.claude/tests/attest.test.sh`, run by `bash scripts/selftest.sh
attest`. Every criterion is mechanical (C-9), so every assertion pins an exact
string, exit status or hash relation; nothing is thresholded. Levels:

| Block (`describe`) | Level | Covers | Assertions |
|---|---|---|---|
| C-2 work_tree_hash | unit: the fixture's own `lib.sh` sourced, function called | C-2; the hash AC-2/AC-3 rest on | 19 |
| AC-1 attest.sh -- <command> | integration: `scripts/attest.sh` run in a `make_project_fixture` tree | AC-1 + control; C-1 "executed directly"; C-3 tail | 28 |
| C-1 usage errors | integration | C-1 exit 2; records nothing | 7 |
| AC-2 check | integration | AC-2 + all its controls | 22 |
| AC-3 void | integration | AC-3 + control | 14 |
| C-4 newest block | integration | C-4 "newest" | 2 |
| AC-4 stranded mutation | integration (planted `.active`, dead pid, as gates.test.sh's HARNESS-030 block) | AC-4 + control | 8 |
| AC-5 real tree | structural guard over `REPO_ROOT` | AC-5 | 1 |
| AC-5 fixtures | structural guard over trees compliant by construction, one site regressed each | AC-5, C-5's table row by row | 19 |
| AC-6 rows | structural: README table (settings.test.sh's own `rows` parser, copied) and settings.json | AC-6 | 3 |

123 executed assertions; none is conditional, so the count is the same red or
green.

**Return 3 (diff review round 1, A-1/A-2):** 165 executed assertions, still none
conditional. C-2 work_tree_hash 19 -> 28; AC-2 22 -> 27; new block "C-1 a
leading assignment reaches the command only" 15; new block "C-1 a word holding
a newline or a CR" 10; AC-5 fixtures 19 -> 22. See `## Regressions`, Return 3. AC-6's other half - the rows and the deny rule agree in both
directions - is `bash scripts/selftest.sh settings`, unchanged; see the handoff.

## Handoff: RED -> GREEN

RED by `test-developer`, on `claude-opus-5-5` (Opus 5.5), as declared; no
override.

**Read the Contract first: C-2, C-3, C-4, C-5 and C-7 carry RED amendments in
place** (each headed *Amended in RED*). The suite pins the amended text.

### Command

    bash scripts/selftest.sh attest

(`bash .claude/tests/attest.test.sh` runs the same suite without the run lock;
`VERBOSE=1` names every passing assertion too.) Runtime here: about 6 s red;
green will be longer (each attest/check call hashes the fixture twice) - well
inside anything, no per-test timeout exists in this harness.

### Files touched

- `.claude/tests/attest.test.sh` - new suite (all ACs).
- `.claude/tests/floors.conf` - `floor | attest        | 123`, above `boundaries`.
- `.claude/tests/selftest.test.sh` - `attest 123` in the COUNTS table, above `boundaries 502`.
- `docs/backlog/stories/HARNESS-084.md` - Contract amendments, `## Test plan`, this handoff.

Nothing else. `scripts/attest.sh`, `lib.sh`, the agent/command prose, the
README, settings.json, CLAUDE.md and VERSION are GREEN's and untouched.

### The failure, and why it is the right one

`attest: 22 passed, 101 failed`. Three causes, and only three:

1. `scripts/attest.sh` does not exist: every attest call exits 127 with
   `bash: scripts/attest.sh: No such file or directory` on stderr, no
   `attest.log` exists, so every exit-status, field, block, check-line and
   "records nothing" assertion is red. That is AC-1..AC-4 and C-1/C-4.
2. `work_tree_hash` is not defined in `lib.sh`: `whash` prints nothing and
   returns 127, so every C-2 assertion is red (the hash helpers refuse an empty
   string, so "" = "" never passes), and every AC assertion that compares a
   recorded `tree:` against the work hash is red on both counts.
3. The real tree's prose and state files are unchanged: `attest_problems
   "$REPO_ROOT"` prints the 12 lines below, and the README/settings.json lack
   the rows (AC-6).

No assertion is red for any other reason: no syntax error (`bash -n` clean),
`check-sigpipe.sh` and `check-grep-count.sh` report 0 findings on the file,
and the fixture preconditions that touch existing code are green (gate_tree_hash
control, `mutate.sh --check` precondition).

Verbatim excerpts of that run (contiguous; `[...]` marks omitted runs of the
same shape):

```
=== attest ===

  C-2  work_tree_hash: one hash, moving on gated content tracked, staged or untracked
    FAIL work_tree_hash prints one hash on a clean tree
         printed: []
    FAIL work_tree_hash returns 0 on a clean tree
         expected: 0
         actual:   127
    FAIL with nothing untracked it IS gate_tree_hash: the same listing, plus no lines
         expected the hash: fb834a3d689099803fc3fc68f1e2813c9d020fed
         actual:            
    FAIL an untracked test file moves the work hash
         expected two different hashes:
         before: 
         after:  
    FAIL an untracked file is hashed exactly as gate_tree_hash hashes it once staged
         expected the hash: 4f31c2296ea34f1abed62c1552e48ffde7331bee
         actual:            
[...]
    FAIL outside a repository work_tree_hash prints exactly `unavailable`
         expected: unavailable
         actual:   
    FAIL and returns 1
         expected: 1
         actual:   127

  AC-1  attest.sh -- <command>: exit passed through, the record, then the tail
    FAIL the command's exit status, 3, is attest.sh's
         expected: 3
         actual:   127
    FAIL attest.log's last block has exactly C-3's fields, in C-3's order
         expected: run command tree after status exit duration last log
         actual:   
[...]
    FAIL the command's stderr goes to the log, not to attest.sh's stderr
         log: []
         attest.sh's stderr: bash: scripts/attest.sh: No such file or directory
[...]
    FAIL control: NAME=value is stripped from what is executed (exit 0, not 127)
         expected: 0
         actual:   127
[...]
  C-1  usage errors exit 2 and record nothing
    FAIL no arguments: exit 2
         expected: 2
         actual:   127
[...]
  AC-2  check: fresh on the unchanged tree; none, stale, or still fresh on a docs edit
    FAIL same words, unchanged tree: the last line is fresh
         expected: fresh
         actual:   
[...]
    FAIL after a tracked source edit: stale, naming the recorded and the current hash
         expected: stale: recorded on  at , the tree is now 
         actual:   
[...]
  AC-3  a command that edits a tracked source file: void, exit passed through
    FAIL the command's exit status, 5, is passed through
         expected: 5
         actual:   127
    FAIL status: void: tree changed during the run
         expected: void: tree changed during the run
         actual:   
[...]
  AC-4  a stranded mutation: refused before running, mutate.sh's report, exit 2
    FAIL attest.sh exits 2
         expected: 2
         actual:   127
    FAIL it prints mutate.sh --check's report
         expected: 1
         actual:   0
[...]
  AC-5  the guard is silent on the real tree
    FAIL attest_problems over REPO_ROOT prints nothing
         expected: 
         actual:   .claude/agents/feature-developer.md: still runs the full gate run in GREEN
         .claude/agents/feature-developer.md: does not run --fast through attest.sh
         .claude/agents/test-developer.md: does not run its tests through attest.sh
         .claude/agents/test-developer.md: does not run --fast through attest.sh
         .claude/commands/advance-story.md: does not permit attest.sh
         .claude/commands/advance-story.md: PLANNED → RED does not check the record
         .claude/commands/advance-story.md: PLANNED → RED still re-runs the tests
         .claude/commands/advance-story.md: RED → GREEN does not check the record
         .claude/commands/advance-story.md: RED → GREEN still re-runs the tests
         .claude/commands/complete-story.md: does not permit attest.sh
         .claude/commands/complete-story.md: does not check the record
         .claude/agents/lead-po.md: does not check the record

  AC-5  ...and on a tree compliant by construction, and fires once per regression

  AC-6  the state README and settings.json carry the attest rows
    FAIL README: attest.log is a row, hand-editable no
         expected: 1
         actual:   0
    FAIL README: attest-logs/*.log is a row, hand-editable yes
         expected: 1
         actual:   0
    FAIL settings.json denies Edit(./.claude/state/attest.log)
         expected: 1
         actual:   0

attest: 22 passed, 101 failed
```

The 12 real-tree lines are each true of today's files: feature-developer.md
step 7 is ``Run `bash scripts/gates.sh`.`` and step 6 runs `--fast` bare;
test-developer.md steps 4 and 7 name no attest.sh; neither command's
allowed-tools has the entry; advance-story.md line 93 (PLANNED → RED) and line
130 (RED → GREEN) both say `run the tests yourself` and neither region names
the check; complete-story.md and lead-po.md's `## Orchestrating` never name it.

### What each block asserts, and the AC

C-2 `work_tree_hash` (19), via the fixture's lib.sh, `set_harness_root <fixture>`:
- prints one hash, returns 0; **equals `gate_tree_hash`** with nothing untracked
- an untracked `tests/new.test.ts` moves it; control: `gate_tree_hash` does not (green on arrival)
- the untracked file hashes **exactly as `gate_tree_hash` after `git add`** (listing shape read out); staging it does not move the work hash
- its content change moves it again; removing it restores the clean hash
- untracked `src/new.ts` (source) and `tsconfig.json` (config), and an unstaged edit to tracked `src/main.ts`, each move it
- tracked docs edit, untracked docs file, untracked `.claude/commands/new.md`, `dist/out.js` (vendor), `.claude/state/anything.txt`: each leaves it unmoved
- outside a git repository: stdout exactly `unavailable`, return 1

AC-1 (28): exit 3 passed through; the last attest.log block's keys are exactly
`run command tree after status exit duration last log`; `run:` matches the
gates.sh stamp and falls inside the call; `command:` is
`bash <WORK>/cmds/two.sh alpha beta`; `tree:` = `after:` = the work hash
before; `status: ok`; `exit: 3`; `duration: <n>s`; `last: second line` (the
command's stderr line, followed by a blank line - so "combined" and
"non-blank" both bite); `log:` matches the colon-free shape and its stamp is
`run:` minus `-`/`:`; the log file holds `first line\nsecond line` (+ blank);
stdout's block equals the log's block; the header is
`--- last 20 lines of <log:> ---`; the lines after it are `first line`,
`second line`; `first line` appears once on stdout; `second line` is in the
log and not on attest.sh's stderr. Tail: 30 lines -> header 20, lines 11..30,
log keeps 30; `ATTEST_TAIL=5` -> header 5, lines 26..30. Executed directly:
`args.sh 'a b' '*'` logs `[a b]` / `[*]` and records `... args.sh a b *`.
Control: `ATTEST_PROBE=value bash env.sh` exits 0, logs `NAME=value`, records
`ATTEST_PROBE=value bash <WORK>/cmds/env.sh`.

C-1 (7): exit 2 for no args, `--`, `frob -- true`, `check`, `check --`,
`true`; attest.log byte-identical after all six.

AC-2 (22): `check -- <same words>` -> last line `fresh`, exit 0, preceding
lines = the AC-1 block. `none: no record for this command`, exit 1, for a
never-run command, reordered words, a prefix, a superset, and env.sh without
its assignment (with it: `fresh`). Docs-only edit: `fresh`, exit 0. Tracked
source edit: `stale: recorded on <T0> at <R1>, the tree is now <Tn>`, exit 1;
undone: `fresh`. Untracked test file: `stale ... now <Ta>`, exit 1; its content
changed: `stale ... now <Tb>`, Tb != Ta, exit 1.

AC-3 (14): `edit.sh` (appends to tracked `src/x.sh`, exits 5) -> exit 5,
`status: void: tree changed during the run`, `tree:` before, `after:` the
hash it exited on (different), `exit: 5`, block printed; `check` -> last line
`void: tree changed during the run`, exit 1, and **still void after the file
is put back**. Control: `state.sh` (writes only `.claude/state/...`) ->
`status: ok`, exit 0, `after:` = hash before, `check` -> `fresh`.

C-4 (2): re-run two.sh on an edited tree -> `fresh`; put the tree back ->
`stale` against the NEWEST block although the older one matches.

AC-4 (8): precondition `mutate.sh --check` exits 1 on the planted sentinel;
attest.sh exits 2; the command's side effect (`<WORK>/ac4-ran`) is absent;
stdout+stderr carry the whole line `mutate: a mutation is unaccounted for. The
tree may not be the code you think.` and the whole line `  src/main.ts`;
attest.log byte-identical. Control: sentinel removed -> same command exits 0
and the side effect appears.

AC-5 (1 + 19): real tree silent; compliant fixture silent; 18 one-line
regressions (C-5's rows, plus: full run on a continuation line; attested
--fast moved outside `## Method`; the re-run phrase wrapped over two lines;
the check only in the next phase paragraph; an allowed-tools entry that
*contains* the pattern; no PLANNED → RED paragraph; lead-po's check only in
another section; lead-po empty; a missing complete-story.md).

AC-6 (3): README rows `attest.log` -> `no` and `attest-logs/*.log` -> `yes`
(parsed by a copy of settings.test.sh's `rows`); settings.json has a deny line
exactly `"Edit(./.claude/state/attest.log)"`.

### Export shape the tests pin (fact, not suggestion)

`scripts/attest.sh`, run as `cd <root> && bash scripts/attest.sh ...`:
- `-- <word>...`: leading `NAME=value` words exported and stripped; the rest
  executed as `"$@"`; stdout+stderr to the log; exit = the command's. Prints
  the block exactly as appended, then `--- last <N> lines of <log:> ---`,
  then the last `ATTEST_TAIL` (default 20) log lines. Root = the script's own
  `scripts/..` (CLAUDE_PROJECT_DIR is set to another tree throughout the suite).
- Block keys, in order, nothing else: `run command tree after status exit
  duration last log`, each `key:` + one or more spaces + value.
  `status:` is `ok` or `void: tree changed during the run`.
  `log:` is `.claude/state/attest-logs/YYYYMMDDTHHMMSSZ.<pid>.log`.
- `check -- <word>...`: last stdout line and exit: `none: no record for this
  command` 1; `void: tree changed during the run` 1; `stale: recorded on
  <tree> at <run>, the tree is now <hash>` 1; `fresh` 0, preceded by the block.
- Usage errors exit 2 and append nothing. A stranded mutation: exit 2, the
  command not run, `mutate.sh --check`'s report on stdout or stderr (either is
  read), nothing appended.
- `.claude/hooks/lib.sh`: `work_tree_hash` with no arguments, judging
  `$HARNESS_ROOT`; stdout one hash and return 0, or exactly `unavailable` and
  return 1.

Not constrained, so GREEN's choice: padding width; whether a blank line
separates the block from the header; N in the header when the output is
shorter than `ATTEST_TAIL`; which stream the refusal/report goes to; the
`void: hash unavailable` path (not reachable from a fixture without breaking
git); `show` entirely (no AC; nothing asserts it); the CLAUDE.md line (C-6,
no AC); non-markdown harness files' effect on the work hash.

Prose (AC-5): keep each needle on **one line** in feature-developer.md and
test-developer.md (judged per line). test-developer.md needs an attested run
**besides** the `--fast` one in its numbered list. Do not leave `run the tests
yourself` anywhere in the PLANNED → RED or RED → GREEN paragraphs, including
the "Unless the runner did not start" sub-paragraph (it is inside PLANNED → RED).

### Passing on arrival (22), and what earns each

- 19 AC-5 fixture assertions. The guard is written in the suite, not in
  production, so it runs in RED. Each regression fixture is itself the
  negative control for the compliant one: the compliant tree is silent AND
  each one-site change produces exactly its one line, so neither "always
  silent" nor "always noisy" passes. Measured in this run: all 19 green, the
  real tree 12 lines. The real-tree probe (DV-2) is GATES'.
- `control: gate_tree_hash does not see that untracked file` - a pin on
  HARNESS-014 behaviour, covered already by lib.test.sh's "an untracked hook
  does not move the hash"; its job here is to show why `work_tree_hash` must
  exist, next to the assertion that fails.
- `precondition: mutate.sh --check calls the planted sentinel stranded`:
  existing code, a precondition (if it were green for the wrong reason, the
  AC-4 refusal would be testing nothing).
- `the command never ran (its side effect is absent)` passes vacuously in RED
  (nothing ran at all). Earned by its control, `control: and its side effect
  appears` with the sentinel removed, which is red now and must go green: a
  mark.sh that never writes would fail that.

### Negative controls: expected values

Measured outside the framework with a **candidate** `work_tree_hash` composed
in a scratch script (gate_tree_hash's temp-index listing + one `git
hash-object` line per `untracked_gated` path, through `_hash_blob_listing`) on
a `make_project_fixture` tree. Hash values depend on the copied harness and
will differ at GREEN; the relations are what GREEN confirms against the shipped
function:

| Control | Expected | Measured (candidate) |
|---|---|---|
| clean tree: work hash vs gate_tree_hash | equal | `fb834a3d...` = `fb834a3d...` |
| untracked tests/new.test.ts | moves | `4f31c229...` |
| same file after `git add`, gate_tree_hash | equals the untracked work hash | `4f31c229...` |
| its content changed | moves again | `bcc106b7...` |
| file removed | back to clean | `fb834a3d...` |
| writes under .claude/state/ (AC-3 control) | unmoved | `fb834a3d...` |
| docs/notes.md edited (AC-2 control) | unmoved | `fb834a3d...` |
| dist/out.js + .claude/commands/new.md | unmoved | `fb834a3d...` |
| tracked src/main.ts edited | moves | `a0d71d21...` |
| AC-5 compliant fixture | 0 lines | 0 (in-suite, this run) |
| AC-5 each regression | exactly 1 line, as pinned | 1 each, 18/18 (in-suite, this run) |
| AC-5 real tree | 0 lines after GREEN | 12 lines now (listed above) |

attest.sh's own controls (env assignment -> exit 0 and `NAME=value`; state
write -> `status: ok`; void stays void after restore; reordered/prefix ->
`none`) cannot be measured in RED: there is no attest.sh. Their expected
values are the strings above; **these are claims until GREEN measures them
against the shipped script.**

### Other suites, and the fast gates (local, this host, 2026-11-01)

    $ bash scripts/selftest.sh attest
    attest: 22 passed, 101 failed
    FAIL attest  did 22 units of work, below the floor of 123 in .claude/tests/floors.conf
    $ bash scripts/selftest.sh selftest
    assertion floors: all 1 suite(s) met their declared floor (268 assertions executed, 268 declared).
    $ bash scripts/selftest.sh settings
    assertion floors: all 1 suite(s) met their declared floor (71 assertions executed, 70 declared).
    $ bash scripts/gates.sh --fast        (rc 0; every gate unconfigured, nothing ran)
    All required gates passed (0 ran, 5 unconfigured, 0 known).

`--fast` also listed `UNTRACKED  .claude/tests/attest.test.sh`: the new suite
is not yet staged; the commit stages it. The floor of 123 is the executed
count (22 + 101), with no conditional assertion, so it is the count GREEN
must reach; the `attest` suite sits below its floor until then, as
HARNESS-010's did. `selftest`'s table carries the same 123 and is green.

### Deferred verifications

DV-1 and DV-2 are owned by GATES. I did not run them and cannot: DV-1 mutates
`scripts/attest.sh`, which does not exist, and DV-2 probes the real
feature-developer.md after GREEN has rewritten it - today it already prints the
line DV-2 looks for, plus 11 others. Declined in writing, left to GATES.

### AC-6 and settings.test.sh

`settings.test.sh` cannot hold a RED assertion for AC-6: it checks that the
README rows and the deny rules agree in both directions, and today they agree
(neither has the attest rows), so it is green now and will stay green only if
GREEN adds the row **and** the rule together. The *existence* of the two rows
and the rule is therefore pinned in this suite (3 assertions, red now);
the agreement is `bash scripts/selftest.sh settings`, which GREEN must run.
If the auto-mode classifier refuses the settings.json edit (PO decision 4),
the third AC-6 assertion here and the settings suite both stay red until the
user applies the line.

### Discovered, for the approach

- `gated_stdin` keeps non-markdown harness files, so C-2's original "stays on
  harness" was wrong (amended).
- `<run>` contains colons; a file name cannot on Windows (amended C-3).
- `.claude/state/*` classifies `harness`, not `ignored` (C-7 note; no effect).
- `manifest` (e.g. `package.json`) is not in `gated_stdin`'s kept set, so
  neither hash moves on a manifest edit. Existing behaviour, out of scope, not
  pinned; worth a story if it matters.
- `bash scripts/attest.sh check` wrapped across two lines in advance-story,
  complete-story or lead-po still counts (regions are joined); in the two agent
  files it does not.

### Addendum for GREEN after return 3 (2026-11-01)

RED return 3 by `test-developer`, on `claude-opus-5-5` (Opus 5.5), as declared;
no override. Command unchanged: `bash scripts/selftest.sh attest`. Today:
`attest: 133 passed, 32 failed`, below the new floor of 165 (`floors.conf` and
`selftest.test.sh`'s table both say 165). The 32 FAIL lines and what each pins
are in `## Regressions`, Return 3. **Read C-1, C-2 and C-5's return-3
amendments first.**

What to build - four things, nothing else:

1. **`work_tree_hash`'s own filter** (`lib.sh`, A-2). Keep `gated_stdin`,
   `gate_tree_hash`, `_hash_blob_listing` and `untracked_gated` byte-identical
   (C-10; the suite's `control: gate_tree_hash does not see committed harness
   markdown` would catch a widened `gated_stdin`). `work_tree_hash` needs:
   (a) the untracked list from `git ls-files --others --exclude-standard`
   through `classify_stdin` and the new filter, not from `untracked_gated`
   (which drops markdown); (b) the hash over the tracked listing plus those
   blobs through the new filter, in `_hash_blob_listing`'s line shape
   (`<blob>  <path>`, `LC_ALL=C sort`, `git hash-object --stdin`) - not through
   `_hash_blob_listing` itself, which applies `gated_stdin`. The filter:
   source, test, config, harness (markdown too), and not under
   `.claude/state/`. The shape matters: two assertions require work ==
   gate on a markdown-free tree.
2. **Assignments through `env`** (`attest.sh`, finding 3). Collect the leading
   `NAME=value` words into an array instead of `export`ing them, and run
   `env "${assigns[@]}" "$@"` (with no assignments, plain `"$@"` or `env "$@"`
   both do). `WORDS` stays all the words.
3. **Newline/CR refusal** (`attest.sh`, finding 4). Before the mode dispatch
   runs anything, any word after `--` containing `$'\n'` or `$'\r'` -> `usage`
   (exit 2), in both run and `check`, assignment words included. Nothing
   appended to attest.log.
4. **Both commands' `allowed-tools`** (A-1). In `advance-story.md` and
   `complete-story.md`, replace `Bash(bash scripts/attest.sh:*)` with
   `Bash(bash scripts/attest.sh check:*)`. Exact, trimmed-equal entry; the old
   one must not remain.

Export shape pinned (unchanged): `work_tree_hash` (no args, stdout one hash or
`unavailable`, returns 1 on failure). Not constrained: how the filter is named
or whether it is a separate function; the usage message text for the new
refusal (only exit 2 and "nothing ran, nothing recorded" are pinned); whether
`HARNESS_ROOT` is exported to the command (vars.sh prints it; nothing asserts
its value in the command).

Expected values of each control (measured in this return, on this host, before
GREEN; hash values are fixture-specific and will differ, the relations are what
GREEN confirms):

| Control | Expected after GREEN | Measured today (RED) |
|---|---|---|
| clean WFIX, no harness md: work vs gate | equal | equal (passes) |
| untracked tests/new.test.ts staged: gate vs untracked work | equal | equal (passes) |
| untracked `.claude/commands/new.md` | moves | unmoved, `3f40522b...` both sides |
| committed `.claude/agents/role.md` + `CLAUDE.md`: gate_tree_hash | unmoved vs `g0` | unmoved (passes) |
| same commit: work hash | moves | unmoved |
| docs / dist / ignored `scratch/out.ts` / `.claude/state/` writes, vs the md tree | unmoved | unmoved (passes) |
| `src/scratch-out.ts`, same content as the ignored file | moves | moves (passes) |
| FIX: tracked `.claude/agents/role.md` or `CLAUDE.md` edit, `check` | `stale: ... now <new>`, exit 1 | `fresh`, exit 0 |
| `-- ROOT=<dir> vars.sh` | record + log in FIX, log line `ROOT=<dir>`, `<dir>` empty | log written to `<dir>/.claude/state/attest-logs/`, FIX has no such file |
| `-- ALOG=<file> vars.sh` | record in FIX, `<file>` absent | record appended to `<file>` |
| `-- HARNESS_ROOT=<dir> vars.sh` | `status: ok`, `after:` = FIX's hash | `void: hash unavailable`, `after: unavailable` |
| marker + `ROOT=<dir>` | exit 2, not run, log unchanged | exit 0, ran, recorded |
| marker + `ALOG=<file>` | exit 2, not run | exit 2, not run (passes on arrival; earned by a probe, `## Regressions`) |
| newline word / CR word / newline assignment, run | exit 2, not run | exit 0, ran |
| newline word, `check` | exit 2 | exit 1 |
| attest.log across those four | byte-identical | grew |
| `check -- bash scripts/gates.sh --fast` afterwards | `none: ...`, exit 1 | `fresh`, exit 0 (the reviewer's forgery, reproduced) |
| real tree, attest_problems | silent | 4 lines: both commands, both tool rows |
| AC-5 fixtures (3 new: prefix back beside check, x2; pre-A-1 entry alone) | 1 line each / 2 lines | as pinned (pass; guard is test code) |

All controls above ran in-suite this time (attest.sh and lib.sh exist), so these
are measured, not claims - except the "after GREEN" column, which GREEN
measures.

Timings: all local, this host, with four other `gates.sh --fast` runs on it:
`selftest.sh attest` 106 s red. No per-test timeouts exist in this harness.

## Regressions

### Return 1: GREEN -> RED (2026-11-01), `.claude/tests/settings.test.sh`

**What was wrong.** HARNESS-050's
`AC-1/C-1: the deny array is exactly the seven C-1 rules, in order`
(`settings.test.sh`, ~line 279) pins the *whole* `permissions.deny` array.
This story's AC-6 adds an eighth rule, `"Edit(./.claude/state/attest.log)"`.
No `settings.json` satisfies both, so the assertion is defective against this
story's criteria, not the implementation. Contract C-7 had said the suite
"needs no change"; that was wrong (C-7 amended in place, and the file added to
`**Writes:**` and `touches:`).

**How it was found.** The GREEN dispatch ran `bash scripts/selftest.sh settings`
after adding the rule (`settings: 70 passed, 1 failed`, that assertion only);
the orchestrator reproduced it by reading the assertion against AC-6.

**What it asserts now.** The deny array is exactly eight rules, in order:
the three `Read` denies, `Edit(./.claude/state/current-story.env)`,
`Edit(./.claude/state/last-gate-run)`, `Edit(./.claude/state/attest.log)`,
then HARNESS-047's two `Bash(git ... *--output*)` denies. Name changed from
"seven" to "eight". No other assertion was touched; the suite still executes
71 assertions, so `floors.conf` (`floor | settings`, 70) and selftest.test.sh's
table are unchanged.

**Earned by a probe.** The corrected assertion passes on arrival, so the rule
it pins was removed from `settings.json` with `scripts/mutate.sh` (restore
verified with `cmp`). Command (one suite name per `selftest.sh` call):

    bash scripts/mutate.sh .claude/settings.json '/"Edit(\.\/\.claude\/state\/attest\.log)",/d' -- bash scripts/selftest.sh settings

Two assertions went red: the corrected one, and the pre-existing
table/rule agreement check `no disagreements`, which independently notices
the README row has lost its deny rule. That second failure is correct and
expected; nothing else failed. The probe removes the rule; it does not
reorder it, so the "in order" half rests on the assertion being a whole-string
`assert_eq` rather than on this run.

```
=== mutate: .claude/settings.json (1 line(s) changed by /"Edit(\.\/\.claude\/state\/attest\.log)",/d) ===
  29 -       "Edit(./.claude/state/attest.log)",

=== mutate: running bash scripts/selftest.sh settings ===
selftest: 3 other test run(s) are on this host; expect this run to be slower, not wrong:
selftest:   pid 1090: bash scripts/selftest.sh
selftest:   pid 170237: bash /d/clean_calendar/.claude/tests/spawns.test.sh
selftest:   pid 170235: bash scripts/selftest.sh

=== settings ===

  the shipped pair agrees with itself
    FAIL no disagreements
         expected: 
         actual:   attest.log: not hand-editable, but settings.json has no "Edit(./.claude/state/attest.log)"

  HARNESS-027 AC-7: the kept failing log has its own row

  HARNESS-069 AC-11: the logs kept for a signature have their own row

  the two files that carry evidence stay denied
    FAIL AC-1/C-1: the deny array is exactly the eight C-1 rules (HARNESS-084 AC-6 adds attest.log), in order
         expected: "Read(./.env)"
         "Read(./.env.*)"
         "Read(./**/secrets/**)"
         "Edit(./.claude/state/current-story.env)"
         "Edit(./.claude/state/last-gate-run)"
         "Edit(./.claude/state/attest.log)"
         "Bash(git log *--output*)"
         "Bash(git diff *--output*)"
         actual:   "Read(./.env)"
         "Read(./.env.*)"
         "Read(./**/secrets/**)"
         "Edit(./.claude/state/current-story.env)"
         "Edit(./.claude/state/last-gate-run)"
         "Bash(git log *--output*)"
         "Bash(git diff *--output*)"

  each way of getting it wrong produces its own complaint

  HARNESS-050 AC-5: the documents say Edit, and name no tool list

  HARNESS-050 AC-6: the suite has no tool list

  HARNESS-029 AC-6: a surviving mutations/*.new has a row, and the paragraph says what it means

  HARNESS-047: git log and git diff stay allowed, and their --output is denied

settings: 69 passed, 2 failed
FAIL settings  did 69 units of work, below the floor of 70 in .claude/tests/floors.conf

assertion floors: 0 of 1 suite(s) met their declared floor.
1 of 1 harness suite(s) FAILED.

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_settings.json.20261101T053315Z.171869.bak) ===
  29:       "Edit(./.claude/state/attest.log)",
```

After the restore:

```
settings: 71 passed, 0 failed

assertion floors: all 1 suite(s) met their declared floor (71 assertions executed, 70 declared).
1 harness suite(s) passed.
```

### Return 2: GATES -> RED (2026-11-01), `.claude/tests/attest.test.sh`

**What was wrong.** The suite did not isolate itself from `ATTEST_TAIL` in the
caller's environment. `att` runs `scripts/attest.sh` in the fixture and, unless
`ATT_ENV` is set, passes the inherited environment straight through, so an
exported `ATTEST_TAIL` reached every AC-1 tail assertion that expects the
default of 20 lines. With `ATTEST_TAIL=2` exported, five assertions failed on a
correct `attest.sh`. The defect is in the test, not in `attest.sh`, which honours
`ATTEST_TAIL` exactly as the contract says.

**How it was found.** By the orchestrator, running
`ATTEST_TAIL=2 bash scripts/attest.sh -- bash scripts/selftest.sh attest`: the
outer call's variable is exported into the command it records, and so reached
the suite (recorded in `## Notes`).

**What the suite does now.** It `unset`s `ATTEST_TAIL` beside
`export CLAUDE_PROJECT_DIR="$REPO_ROOT"`, for the same reason that line exists:
attest.sh under test must see what the assertion intends, not what the session
happens to export. The one assertion that wants a non-default tail
(`ATTEST_TAIL=5 prints a 5-line header`) still sets it explicitly through
`ATT_ENV`, and still passes. Nothing else changed; the assertion count is 123
before (118 passed + 5 failed) and after.

**Earned by before/after under the hostile environment**, not by a mutation of
`attest.sh`: the defect is test isolation, so the evidence is the same command
run in the environment that broke it, against the uncorrected and the corrected
file. No revert was needed for the "before": it was run first, on the committed
file (`da11384..cd88b9b` leave `attest.test.sh` as committed), and the fix was
applied afterwards.

Before, `ATTEST_TAIL=2 bash scripts/selftest.sh attest` (FAIL lines and summary):

```
  AC-1  attest.sh -- <command>: exit passed through, the record, then the tail
    FAIL then a header naming the log
    FAIL then the log's last lines
    FAIL the output is printed once, from the log, not streamed as well
    FAIL a 30-line output prints a 20-line header by default
    FAIL and exactly lines 11..30
attest: 118 passed, 5 failed
FAIL attest  did 118 units of work, below the floor of 123 in .claude/tests/floors.conf
1 of 1 harness suite(s) FAILED.
```

After, the same command with the fix:

```
attest: 123 passed, 0 failed
1 harness suite(s) passed.
```

And plain `bash scripts/selftest.sh attest`, no `ATTEST_TAIL` exported:

```
attest: 123 passed, 0 failed
1 harness suite(s) passed.
```

### Return 3: GATES -> RED (2026-11-01), `.claude/tests/attest.test.sh`

**Why.** Diff review round 1 (`## Diff review`) found four defects no test was
written for. Findings 1 and 2 contradicted pinned assertions and needed
amendments, A-1 and A-2, approved by the user ("Approve, fix all four");
findings 3 and 4 change no criterion, only C-1. This return writes the tests
for all four and amends C-1, C-2 and C-5 in place to match. `attest.sh`,
`lib.sh`, the prose and settings.json are untouched.

**What each new or changed assertion pins.**

- *Finding 1 / A-2, C-2 block.* Changed: "an untracked harness markdown file
  does not move it" is now "... (.claude/commands/new.md) moves it". New: its
  content change moves it again; an untracked `.claude/skills/x/SKILL.md`
  moves it; committing `.claude/agents/role.md` and `CLAUDE.md` moves it; an
  unstaged edit to each tracked file moves it (and the undo returns it, green
  on arrival as a restore control). Kept and re-based on the tree with
  harness markdown: tracked docs edit, untracked docs file, `dist/out.js`,
  `.claude/state/` writes (now with a `.md` among them) do not move it. New
  and green on arrival: an ignored `scratch/out.ts` (source by name) does not
  move it, earned in-suite by its control - the same content at the
  non-ignored `src/scratch-out.ts` does move it; and `gate_tree_hash` does not
  see the committed markdown (C-10, so GREEN cannot satisfy A-2 by widening
  `gated_stdin`). **"With nothing untracked, work hash == gate_tree_hash" is
  kept, but now holds only on a markdown-free tree**, and its name says so; it
  and the staged-equals-untracked equality run before any harness markdown is
  added to that fixture.
- *Finding 1 / A-2, AC-2 block.* The attest fixture now tracks
  `.claude/agents/role.md` and `CLAUDE.md`; an edit to either makes `check`
  answer `stale: recorded on <T0> at <run>, the tree is now <new>`, exit 1; both
  undone, `fresh` again.
- *Finding 2 / A-1, AC-5.* `check_attest_tool` now requires an entry equal to
  `Bash(bash scripts/attest.sh check:*)` (`does not permit attest.sh check`)
  and refuses an entry equal to `Bash(bash scripts/attest.sh:*)` (`permits
  attest.sh to run any command`). The compliant fixture carries the check entry
  with odd spacing and a near-miss `NotBash(bash scripts/attest.sh:*)` that
  contains the prefix but is not equal to it. Regression fixtures, one line
  each: check entry replaced by a containing-not-equal one; the old prefix back
  beside the check entry, in advance-story and in complete-story; check entry
  removed from complete-story. And the pre-A-1 entry alone prints both lines.
  The real-tree assertion is red with four lines (below).
- *Found while doing the above, C-5 amended.* complete-story was judged on the
  whole file, and A-1's entry `Bash(bash scripts/attest.sh check:*)` contains
  the needle `bash scripts/attest.sh check`: the `cs-check` fixture went silent
  on the first run of this return. complete-story is now judged on its body
  (after the frontmatter); `cs-check` is red-able again and passes.
- *Finding 3, new block "C-1 a leading assignment reaches the command only".*
  `ROOT=<dir>`: exit 0, the record in FIX's attest.log, the log it names under
  FIX, the command printed `ROOT=<dir>`, nothing written under `<dir>`.
  `ALOG=<file>`: the record in FIX's attest.log, `<file>` never created, the
  command printed `ALOG=<file>`. `HARNESS_ROOT=<dir>`: `status: ok`, `after:`
  is FIX's work hash. With a stranded `mutations/*.active`: `ROOT=<dir>` still
  exits 2, the command does not run, attest.log unchanged; `ALOG=<file>` still
  exits 2, the command does not run (these two pass on arrival - see the probe
  below).
- *Finding 4, new block "C-1 a word holding a newline or a CR".* A word with a
  newline, a word with a CR, and a leading assignment with a newline: each
  exit 2 and the command does not run; `check --` with a newline word exits 2;
  attest.log byte-identical across all four; and the reviewer's forgery pinned
  directly - afterwards `check -- bash scripts/gates.sh --fast` answers `none:
  no record for this command`, exit 1.
- *Floors.* 123 -> 165 in `floors.conf` and `selftest.test.sh`'s table, read off
  the run: 133 passed + 32 failed, no conditional assertion.

**Failure, against today's `attest.sh` and `lib.sh`.**
`bash scripts/attest.sh -- bash scripts/selftest.sh attest`:

    last:     1 of 1 harness suite(s) FAILED.
    log:      .claude/state/attest-logs/20261101T183007Z.50862.log
    status: ok, exit: 1, duration: 106s

FAIL lines from that log (headers kept; selected detail lines indented below
their FAIL):

```
  C-2  work_tree_hash: one hash, moving on gated content tracked, staged or untracked
    FAIL an untracked harness markdown file (.claude/commands/new.md) moves it
         expected two different hashes:
         before: 3f40522b382497c261d89c5d4f46f370cc9d0680
         after:  3f40522b382497c261d89c5d4f46f370cc9d0680
    FAIL and a content change to it moves it again
    FAIL an untracked skill (.claude/skills/x/SKILL.md) moves it
    FAIL committed harness markdown is part of the work hash (it moved from the clean tree's)
    FAIL an unstaged edit to a tracked .claude/agents/*.md moves it
    FAIL an unstaged edit to a tracked CLAUDE.md moves it
  AC-2  check: fresh on the unchanged tree; none, stale, or still fresh on a docs edit
    FAIL after a tracked .claude/agents/*.md edit: stale, naming the recorded and the current hash
         actual:   fresh
    FAIL and exits 1
    FAIL after a tracked CLAUDE.md edit: stale, naming the recorded and the current hash
         actual:   fresh
    FAIL and exits 1
  C-1  a leading assignment reaches the command only, never attest.sh's own shell
    FAIL ROOT=<elsewhere>: the log it names is under this tree's .claude/state/
    FAIL ROOT=<elsewhere>: and the command saw ROOT, which it printed
    FAIL ROOT=<elsewhere>: nothing is written under <elsewhere>
         /tmp/tmp.A21Rsd8cLv/scratch-root/.claude/state/attest-logs/20261101T182337Z.38613.log
    FAIL ALOG=<elsewhere>: the record lands in this tree's attest.log
    FAIL ALOG=<elsewhere>: nothing is appended to <elsewhere>
    FAIL ALOG=<elsewhere>: and the command saw ALOG, which it printed
    FAIL HARNESS_ROOT=<elsewhere>: status: ok (both hashes are of this tree)
         actual:   void: hash unavailable
    FAIL HARNESS_ROOT=<elsewhere>: after: is this tree's work hash
    FAIL a stranded mutation and ROOT=<elsewhere>: still refused, exit 2
         actual:   0
    FAIL a stranded mutation and ROOT=<elsewhere>: the command never ran
    FAIL a stranded mutation and ROOT=<elsewhere>: nothing recorded
  C-1  a word holding a newline or a CR is a usage error, and forges nothing
    FAIL a word containing a newline: exit 2
    FAIL a word containing a newline: the command never ran
    FAIL a word containing a CR: exit 2
    FAIL a word containing a CR: the command never ran
    FAIL a leading assignment containing a newline: exit 2
    FAIL a leading assignment containing a newline: the command never ran
    FAIL check with a word containing a newline: exit 2
         actual:   1
    FAIL none of them appended to attest.log
    FAIL the forged command has no record: check answers none
         expected: none: no record for this command
         actual:   fresh
    FAIL and exits 1
  AC-5  the guard is silent on the real tree
    FAIL attest_problems over REPO_ROOT prints nothing
         actual:   .claude/commands/advance-story.md: does not permit attest.sh check
         .claude/commands/advance-story.md: permits attest.sh to run any command
         .claude/commands/complete-story.md: does not permit attest.sh check
         .claude/commands/complete-story.md: permits attest.sh to run any command
attest: 133 passed, 32 failed
FAIL attest  did 133 units of work, below the floor of 165 in .claude/tests/floors.conf
```

(The two detail lines above quoting temp paths and the first-run hash are from
the identical first run, `20261101T182108Z.34557.log`; the same assertions
fail with the same reasons in `...50862.log`.) Every other block - AC-1, C-1
usage errors, AC-3, C-4, AC-4, AC-5 fixtures, AC-6 - is green.

**Probe for the two assertions green on arrival** (a stranded mutation plus
`ALOG=<elsewhere>`: still exit 2, the command never ran). One mutation of the
refusal itself, one run, restored by `mutate.sh`:

```
$ bash scripts/mutate.sh scripts/attest.sh 's/if \[ -f "\$ROOT\/scripts\/mutate.sh" \]; then/if false; then/' -- bash scripts/selftest.sh attest
=== mutate: scripts/attest.sh (1 line(s) changed by s/if \[ -f "\$ROOT\/scripts\/mutate.sh" \]; then/if false; then/) ===
  147 - if [ -f "$ROOT/scripts/mutate.sh" ]; then
=== mutate: running bash scripts/selftest.sh attest ===
  AC-4  a stranded mutation: refused before running, mutate.sh's report, exit 2
    FAIL attest.sh exits 2
    FAIL the command never ran (its side effect is absent)
    FAIL it prints mutate.sh --check's report
    FAIL a stranded mutation and ROOT=<elsewhere>: still refused, exit 2
    FAIL a stranded mutation and ROOT=<elsewhere>: the command never ran
    FAIL a stranded mutation and ROOT=<elsewhere>: nothing recorded
    FAIL a stranded mutation and ALOG=<elsewhere>: still refused, exit 2
    FAIL a stranded mutation and ALOG=<elsewhere>: the command never ran
attest: 126 passed, 39 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_attest.sh.20261101T182817Z.46363.bak) ===
  147: if [ -f "$ROOT/scripts/mutate.sh" ]; then
```

(grep of the FAIL lines that mention the refusal; the run was taken before the
floor was raised.) Both ALOG assertions go red when the refusal is removed, so
they can fail; they pass today only because `ALOG=` does not reach the
refusal's path. Their job is to hold that once GREEN restructures the
assignment handling.

`bash scripts/attest.sh -- bash scripts/gates.sh --fast`:

    exit:     0
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261101T183000Z.50675.log

`bash scripts/attest.sh -- bash scripts/selftest.sh selftest` (the floors table
agrees with `floors.conf` at 165):

    exit:     0
    last:     1 harness suite(s) passed.
    log:      .claude/state/attest-logs/20261101T183155Z.55297.log

Files touched in this return: `.claude/tests/attest.test.sh`,
`.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, and this story
(C-1, C-2, C-5 amendments, `## Test plan` note, the handoff addendum, this
block). Nothing else.

## Diff review

Round 1, 2026-11-01, fresh `feature-developer` on the GATES row, resolved
**claude-opus-5-5**; it changed no file. Report, condensed to its findings
(full text in the session transcript):

**Must fix**
1. `work_tree_hash` leaves out harness markdown (`.claude/agents/*.md`,
   `.claude/commands/*.md`, `CLAUDE.md`), which at least ten of this
   repository's suites read. Reproduced by the reviewer: after an attested
   `attest: 123 passed`, an edit to feature-developer.md's `--fast` line
   left `check` answering `fresh` while a re-run gave `122 passed, 1 failed`.
   Fix: its own filter that drops only docs, vendor, ignored and
   `.claude/state/`; `gated_stdin` and `gate_tree_hash` unchanged. Contradicts
   C-2 as amended and a pinned assertion (untracked `.claude/commands/new.md`
   does not move it): Amendment + RED.
2. `Bash(bash scripts/attest.sh:*)` in both commands' `allowed-tools` is a
   prefix match over a script that runs whatever follows `--`, so any command
   is auto-approved behind it. The orchestrator needs only `check`. Fix:
   `Bash(bash scripts/attest.sh check:*)`. AC-5 pins the exact entry:
   Amendment + RED.

**Should fix**
3. A leading `NAME=value` is exported into attest.sh's own shell, so
   `ROOT=`, `ALOG=` or `HARNESS_ROOT=` redirect the log, the record and the
   hash, and `ROOT=` skips the AC-4 mutation refusal. Fix: collect the
   assignments, run `env "${assigns[@]}" "$@"`. Test: RED.
4. A newline inside a word writes extra record lines: `attest.sh -- bash -c
   $'exit 1\ncommand: bash scripts/gates.sh --fast\nexit: 0'` made `check --
   bash scripts/gates.sh --fast` answer `fresh`, exit 0. Fix: refuse a word
   containing a newline (or CR) as a usage error, exit 2. Test: RED.

**Nice to have**
5. `command:` is the words joined by one space, so `runner "a b"` and
   `runner a b` collide. Fix needs C-1 changed.

Verdict: fix 1 and 2 first.

Orchestrator's independent reproduction (2026-11-01), different inputs:
1. `work_tree_hash` before, after appending a line to
   `.claude/commands/status.md`, and after restoring it: all three
   `6c032341136e5bb1cd2c9611af5bcc29404c855c`.
2. `advance-story.md`'s `allowed-tools`: `Bash(bash scripts/attest.sh:*)` is
   the only entry that runs arbitrary words; `task.sh` runs named
   `project.conf` tasks, and `mutate.sh` is not listed.
Both amendments are put to the user before RED.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-01T18:01:55Z
    commit: d656312
    tree:   6c032341136e5bb1cd2c9611af5bcc29404c855c
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

<!-- Not expected: this story adds no gate to project.conf. If GREEN finds it
     changed one, record the probe here and say so in ## Notes. -->

## Notes

PO decisions at PLANNED → RED (2026-11-01), before dispatch:

1. **The gate.** Every gate in this repository's `project.conf` is
   unconfigured, so no `gates.sh` gate reads what this story builds. The gate
   that fails if it breaks is `bash scripts/selftest.sh attest`, which CI's
   `selftest.sh` step runs on every PR; `required_gates` stays empty because
   there is no gate id to name. The same holds for every HARNESS story so
   far.
2. **The phase lock does not separate RED from GREEN here.** Every path on
   the `**Writes:**` line classifies as `harness` (`bash scripts/classify.sh`
   on each, 2026-11-01), which every phase may write. The discipline that
   RED writes only `.claude/tests/attest.test.sh`, `floors.conf` and
   `selftest.test.sh`'s table, and the story file, is the Test Developer's
   own (`rules.md`, "Path ownership"), and the orchestrator checks the diff.
3. **Callers.** C-10 changes no existing signature. Verified: `gate_tree_hash`,
   `untracked_gated`, `_hash_blob_listing` and `gated_stdin` exist in
   `lib.sh` (lines 1365-1456) and `work_tree_hash` does not yet; `has_entry`
   and `first_step` are in `procedure.test.sh`; `make_project_fixture` is in
   `_lib.sh`; feature-developer.md step 7 reads `` Run `bash scripts/gates.sh`. ``
   at line 67 and test-developer.md step 7 at line 51, as C-5 assumes.
4. **`settings.json`.** The auto-mode classifier has refused agent edits to
   its `permissions` block before (PR #12). If GREEN is refused, it proposes
   the one deny line and the user applies it; that is not a return to RED.
5. **Epic.** `epic:` is empty; no done-when to check.

- RED - `test-developer`, planned `opus`, resolved **claude-opus-5-5** (2026-11-01), per its report; no override.

RED verification by the orchestrator (2026-11-01): `bash scripts/selftest.sh attest`
re-run, 43.6 s: `attest: 22 passed, 101 failed`, below the floor of 123, as
the handoff says. Failures grouped by message: every red one is `attest.sh`
absent (exit 127, no record), `work_tree_hash` absent, or the real tree's
prose and state rows unchanged; no syntax or unrelated error. The diff is
the suite, `floors.conf`, `selftest.test.sh` and this file only: no
`scripts/attest.sh`, no `lib.sh` change. `bash scripts/gates.sh --fast`:
`All required gates passed (0 ran, 5 unconfigured, 0 known).`, not recorded.
`docs/backlog/stories/HARNESS-088.md` is untracked and belongs to another
session; it is left out of this branch.

GREEN - `feature-developer`, resolved **claude-opus-5-5** (2026-11-01), as
declared; no override.

- Built: `scripts/attest.sh` (new); `work_tree_hash` appended to `lib.sh`
  (`gate_tree_hash` not touched, C-10 - so the temp-index listing is built a
  second time inside `work_tree_hash` rather than shared; untracked blobs via
  `git hash-object --stdin-paths`); the prose in feature-developer.md (full
  run out of `## Method`, its guidance moved to a GATES paragraph; steps 8-9
  are now 7-8), test-developer.md steps 4 and 7, advance-story.md PLANNED →
  RED and RED → GREEN, complete-story.md, lead-po.md's first rung; both
  commands' `allowed-tools`; the CLAUDE.md line; the two README rows plus a
  paragraph each; the settings.json deny line; VERSION 103.
- `bash scripts/selftest.sh attest`: `attest: 123 passed, 0 failed`, floor met.
- **Blocked: `bash scripts/selftest.sh settings` is red, `settings: 70 passed,
  1 failed`**, on a frozen assertion from HARNESS-050:
  `AC-1/C-1: the deny array is exactly the seven C-1 rules, in order`
  (settings.test.sh line 279). It pins the whole deny array, so AC-6's deny
  line - which attest.test.sh's third AC-6 assertion requires - cannot be added
  without failing it. The handoff's claim that settings "needs no change"
  (C-7) does not hold. The two frozen suites contradict each other; the fix is
  a RED change to that one assertion (eight rules, `attest.log` after
  `last-gate-run`), and `settings.test.sh` is not on the `**Writes:**` line.
  Returned to the orchestrator; story goes back to RED for it.
- Negative controls, measured on a `make_project_fixture` tree against the
  shipped `work_tree_hash` (values differ from RED's candidate, relations all
  hold): clean work = gate = `fc2c2a2d...`; untracked tests/new.test.ts ->
  `0d5c628f...`, gate unmoved; staged, gate_tree_hash = `0d5c628f...` (equal);
  content change -> `13644222...`; removed -> `fc2c2a2d...`; .claude/state
  write -> unmoved; docs + dist/out.js + .claude/commands/new.md -> unmoved;
  tracked src edit -> `43b818dc...`. attest.sh: `P=value bash env.sh` ->
  exit 0, log `NAME=value`, `command:` keeps the assignment; state-only write
  -> `status: ok`; `check -- b a` after running `a b` -> `none`; edit.sh ->
  `void: tree changed during the run`, still `void` after the file is put back.
- `bash scripts/selftest.sh` takes ONE suite name (`ONLY="${1:-}"`); a list
  runs only the first. Suites were run one call each, all green: `procedure:
  118 passed`, `briefs: 31`, `reporting: 27`, `phase: 73`, `mutate: 308`,
  `policy: 17`, `selftest: 268`, `lib: 324`, 0 failed each, floors met.
  `check-sigpipe` and `check-grep-count`: 0 findings over 58 files.
  `bash scripts/gates.sh --fast`: `All required gates passed (0 ran, 5
  unconfigured, 0 known).`, not recorded.
- GREEN - `feature-developer`, planned `opus`, resolved **claude-opus-5-5** (2026-11-01), per its report; no override.

GREEN verification by the orchestrator (2026-11-01): `attest: 123 passed, 0
failed`; `settings: 70 passed, 1 failed` - `AC-1/C-1: the deny array is
exactly the seven C-1 rules, in order` (settings.test.sh ~line 279,
HARNESS-050). Reproduced by reading the assertion: it pins the whole deny
array, so no settings.json can carry AC-6's eighth rule and keep it green.
C-7's "settings.test.sh needs no change" was wrong. Return to RED follows.
A finding from the GREEN dispatch, about the orchestrator's brief:
`bash scripts/selftest.sh a b c` runs only `a` (`ONLY="${1:-}"`) and still
prints `1 harness suite(s) passed.`; each suite needs its own call.

GREEN after return 1 (2026-11-01): a genuine no-op, no dispatch. The
orchestrator ran each check through `scripts/attest.sh` itself:
`selftest.sh settings` exit 0 (`1 harness suite(s) passed.`, 22 s),
`selftest.sh attest` exit 0 (159 s), `gates.sh --fast` exit 0 (`0 ran, 5
unconfigured`); `attest.sh check` answered `fresh` for each.

Finding for GATES / the diff review: the first attest run here was made with
`ATTEST_TAIL=2` on the outer call, and the suite inherited it - five AC-1
tail assertions went red (`a 30-line output prints a 20-line header by
default` and four others). `attest.test.sh` does not unset `ATTEST_TAIL`, so
a caller's environment changes its result. Fixing that is a test change (RED).

GREEN after return 2 (2026-11-01): a genuine no-op. Orchestrator run:
`bash scripts/attest.sh -- ATTEST_TAIL=2 bash scripts/selftest.sh attest`
-> `status: ok`, `exit: 0`, 106 s, `1 harness suite(s) passed.` - the hostile
environment that broke five assertions before.
- RED return 2 - `test-developer`, planned `opus`, resolved **claude-opus-5-5** (2026-11-01); no override.

RED return 3 verified (2026-11-01) without a re-run: `bash scripts/attest.sh
check -- bash scripts/selftest.sh attest` answered `fresh` on the tree the
test-developer left (`exit: 1`, `last: 1 of 1 harness suite(s) FAILED.`); its
log `.claude/state/attest-logs/20261101T183007Z.50862.log` shows
`attest: 133 passed, 32 failed`, 32 FAIL lines, the ones the report names.
The first use of the story's own mechanism; it saved one 106 s run.
- RED return 3 - `test-developer`, planned `opus`, resolved **claude-opus-5-5** (2026-11-01); no override.
