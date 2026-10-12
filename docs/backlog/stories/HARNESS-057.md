---
id: HARNESS-057
title: gates.sh looks up a gate's settings without forking, so --list and --audit no longer cost about 1.5 s per gate
slug: gates-sh-looks-up-a-gate-s-settings-with
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-057-gates-sh-looks-up-a-gate-s-settings-with
depends_on: [HARNESS-056]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/gates.sh, .claude/tests/gates.test.sh, .claude/tests/sigpipe.test.sh]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Port of the second half of manhwa-cropper's MC-045 (`cf01401`, "parse
project.conf with builtins so gates.sh startup no longer scales with its
length"; its suite is `.claude/tests/gates-parse.test.sh` there). Triaged
2026-10-11 against release 93; release 94 changed nothing in this area.

The first half - the per-LINE cost of parsing `project.conf` - is already
covered upstream by HARNESS-024 (port of MT-040): `trim`, `field` and `rest`
are builtins, and `gates.test.sh`'s HARNESS-024 AC-2 block (around :1150-1197)
pins, with `pad_manifest` and `same_count`, that a manifest 100 comment lines
longer spawns no more processes.

The per-GATE cost is not covered. For every gate line the main loop reaches,
`scripts/gates.sh` runs `$(table_lookup "$TABLE" "$id")` seven times (:382,
:413-418), plus once per failing gate (:576) and once per covered path (:817).
`table_lookup` is pure bash, but **a `$(...)` forks whether or not its body
execs anything**. HARNESS-024's oracle, `trace_externals`, counts only exec'd
programs, so these forks are invisible to it: its AC-1 bound of 20 externals
and its AC-2 equality both hold today over a manifest where the gate count
drives seventy forks. The downstream suite adds the oracle that sees them:
`bash -x` with `PS4='+ '`, counting trace lines at depth two or more
(`^++`), which is exactly a command run inside a command substitution or a
subshell.

**Measured on this tree (release 94, `8048134`) by the Lead PO on 2026-10-12,
on this host, over `make_project_fixture` with the one-gate and ten-gate
manifests pasted in C-3 below:**

    one --list   rc=0 nested=73  table_lookup_subst=7
    one --audit  rc=0 nested=73  table_lookup_subst=7
    ten --list   rc=0 nested=811 table_lookup_subst=70
    ten --audit  rc=0 nested=811 table_lookup_subst=70

`nested` is `grep -c '^++'` over the trace; `table_lookup_subst` is
`grep -c '^++ table_lookup'`, i.e. the lookups that ran inside a `$(...)`.
Nine more gates cost 738 more nested commands, 63 of them the lookups
themselves and the rest the loop bodies inside them. Downstream's own AC-2 run
against upstream, the day before, said the same thing (73 -> 937 with its
richer ten-gate manifest; see `## Notes`).

**What it costs in wall clock**, on manhwa-cropper's real 303-line, 7-gate
`project.conf` on this (noisy) host: `gates.sh --list` took 13.3 / 12.2 /
19.4 / 12.5 / 10.3 s on upstream `gates.sh`, and 4.3 / 5.8 s with the port
applied; neither figure moves with comment lines, because HARNESS-024 already
fixed that axis. `--list` output was byte-identical before and after the port
(`cmp` clean). Wall clock is context only: nothing in this story asserts a
clock, because the figure halves between runs on this machine.

**Required gate that would fail if this broke:** `unit`, which in this
repository is CI's `bash scripts/selftest.sh` step running
`.claude/tests/gates.test.sh`. Every gate in `.claude/harness/project.conf`
here is unconfigured (`BOOTSTRAPPED=no`), as for every harness story.

**Serialisation.** Every story that edits `scripts/gates.sh` in this planning
round runs after the previous one: HARNESS-052 -> HARNESS-055 -> HARNESS-056
-> HARNESS-057, hence `depends_on: [HARNESS-056]`. The dependency is
ordering, not need: this story's change is a local rewrite of nine call sites
and does not build on anything those stories decide. If HARNESS-055 lands a
`table_lookup` caller of the `x=$(table_lookup ...); is_x=$?` shape, it is one
more site for C-2's list, and C-2's status semantics keep it working.

## Acceptance criteria

