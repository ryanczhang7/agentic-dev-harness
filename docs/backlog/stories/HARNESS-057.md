---
id: HARNESS-057
title: gates.sh looks up a gate's settings without forking, so --list and --audit no longer cost about 1.5 s per gate
slug: gates-sh-looks-up-a-gate-s-settings-with
epic: 
type: fix
status: in-progress
phase: GATES
branch: story/HARNESS-057-gates-sh-looks-up-a-gate-s-settings-with
depends_on: [HARNESS-056]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/gates.sh, .claude/tests/gates.test.sh, .claude/tests/sigpipe.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh]         # files this story expects to write; `plan.sh conflicts` reads it
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

**Writes:** `scripts/gates.sh`, `.claude/tests/gates.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

**Re-anchored 2026-10-15 (Lead PO, before RED), after HARNESS-052, -055 and
-056 landed.** `scripts/gates.sh` is 1122 lines. Verified by grep today:
`table_lookup()` at `:261`; **ten** forking call sites, not nine - C-2's
nine at `:420`, `:451-456`, `:636`, `:892`, plus HARNESS-055's
`nocountwhy=$(table_lookup "$NOCOUNTS" "$id"); is_nocount=$?` at `:457`,
which C-2 anticipated and which converts to
`table_get nocountwhy "$NOCOUNTS" "$id"; is_nocount=$?` (the `is_*` status
shape); the three predicate callers at `:447`, `:776`, `:822` stay. The
sigpipe pins (`sigpipe.test.sh:567-568`) read `scripts/gates.sh:77:` and
`scripts/gates.sh:640:`; C-1's eleven lines land after `:271`, so the second
moves to about `:651` - **GREEN pins what `grep -n 'could not launch: \$('`
prints**. No test names `table_lookup` or `table_get` (grep over
`.claude/tests/`: 0 lines). **Re-measured on this tree with C-3's manifests
and oracle:**

    one --list   rc=0 nested=81  table_lookup_subst=8   gates_named=1
    ten --list   rc=0 nested=891 table_lookup_subst=80  gates_named=10
    one --audit  rc=0 nested=81  table_lookup_subst=8
    ten --audit  rc=0 nested=891 table_lookup_subst=80

Eight forking lookups per gate line now (the tenth site), 81 -> 891; the
AC is the equality and is failed the same way. RED records what it measures.

**PO decision 1 (2026-10-15).** C-6's "raises nothing" is reversed: the
`gates` floor is **654** today (`floors.conf:44`, mirrored at
`selftest.test.sh:535`), and the sibling-collision reason for leaving it is
gone - 052, 055 and 056 are DONE and 058 touches neither file. RED raises it
to the executed count it reads off its own run, in both tables, as every
story this round did (`touches:` and `**Writes:**` widened accordingly).

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

- RED, `test-developer`, 2026-10-15: **Opus 5.5** (`claude-opus-5-5`), its declared `model:`; no override. Planned `opus`; no change.
- GREEN, `feature-developer`, 2026-10-15: **Opus 5.5** (`claude-opus-5-5`), its declared `model:`; no override. Planned `opus`; no change.

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

One new section in `.claude/tests/gates.test.sh`, "HARNESS-057: a gate's
settings are looked up without forking" (`:1499-1627`), placed after
HARNESS-024's AC-6 and before HARNESS-026. Level: integration - the real
`scripts/gates.sh`, copied into two `make_project_fixture` trees, run under
`bash -x` (AC-1, AC-2); a static count over the shipped file (AC-4). It uses
its own fixtures, not `MFX`, because C-3's manifests are `write_conf` bodies.

Helpers, all local to `gates.test.sh` (C-3; nothing in `_lib.sh`):
`nested_measure` exactly as C-3 gives it (unchanged; `exec 9>` +
`BASH_XTRACEFD=9` works on this Git Bash), `_h57_one` / `_h57_ten` (C-3's
manifests verbatim, the simple shape - not downstream's `i % 5` variant), and
`_h57_same` (the equality, whose failure message prints both nested counts and
both `^++ table_lookup` counts).

| # | Assertion (test name, abridged) | AC | On arrival |
|---|---|---|---|
| 1 | one-gate manifest declares exactly one gate line | fixture | green (precondition) |
| 2 | ten-gate manifest declares exactly ten gate lines | fixture (C-3 "asserts ten gate lines") | green (precondition) |
| 3 | every gate command is one line with its `\n` intact (fixed-string count = 10) | fixture | green (precondition) |
| 4 | ten-gate manifest is exactly 25 lines | fixture | green (precondition) |
| 5, 9 | traced one-gate `--list` / `--audit` exits 0 | AC-1, AC-2 | green |
| 6, 10 | traced ten-gate `--list` / `--audit` exits 0 | AC-1, AC-2 | green |
| 7, 11 | control: one-gate nested count `> 0` (prints the count) | AC-1, AC-2 control | green (81) |
| 8 | **`--list` nested count equal over ten gates and one** | AC-1 | **RED** (81 vs 891) |
| 12 | **`--audit` nested count equal over ten gates and one** | AC-2 | **RED** (81 vs 891) |
| 13 | ten-gate `--list` names g01..g10, once each (`^gNN +(optional\|required) `) | AC-1 | green |
| 14 | ten-gate `--audit` prints `^ok +g10 +evidence: ` exactly once | AC-2 | green |
| 15 | ten-gate `--audit` prints `^Manifest audit passed\.$` | AC-2 | green |
| 16 | **`grep -c -F '$(table_lookup' scripts/gates.sh` = 0** | AC-4 | **RED** (10) |
| 17 | `grep -c -E '^table_lookup\(\) \{' scripts/gates.sh` = 1 | AC-4 (anti-vacuity) | green |

AC-3 has **no new assertion** (C-4: settled). It is read out of the existing
HARNESS-024 blocks, unchanged: the C-3 instrument controls (`:1265`), the
AC-1 `trace_externals` assertions (`:1303`; zero sed, zero cut, at most 20
externals over `--list`), AC-2 `same_count` and padded goldens (`:1321`),
AC-3's nine goldens for `project`, `broken`, `crlf` x `list`, `audit`, `run`
(`:1351`), and AC-4's whole-value needles (`:1368`). All green on arrival in the run below.

## Handoff: RED -> GREEN

**Model.** RED ran on `opus` (Claude Opus 5.5, `claude-opus-5-5`), the
agent's own `model:`; no override was reported to this dispatch.

**Commands.**

    bash .claude/tests/gates.test.sh          # the suite (about 4 min here)
    bash scripts/selftest.sh gates            # the same, with the floor check

**Failure output on arrival** (`bash scripts/selftest.sh gates`, this tree,
`gates.sh` unchanged, 2026-10-15, wall 4m05s; excerpt - every other section
printed only its describe line):

```
  HARNESS-057 fixtures: the ten-gate manifest declares ten gates, the one-gate manifest one

  HARNESS-057 AC-1: gates.sh --list runs no more nested commands for nine more gates
    FAIL AC-1: gates.sh --list runs as many nested commands over ten gates as over one
         nested commands (trace lines at depth >= 2): one gate 81, ten gates 891
         of which $(table_lookup ...) substitutions: one gate 8, ten gates 80

  HARNESS-057 AC-2: gates.sh --audit runs no more nested commands for nine more gates
    FAIL AC-2: gates.sh --audit runs as many nested commands over ten gates as over one
         nested commands (trace lines at depth >= 2): one gate 81, ten gates 891
         of which $(table_lookup ...) substitutions: one gate 8, ten gates 80

  HARNESS-057 AC-4: gates.sh has no $(table_lookup substitution, and still defines table_lookup
    FAIL AC-4: no line of scripts/gates.sh contains $(table_lookup
         expected: 0
         actual:   10

gates: 668 passed, 3 failed

assertion floors: all 1 suite(s) met their declared floor (668 assertions executed, 654 declared).
1 of 1 harness suite(s) FAILED.
```

(That floor line predates the floor raise below; against 671 the suite now
sits 3 below its floor until GREEN.) Exactly the three intended assertions are
red, each for the defect: 81 -> 891 nested, 8 -> 80 forking lookups - the
re-anchored figures exactly - and ten matching lines. Nothing else in the
suite is red. The section alone (extracted into a scratch script with
`VERBOSE=1`) printed `h57: 14 passed, 3 failed` and every green assertion
named in the Test plan.

**Files touched (RED).**

- `.claude/tests/gates.test.sh` - the new section (`:1499-1627`).
- `.claude/tests/floors.conf` - `gates 654 -> 671` (`:44`) and the dated
  measurement comment at the end of the file.
- `.claude/tests/selftest.test.sh` - the mirrored `COUNTS` row, `gates 671`
  (`:535`).
- this story: `## Test plan`, `## Handoff: RED -> GREEN`.

Not touched: `scripts/gates.sh` (GREEN's), `.claude/tests/sigpipe.test.sh`
(C-5: GREEN's).

**Floor (PO decision 1).** `gates` raised 654 -> **671** in both tables =
the EXECUTED count (668 passed + 3 failed) read off the run above. The new
section adds exactly 17 (4 fixture + 2 x 4 in the mode loop + 1 + 2 + 2; the
`> 0` control is an if/else with one assertion per arm, so the count is
unconditional). `bash scripts/selftest.sh selftest`: `selftest: 268 passed,
0 failed`. Floors count passes, so the suite is 3 below its floor until GREEN.
Note that `## Out of scope` and C-6's "Floors" paragraph still say the floor
is not raised; PO decision 1 supersedes both and I did not edit them.

**Export shape the tests pin.** The tests import nothing from `gates.sh`;
they pin behaviour and text:

- Over C-3's manifests, `--list` and `--audit` must run the **same** number of
  `^++` trace lines for one gate and for ten. This means every per-gate lookup
  on the paths `--list`/`--audit` reach must be fork-free - all eight per gate
  line today (`:420`, `:451-457`). The two failure/coverage-only sites (`:636`,
  `:892`) are not reached by these runs; AC-4 is what makes them convert.
- No line of `scripts/gates.sh` may contain the literal `$(table_lookup`
  (fixed string; `"$(table_lookup` contains it). All ten C-2 sites, including
  HARNESS-055's `:457` (`table_get nocountwhy "$NOCOUNTS" "$id"; is_nocount=$?`).
  A comment must not quote the old form with `$(`.
- `table_lookup() {` must still start a line (count exactly 1): the
  function stays, as do its three predicate callers (`:447`, `:776`, `:822`).
- Not pinned by a new test but by C-1 and AC-3's goldens: `table_get <var>
  <table> <id>`, status 0 and the whole remainder after the first tab assigned
  on a hit, status 1 and `""` on a miss, exact string compare on the id,
  no trim or re-split.
- **Unconstrained:** where `table_get` sits in the file (C-1 says after
  `table_lookup`, the tests do not), its local names (the `_tg_` prefix is C-1's
  shadowing argument, not a test), comment wording, and whether the redundant
  `|| x=""` suffixes stay. The absolute nested constant (22 measured below) is
  not pinned - only the equality.
- `grep -rn 'table_lookup\|table_get' .claude/tests/` is no longer empty:
  the new section names `table_lookup` (AC-4's needle and messages). Nothing
  names `table_get`.

**Passed on arrival, and what earns each.**

| Assertion | Earned by |
|---|---|
| AC-3 goldens + `trace_externals` (HARNESS-024, existing) | DV-1 (b), GATES: wrong-value mutation must turn them red |
| fixture checks 1-4 | probed off-framework: a manifest whose `\n` had been expanded into a real newline (my own first draft did this) gives 0 on check 3, not 10; check 4 counts 25 lines against 34 for that broken shape |
| `> 0` controls (7, 11) | measured 81 on arrival; off-framework, the guard expression returns false for an empty count and for 0 |
| exits 0, ten gates named, `ok g10`, audit passed | measured on arrival; the ten-gate outputs were read by eye (all ten `ok` lines, `Manifest audit passed.`); DV-1 (b) turns `--audit`'s exits red (see below) |
| AC-4 `table_lookup()` defined | anti-vacuity guard; a GREEN that deleted the function would turn it red |

**Expected values (controls), measured off-framework on a CANDIDATE.** I
applied C-1 and the C-2 conversions with `awk`/`sed` to the COPY of
`gates.sh` inside two temp `make_project_fixture` trees (never the tree), and
ran `nested_measure` over C-3's manifests. These are claims about the
candidate; GREEN confirms them against its own `gates.sh`.

| Condition | Mode | one gate (rc/nested) | ten gates (rc/nested) | Assertions expected |
|---|---|---|---|---|
| shipped (RED, measured in suite) | --list | 0/81 | 0/891 | AC-1 eq RED |
| shipped (RED, measured in suite) | --audit | 0/81 | 0/891 | AC-2 eq RED |
| C-1 + C-2 applied (GREEN) | --list | 0/22 | 0/22 | all green; `$(table_lookup` count 0 |
| C-1 + C-2 applied (GREEN) | --audit | 0/22 | 0/22 | all green |
| DV-1 (a): `:451`'s `exp` site reverted | --list | 0/29 | 0/227 | AC-1 eq RED; AC-4 RED with 1 |
| DV-1 (a) | --audit | 0/29 | 0/227 | AC-2 eq RED |
| DV-1 (b): `table_get` assigns `$_tg_id` | --list | 0/22 | 0/22 | AC-1 eq green; `--list` shows `evidence: g01`, `floor: g01` |
| DV-1 (b) | --audit | **1**/22 | **1**/22 | AC-2 eq green, but AC-2's two exits-0 and `audit passed` go RED too |

Threshold for every equality: exact. Candidate range: none (22 = 22 matches
C-3's downstream figure; a different equal constant also passes). The `> 0`
control's threshold is 1; measured 81 (shipped) and 22 (candidate).

**Discovered, for GREEN and GATES.**

- DV-1 (a)'s gap is +7 nested for one gate (22 -> 29) and +205 for ten
  (22 -> 227), not "one substitution's worth" per gate in a literal sense: one
  reverted lookup costs about 7 nested lines per gate it runs for (the
  substitution plus its loop body). The equality goes red either way.
- DV-1 (b) does NOT leave AC-2 wholly green as the DV text says: the audit
  fails on a floor of `g01` (not a number), exits 1, and AC-2's exits-0 and
  `Manifest audit passed` assertions go red alongside AC-3's goldens. The
  equality assertions themselves stay green (22 = 22), which is the point of
  the condition. Record it as measured when GATES runs DV-1.
- C-5: GREEN pins the sigpipe line to whatever
  `grep -n 'could not launch: \$(' scripts/gates.sh` prints (`:640` today;
  `:648` in my candidate with an uncommented eight-line `table_get`, so about
  `:651` with C-1's comment) and confirms with `bash scripts/selftest.sh sigpipe`.
- DV-1's commands quote the `exp` site; it is `:451` today, not `:413`.

**Other checks run in RED.** `bash scripts/check-sigpipe.sh`: `check-sigpipe:
scanned 49 shell file(s), 45 with pipefail, 0 finding(s)`.
`bash scripts/check-grep-count.sh`: `check-grep-count: scanned 49 shell
file(s), 0 finding(s)`. `bash scripts/gates.sh --fast`: `All required gates
passed (0 ran, 5 unconfigured, 0 known).` - nothing runs here
(`BOOTSTRAPPED=no`), as expected.

**Deferred verifications.** DV-1 (a) and (b) are owned by GATES and I could
not run them: they mutate `table_get`, which does not exist in RED. The
candidate measurements above are on a temp copy, not a `mutate.sh` run
against the shipped file, and are not a substitute for them.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-15T20:48:12Z
    commit: 3e22256
    tree:   52e07d15525a252e41656307883a8dd7368009f8
    result: pass (0 ran, 7 unconfigured, 0 known)

    UNCONFIGURED format
    UNCONFIGURED lint
    UNCONFIGURED typecheck
    UNCONFIGURED unit
    UNCONFIGURED coverage
    UNCONFIGURED integration
    UNCONFIGURED build
    ON REQUEST   mutation (not run: per-story cost the user declined (HARNESS-015); run it with /audit-mutations; bash scripts/gates.sh --gate mutation)

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

### RED verification (orchestrator, 2026-10-15)

RED dispatched to `test-developer`; it reported running on `opus`. Its diff
was read in full: one section in `gates.test.sh` (+130, 17 assertions) with
C-3's `nested_measure` and manifests verbatim, four fixture checks, the
two-mode loop (exits, the `> 0` control, the equality with both nested and
lookup counts in its failure message), AC-1's ten names and AC-2's `ok g10`
anchored, and AC-4's zero count paired with "`table_lookup()` still
defined"; `gates` floor 654 -> 671 in both tables. Nothing outside test
files and this story.

Orchestrator's own run against the unpatched `scripts/gates.sh`:

    $ time bash scripts/selftest.sh gates
      HARNESS-057 AC-1: gates.sh --list runs no more nested commands for nine more gates
        FAIL AC-1: gates.sh --list runs as many nested commands over ten gates as over one
             (one gate 81, ten gates 891; $(table_lookup ...) substitutions 8 and 80)
      HARNESS-057 AC-2: gates.sh --audit runs no more nested commands for nine more gates
        FAIL AC-2: gates.sh --audit runs as many nested commands over ten gates as over one
      HARNESS-057 AC-4: gates.sh has no $(table_lookup substitution, and still defines table_lookup
        FAIL AC-4: no line of scripts/gates.sh contains $(table_lookup   (expected 0, actual 10)
    gates: 668 passed, 3 failed
    FAIL gates  did 668 units of work, below the floor of 671
    real    3m55s   (a quiet machine, for once)

    $ bash scripts/selftest.sh selftest
    selftest: 268 passed, 0 failed
    $ bash scripts/check-sigpipe.sh
    check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
    $ bash scripts/check-grep-count.sh
    check-grep-count: scanned 49 shell file(s), 0 finding(s)
    $ bash scripts/gates.sh --fast
    All required gates passed (0 ran, 5 unconfigured, 0 known).

Right failure: exactly the two equalities and the text check are red, with
the counts the PO re-measured (81 vs 891, 8 vs 80 forking lookups, ten
matching lines); every HARNESS-024 golden and externals assertion stays
green. Floors count passes, so the suite also sits 3 below its new floor
until GREEN.

**Contract notes from the handoff, accepted (2026-10-15):** DV-1 (b)'s
"AC-1 and AC-2 stay green" is amended - with the value replaced by the id,
`g01`'s floor reads a non-number and the audit exits 1, so AC-2's two
exit-0 assertions and its "audit passed" assertion go red beside AC-3's
goldens; the equalities themselves stay green (22 = 22 on RED's candidate).
DV-1 (a)'s gap is one lookup's loop body per gate (about 7 nested lines),
22 -> 29 and 22 -> 227 on the candidate, not "one substitution". The `exp`
site is `:451` today. GATES reads DV-1 with these corrections.

### GREEN verification (orchestrator, 2026-10-15)

The feature-developer's diff was read in full. `scripts/gates.sh` (+21/-10):
`table_get` verbatim from C-1 directly after `table_lookup()` (`:269-279`);
all ten forking sites converted by text with every suffix untouched (`:431`
`ondwhy; is_ondemand=$?`, `:462` `exp || exp="<none>"`, `:463-467`,
`:468` `nocountwhy; is_nocount=$?`, `:647` `extra`, `:903` `creq`); the
three predicate callers untouched. `grep -c -F '$(table_lookup'` = 0 and
`grep -c -E '^table_lookup\(\) \{'` = 1 on the tree. `sigpipe.test.sh:568`
moved `:640` -> `:651`, the eleven lines of C-1, exactly as C-5 estimated;
the `:77` pin did not move. Nothing else changed.

Orchestrator's own measurement with C-3's oracle, on the shipped script:

    one --list   rc=0 nested=22 table_lookup_subst=0
    ten --list   rc=0 nested=22 table_lookup_subst=0
    one --audit  rc=0 nested=22 table_lookup_subst=0
    ten --audit  rc=0 nested=22 table_lookup_subst=0

81 -> 891 on arrival is 22 -> 22 now, and no `table_lookup` runs inside a
fork. The constant 22 is what the Contract expected (not pinned; the AC is
the equality).

Orchestrator's own suite runs against the shipped tree:

    $ bash scripts/selftest.sh sigpipe
    sigpipe: 82 passed, 0 failed    (floor 82 met; C-5 finds the pin at :651)
    $ time bash scripts/selftest.sh gates
    gates: 671 passed, 0 failed     (floor 671 met)   real 3m51s
    $ bash scripts/gates.sh --audit
    Manifest audit passed.
    $ bash scripts/gates.sh --fast
    All required gates passed (0 ran, 5 unconfigured, 0 known).
    $ bash scripts/check-sigpipe.sh
    check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
    $ bash scripts/check-grep-count.sh
    check-grep-count: scanned 49 shell file(s), 0 finding(s)

Every control landed where the handoff expected: the three RED assertions
pass (22 = 22 in both modes, 0 forking lookups), AC-1's ten names and
AC-2's `ok g10` hold, and every HARNESS-024 golden and externals assertion
(AC-3) is still green - so the forks went without a lookup going wrong.
DV-1 (a) and (b) are GATES' to run.

### DV-1 results (GATES, orchestrator, 2026-10-15)

**(a) The `exp` site reverted to the forking form.** Exactly AC-1, AC-2 and
AC-4 red (668/3): one lookup back inside a `$(...)` costs 29 nested for one
gate and 227 for ten (1 and 10 forking lookups), and the text check counts
one line. AC-3's goldens stayed green - a forking lookup returns the same
value, so the entry's "AC-3 also goes red" was wrong and the equality is
what catches this defect. Restored and verified:

```
$ bash scripts/mutate.sh scripts/gates.sh 's|table_get exp "$EVIDENCE" "$id"|exp=$(table_lookup "$EVIDENCE" "$id")|' -- bash scripts/selftest.sh gates
=== mutate: scripts/gates.sh (1 line(s) changed by ...) ===
    FAIL AC-1: gates.sh --list runs as many nested commands over ten gates as over one
         nested commands (trace lines at depth >= 2): one gate 29, ten gates 227
         of which $(table_lookup ...) substitutions: one gate 1, ten gates 10
    FAIL AC-2: gates.sh --audit runs as many nested commands over ten gates as over one
         nested commands (trace lines at depth >= 2): one gate 29, ten gates 227
         of which $(table_lookup ...) substitutions: one gate 1, ten gates 10
    FAIL AC-4: no line of scripts/gates.sh contains $(table_lookup   (expected 0, actual 1)
gates: 668 passed, 3 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_gates.sh.20261015T203355Z.505758.bak) ===
```

**(b) `table_get` assigns the id instead of the value.** The AC-1/AC-2
equalities stayed green (22 = 22: the fork count does not move) while AC-3's
nine goldens went red with 164 more assertions that read a looked-up value
- and, as RED's handoff corrected, AC-2's two exit-0 assertions and its
"audit passes" went red too, because `g01`'s floor now reads `g01` and the
audit exits 1. That is the control: the count oracle alone would wave a
wrong lookup through, and the goldens are what guard correctness. Restored
and verified:

```
$ bash scripts/mutate.sh scripts/gates.sh 's|printf -v "$1" %s "$_tg_val"|printf -v "$1" %s "$_tg_id"|' -- bash scripts/selftest.sh gates
=== mutate: scripts/gates.sh (1 line(s) changed by ...) ===
    FAIL a live gate passes                                   (expected PASS         unit; actual empty)
    FAIL a floor without an evidence line                     (actual: FAIL unit         floor 'unit' is not a number)
    FAIL --list shows the no-count reason beside the gate     (actual: the gate's own command line)
    ...
    FAIL AC-3: gates.sh --list over project.conf is byte-identical to the pre-rewrite golden
    FAIL AC-3: gates.sh --audit over project.conf is byte-identical to the pre-rewrite golden
    FAIL AC-3: gates.sh full run over project.conf is byte-identical to the pre-rewrite golden
    FAIL AC-3: (the same three for broken.conf and crlf.conf)
    FAIL AC-4 -f3-: an evidence regex keeps its alternation   (actual: short ... <unconfigured>)
    ...
    FAIL the traced one-gate --audit exits 0                  (expected 0, actual 1)
    FAIL the traced ten-gate --audit exits 0                  (expected 0, actual 1)
    FAIL AC-2: and the ten-gate --audit passes                (expected 1, actual 0)
    ...
gates: 498 passed, 173 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_gates.sh.20261015T203947Z.536533.bak) ===
$ bash scripts/mutate.sh --check
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

### GATES (orchestrator, 2026-10-15)

DV-1 (a) and (b) ran through `scripts/mutate.sh` against the `gates` suite
before the gate run, both restored byte for byte, `--check` clean. Then
`bash scripts/gates.sh` recorded `result: pass (0 ran, 7 unconfigured,
0 known)` against `3e22256`; every gate is unconfigured on this repository,
so the suites and the full self-test before REVIEW are the judge.