- **AC-1** — Given a fixture project whose `project.conf` declares one gate,
  and the same fixture with nine more gates declared (ten in all; the
  manifests of C-3), when `bash -x scripts/gates.sh --list` is traced with
  `PS4='+ '` and `BASH_XTRACEFD` on its own descriptor over each, then the
  number of trace lines at depth two or more (lines beginning `++`) is **the
  same for both manifests**, both runs exit 0, and the ten-gate `--list`
  output names every one of the ten gates.
  *Measured today:* 73 -> 811. *Control:* the shipped `gates.sh` fails this by
  construction (seven `$(table_lookup ...)` per gate line); RED shows that
  red. A second, mechanical control: the one-gate count must be greater than
  zero, so a trace that was never written cannot satisfy the equality with
  `0 = 0`.
- **AC-2** — As AC-1 for `bash -x scripts/gates.sh --audit`: equal nested
  counts over the one-gate and ten-gate manifests, both exit 0, and the
  ten-gate audit prints an `ok` line for the tenth gate (so a loop that
  `continue`d early cannot pass by reaching nothing).
  *Measured today:* 73 -> 811. *Control:* as AC-1.
- **AC-3** — Given the synthetic manifest fixture of HARNESS-024
  (`.claude/tests/fixtures/manifest/`), when `gates.sh --list`, `--audit` and a
  full run are checked against the committed goldens for `project`, `broken`
  and `crlf`, then every one is still **byte-identical** (the existing
  HARNESS-024 AC-3 assertions), and the trace oracle of HARNESS-024 AC-1 and
  AC-2 (`trace_externals`) still reports zero `sed`, zero `cut` and at most
  20 externals over `--list`.
  *Control:* this is what stops "fork less" being done by "look up less". A
  `table_get` that misses an id, returns the wrong line, or drops a trailing
  field changes `--list`'s `evidence:` / `floor:` / `waiver:` / `slow:` /
  `ci-factor:` rows and the audit's verdicts, and the goldens go red. It is
  green on arrival, so it is earned by DV-1's second mutation (a wrong
  *value*, not a missing lookup).
- **AC-4** — Given `scripts/gates.sh`, when it is searched, then no line
  matches `$(table_lookup` or `"$(table_lookup`, and `table_lookup` is still
  defined (its predicate callers, which fork nothing, stay).
  *Measured today:* 9 such lines (:382, :413, :414, :415, :416, :417, :418,
  :576, :817). *Control:* a static assertion is cheap to satisfy vacuously;
  it is paired with AC-1/AC-2, which measure the behaviour rather than the
  text, and its needle is anchored on the literal `$(table_lookup` so that a
  comment mentioning the function cannot match.

## Contract

**RED may amend any block below in place, with a reason stated in the block;
GREEN builds what the amended block says.**

**Writes:** `scripts/gates.sh`, `.claude/tests/gates.test.sh`, `.claude/tests/sigpipe.test.sh`

### C-1 `table_get`: name, signature, semantics

Add to `scripts/gates.sh` directly after `table_lookup` (which is at :252-263
today and is not changed), verbatim from the port diff:

```bash
# table_get <var> <table> <id>   table_lookup, assigning <var> instead of echoing,
# so a per-gate lookup costs no fork. <var> is empty and status 1 when no line.
table_get() {
  local _tg_id _tg_val
  while IFS="$TAB" read -r _tg_id _tg_val; do
    if [ "$_tg_id" = "$3" ]; then printf -v "$1" %s "$_tg_val"; return 0; fi
  done <<< "$2"
  printf -v "$1" %s ""
  return 1
}
```

- `table_get <var> <table> <id>` assigns the value of `<id>`'s line in
  `<table>` to the variable named `<var>` and returns 0; when `<id>` has no
  line it assigns the empty string and returns 1. Exact string comparison on
  the id, as `table_lookup`: a gate id containing `.` or `*` must not adopt
  another gate's line.
- **Status semantics are the same as `table_lookup`'s and are load-bearing.**
  Two call sites read `$?` straight after the lookup (`is_ondemand=$?`,
  `is_slow=$?`) and distinguish *a line with an empty value* (status 0, value
  `""`) from *no line* (status 1). `printf -v` does not disturb `$?`, and the
  explicit `return 0` / `return 1` are what the `is_*` pattern reads. A
  rewrite that returns the status of the last `read` is wrong.
- The value is the whole remainder of the line after the first tab, exactly
  as `table_lookup` prints it: the tables are built by HARNESS-024's `rest`,
  so embedded `|` and internal whitespace are already in the value, and
  `table_get` must not trim or re-split it. `read -r` with `IFS="$TAB"` into
  two variables gives the second variable everything after the first tab
  (trailing-IFS stripping removes only trailing *tabs*, and no table value
  ends in one).
- The `_tg_` prefix is so the locals cannot shadow a caller's `<var>`:
  `printf -v "$1"` assigns in the caller's scope only if the name is not
  also a local here.
- bash 3.2: `printf -v` is 3.1+, `<<<` is 2.05b+. No associative arrays.
- **Why not change `table_lookup` itself:** three callers use it as a
  predicate with stdout discarded (`table_lookup "$SLOWS" "$id" >/dev/null`
  at :409, :711 and :747). A redirect on a function call does not fork, so
  they cost nothing and stay as they are; changing the printing function
  under them would be a second behaviour change for no gain.

### C-2 The call sites, all of which change

Each `x=$(table_lookup "$T" "$id") <suffix>` becomes
`table_get x "$T" "$id" <suffix>` with the suffix untouched. The nine, with
today's line numbers:

| Line | Today | After |
|---|---|---|
| :382 | `ondwhy=$(table_lookup "$ONDEMANDS" "$id"); is_ondemand=$?` | `table_get ondwhy "$ONDEMANDS" "$id"; is_ondemand=$?` |
| :413 | `exp=$(table_lookup "$EVIDENCE" "$id") \|\| exp="<none>"` | `table_get exp "$EVIDENCE" "$id" \|\| exp="<none>"` |
| :414 | `waiver=$(table_lookup "$WAIVERS" "$id") \|\| waiver=""` | `table_get waiver "$WAIVERS" "$id" \|\| waiver=""` |
| :415 | `slowwhy=$(table_lookup "$SLOWS" "$id"); is_slow=$?` | `table_get slowwhy "$SLOWS" "$id"; is_slow=$?` |
| :416 | `floor=$(table_lookup "$FLOORS" "$id") \|\| floor=""` | `table_get floor "$FLOORS" "$id" \|\| floor=""` |
| :417 | `skippat=$(table_lookup "$SKIPPEDWHEN" "$id") \|\| skippat=""` | `table_get skippat "$SKIPPEDWHEN" "$id" \|\| skippat=""` |
| :418 | `cifactor=$(table_lookup "$CIFACTORS" "$id") \|\| cifactor=""` | `table_get cifactor "$CIFACTORS" "$id" \|\| cifactor=""` |
| :576 | `extra=$(table_lookup "$BLOCKEDWHEN" "$id") \|\| extra=""` | `table_get extra "$BLOCKEDWHEN" "$id" \|\| extra=""` |
| :817 | `creq="$(table_lookup "$GATE_REQ" "$cid")" \|\| creq=""` | `table_get creq "$GATE_REQ" "$cid" \|\| creq=""` |

The `|| x=""` suffixes are now redundant (`table_get` already assigns `""` on
a miss) but stay, because they also stop `set -e`-style readers and the
`is_*` pattern from diverging in shape, and because a diff that touches only
the left-hand side is the easiest one to review. `|| exp="<none>"` at :413 is
not redundant and must stay.

Line numbers above are those of `8048134`. HARNESS-052, -055 and -056 run
first and may move them; GREEN locates each site by its text, not its number.
If HARNESS-055 adds a site of the same shape (its brief mentions
`is_nocount=$?`), it is converted too and added to this table with a reason.

**No exported signature changes.** `table_lookup` keeps its signature and its
three predicate callers. `table_get` is new. No test file names either
today: `grep -rn 'table_lookup\|table_get' .claude/tests/` found nothing at
`8048134`. RED confirms against the tree at its commit and states so in the
handoff.

### C-3 The nested-command oracle and the two manifests (AC-1, AC-2)

**Oracle.** A `bash -x` trace prefixes each traced command with one `+` per
nesting level. With `PS4='+ '` (the default), a command at top level is
`+ cmd`, inside a `$(...)` or `( ... )` it is `++ cmd`, and so on. The count
`grep -c '^++' trace` is therefore the number of commands run inside a fork,
blind to a top-level pipeline (which `trace_externals` sees) and sighted on a
fork that execs nothing (which `trace_externals` is blind to). Each oracle
covers the other's blind spot; AC-3 keeps the old one in force.

The trace goes to its own descriptor so stdout and stderr stay what a user
sees and can be compared; downstream's `measure`, adapted to upstream's
helpers (RED may restructure, keeping the three measured values):

```bash
# nested_measure <fixture> <out-prefix> <mode>   gates.sh <mode> under bash -x
# with the trace on fd 9. Sets N_RC, N_NESTED (lines at depth >= 2), and
# leaves stdout in <out-prefix>.out, stderr in <out-prefix>.err.
nested_measure() {
  local fix="$1" pre="$2" mode="$3"
  (
    cd "$fix" || exit 99
    exec 9> "$pre.trace"
    BASH_XTRACEFD=9 PS4='+ ' bash -x scripts/gates.sh "$mode" > "$pre.out" 2> "$pre.err"
  )
  N_RC=$?
  N_NESTED=$(grep -c '^++' "$pre.trace")
}
```

`grep -c` on a file is not a pipeline, so `check-grep-count.sh` has nothing to
say about it; RED runs `bash scripts/check-grep-count.sh` and
`bash scripts/check-sigpipe.sh` over the suite anyway and pastes the summary
lines. The helper lives in `gates.test.sh`, not `_lib.sh`, so the story's
footprint stays off a file every sibling story may also edit (`touches:`).

**Manifests.** The one-gate manifest carries every table kind that can sit on
one gate without failing the audit (`no-count` cannot share a gate with a
`floor`, so it is absent). Written with `write_conf` into a
`make_project_fixture`, which prepends `BOOTSTRAPPED=yes`:

```
gate      | g01 | optional | . | printf 'Tests  47 passed (47)\n'
evidence  | g01 | Tests +[1-9][0-9]* passed
floor     | g01 | 40
waiver    | g01 | flaky on the fixture runner, see MC-000
slow      | g01 | builds a release bundle
ci-factor | g01 | 3.4 | measured from CI run 12345
```

The ten-gate manifest is the same six lines followed by, for `i` in 2..10,
with `id` = `g02` .. `g10`:

```
gate      | $id | required | . | printf 'Tests  47 passed (47)\n'
evidence  | $id | Tests +[1-9][0-9]* passed
```

This is the pair the Context figures (73 -> 811) were measured on. Downstream
varies the nine extra gates' table lines by `i % 5` (evidence alternation,
`floor`, `slow`, `ci-factor`, `-`) so that every table grows with the gate
count; RED may port that richer shape instead - the AC's claim is the same
and the shipped code fails it the same way (73 -> 937 downstream) - and if it
does, it records the measured pair in the handoff. Either way the suite
asserts that the ten-gate manifest really declares ten `gate` lines, and the
audit assertion for AC-2 looks for `ok   g10`.

**Expected values after GREEN**, from the port applied to this tree on
2026-10-11: `nested 22 -> 22` for both `--list` and `--audit`. Those are
*expected*, not pinned: the AC is the equality, and a different constant (a
sibling story adding a fork, say) is not a failure of this story. RED
records what it measures in the handoff; GREEN confirms.

### C-4 Oracle partition

| AC | Kind | Instruction to RED |
|---|---|---|
| AC-1, AC-2 | mechanical | pin the count equality exactly; the control is the shipped code's own failure, plus the `> 0` guard on the one-gate count |
| AC-3 | settled | read the goldens and the HARNESS-024 assertions out; they already exist and are not re-derived or re-captured |
| AC-4 | mechanical | anchored literal needle `$(table_lookup`, count of matching lines equals 0 |

Nothing is oracle-free. No threshold, no clock.

### C-5 Line pins that this story moves

`.claude/tests/sigpipe.test.sh` pins status-discarded lines by number in its
C-5 `DISCARDED` block (:555-571 today) and fails as stale when one drifts. Two
are in `gates.sh`:

- `scripts/gates.sh:74:BOOTSTRAPPED="$(grep` - **must not move**; C-1 inserts
  after :263.
- `scripts/gates.sh:580:why="could not launch: $(` - moves down by the eleven
  lines of C-1 (to :591 if nothing else moved; GREEN reads the real number).

**GREEN updates that one number** and nothing else in that file; the "twelve
lines, none stale" count does not change. Every file this story writes
classifies as `harness` (`bash scripts/classify.sh` says so), so the lock
permits the edit in GREEN. After the edit GREEN runs
`bash .claude/tests/sigpipe.test.sh` and pastes its summary line in `## Notes`.

### C-6 Commands, narrowest first

- **RED and GREEN:** `bash .claude/tests/gates.test.sh`. The two traced
  invocations per manifest per mode are four `bash -x` runs of `gates.sh` in
  all; on the shipped code the ten-gate runs are the slow ones (seconds, not
  minutes - the per-line cost is already gone).
- **After the GREEN edits:** `bash .claude/tests/sigpipe.test.sh` (C-5),
  `bash scripts/check-sigpipe.sh`, `bash scripts/check-grep-count.sh`.
- **GATES:** `bash .claude/tests/profiles.test.sh` (runs `gates.sh --audit`
  over profile snippets), `bash .claude/tests/boundaries.test.sh` (writes
  small manifests), then `bash scripts/gates.sh`.
- **Once, before REVIEW:** the full `bash scripts/selftest.sh`, in the
  background.

**Floors.** `.claude/tests/floors.conf` has `floor | gates | 507` and
`selftest.test.sh`'s `COUNTS` block pins that number exactly, so raising one
means writing both. This story adds assertions above the floor and raises
nothing: the floor is a minimum, and both files are ones every sibling story
of this round would otherwise collide on. The next story that must touch them
raises the figure to the measured count then.

## Deferred verifications

- **DV-1 - defect put back (the story's central claim). Owner: GATES.**
  Condition (a): with ONE converted site reverted to the forking form - :413's
  `table_get exp "$EVIDENCE" "$id"` back to `exp=$(table_lookup "$EVIDENCE"
  "$id")` - AC-1's and AC-2's equality assertions **must** go red, and the
  measured gap must be exactly nine more nested `table_lookup` substitutions
  for nine more gates plus their loop bodies: the one-gate count rises by one
  substitution's worth and the ten-gate count by ten. One assertion per mode
  catches it; AC-3 and AC-4 (the text check) also go red, the latter by one
  line. RED cannot run this: on the shipped code every site is still the
  forking form, so there is nothing to put back. Run as
  `bash scripts/mutate.sh scripts/gates.sh 's|table_get exp "\$EVIDENCE" "\$id"|exp=$(table_lookup "$EVIDENCE" "$id")|' -- bash .claude/tests/gates.test.sh`
  (escape to taste; the expression must change exactly one line, and
  `mutate.sh` prints how many it changed).
  Condition (b), the wrong-*value* mutation this port-shaped story adds: with
  `table_get`'s `printf -v "$1" %s "$_tg_val"` changed to
  `printf -v "$1" %s "$_tg_id"` (the value replaced by the id), AC-1 and AC-2
  stay green - the fork count does not move - and AC-3's `--list` and `--audit`
  goldens **must** go red (`evidence: unit` where `evidence: Tests +...` was).
  This is the control that shows AC-3 is what guards correctness, and that the
  count oracle alone would wave a wrong lookup through. Run as
  `bash scripts/mutate.sh scripts/gates.sh 's|printf -v "\$1" %s "\$_tg_val"|printf -v "$1" %s "$_tg_id"|' -- bash .claude/tests/gates.test.sh`.
  For both: confirm the suite is green again on the restored file and paste
  `mutate.sh`'s `restored (verified ...)` line with the red lines here.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-057` from `.claude/harness/models.conf`.
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

No departure from the plan. The oracle partition RED is briefed with is C-4
of the Contract: AC-1, AC-2 and AC-4 mechanical, AC-3 settled, nothing
oracle-free. PLANNED ran on `fable` (Fable 5.1, the agent's own `model:`; no
override was reported to this dispatch).

## Out of scope

- **MC-046 and MC-047** (the gate-accounting and `</dev/null` changes also in
  the scratch port diff) - those are HARNESS-052. The diff this story takes
  from that file is `table_get` and the nine call-site lines only.
- **The predicate callers of `table_lookup`** at :409, :711 and :747
  (`... >/dev/null`). They fork nothing and are not touched; AC-4's needle is
  `$(table_lookup`, which they do not match.
- **The per-line parse cost** - HARNESS-024, done. The padded-manifest
  assertions stay as they are and keep passing (AC-3).
- **Wall-clock assertions.** The Context's seconds are evidence for the
  story's existence, never for its tests.
- **`doctor.sh` and `task.sh`.** Neither has a `table_lookup`; HARNESS-024
  already made their parsers builtin.
- **Raising the `gates` floor** in `floors.conf` and `selftest.test.sh`
  (C-6, Floors).
- **The trailing-newline drop.** Found in triage, not fixed here, recorded as
  a follow-up in `## Notes` with its reproduction. It is a different defect
  in the same loops (`while IFS= read -r line` returns 1 on a final line with
  no `\n`, and both parse loops drop it), it needs its own failing test and
  its own fix, and it would widen this story past one behaviour.
- `_lib.sh`. The nested-count helper is local to `gates.test.sh` (C-3);
  promoting it to `_lib.sh` for `doctor.test.sh` to share is a later story's
  call, if one ever needs it.

## Design notes

<!-- Omitted: headless work. -->

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

## Gate results

<!-- Written by scripts/gates.sh itself on every full run, stamped with the
     commit and a hash of the code it ran against. Do not paste or edit it:
     check-boundaries.sh refuses a PR whose recorded run does not match the
     code being merged. -->

## Notes

**Provenance (Lead PO, PLANNED, 2026-10-12).** Source: manhwa-cropper commit
`cf01401` (MC-045), `git -C D:/manhwa-cropper show cf01401`; downstream
suite `.claude/tests/gates-parse.test.sh` (AC-1 per-line, AC-2 per-gate, AC-3
a golden of *that project's* `--list` format). Triage on 2026-10-11 ran the
downstream suite, adapted (its `no-count` lines removed from AC-2's ten-gate
manifest; AC-3 not run because it pins a consumer's format), against
upstream release 93:

```
AC-1: measured --list: execs 4 -> 4, nested 77 -> 77 (unpadded -> padded)   all ok, 17 passed
AC-2: measured --list: execs 4 -> 4, nested 73 -> 937 (1 gate -> 10 gates)
    FAIL gates.sh --list runs no extra nested command for nine more gates  expected: 73 actual: 937
      measured --audit: execs 4 -> 4, nested 73 -> 937
    FAIL gates.sh --audit runs no extra nested command for nine more gates
gates-parse: 17 passed, 2 failed
```

With `table_get` and the nine conversions applied (alongside the HARNESS-052
changes, which do not touch these sites): AC-2 `nested 22 -> 22` in both
modes, `gates-parse: 19 passed, 0 failed`, and the full upstream
`gates.test.sh`: `507 passed, 0 failed`. The scratch directory holding the
port diff, the patched `gates.sh` and the perf traces is deleted after
planning; everything the next agent needs is in C-1, C-2 and C-3 verbatim.

**AC-1/AC-2 figures in the Context (73 -> 811)** were re-measured by the Lead
PO on this tree with the simpler ten-gate manifest of C-3, not the downstream
suite, so that the numbers in this story come from the manifest this story
pastes. The `table_lookup_subst` column (7 -> 70) is the direct count of the
forking lookups and matches nine sites minus the two reached only on a
failing gate or a covered path: seven per gate line in `--list`/`--audit`.

**Follow-up, not this story: a final manifest line with no trailing newline
is silently dropped.** Both `while IFS= read -r line` loops in `gates.sh`
(the tables pass and the gate loop) end when `read` returns non-zero, which
it does on a last line that has data but no `\n` - and the body never runs
for it. Reproduction (`nonl.sh`, run against `8048134` on 2026-10-12; the
gate `z` is `exit 1` and required, and the run passes):

```bash
. "$1/.claude/tests/_lib.sh"
FIX="$(make_project_fixture)"
printf "BOOTSTRAPPED=yes
gate | a | required | . | true
gate | z | required | . | exit 1" > "$FIX/.claude/harness/project.conf"; tail -c 40 "$FIX/.claude/harness/project.conf" | od -c | tail -3
( cd "$FIX" && bash scripts/gates.sh 2>&1 ) </dev/null | grep -E '^(PASS|FAIL|All|[0-9]+ req)'; echo "exit=${PIPESTATUS[0]}"
rm -rf "$FIX"
```

```
0000020       |       r   e   q   u   i   r   e   d       |       .    
0000040   |       e   x   i   t       1
0000050
PASS         a (1s) -- no evidence line: a vacuous pass would go unnoticed
All required gates passed (1 ran, 0 unconfigured, 0 known).
exit=0
```

A required gate declared on the last line is never run and the run reports
green. HARNESS-052 (MC-047's "declared but never accounted for" check) will
**not** catch it: `GATE_IDS` is built in the tables pass (`gates.sh:154`),
which is the same `while IFS= read -r line` shape and drops the same line, so
the gate is missing from the declared list as well as from the run. Fix
shape, for whoever cuts it: `while IFS= read -r line || [ -n "$line" ]; do`
in both loops, with the reproduction above as the failing case.
