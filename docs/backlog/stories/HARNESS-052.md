---
id: HARNESS-052
title: A gate that reads stdin cannot swallow the gates after it, and a run accounts for every declared gate
slug: a-gate-that-reads-stdin-cannot-swallow-t
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-052-a-gate-that-reads-stdin-cannot-swallow-t
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/gates.sh, scripts/doctor.sh, .claude/tests/gates.test.sh, .claude/tests/doctor.test.sh, .claude/tests/sigpipe.test.sh]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

This is a port. The consuming project manhwa-cropper (`D:/manhwa-cropper`)
fixed two defects in its copy of `scripts/gates.sh` on 2026-09-23, as
MC-046 (commit `a60eb69`) and MC-047 (commit `b440b59`). Upstream, release 93
and 94 are identical in the affected files and have neither fix. Until they do,
`refresh-harness.sh` into manhwa-cropper would overwrite both; the memory rule
"port before refresh" is why this story exists now. A triage on 2026-10-11 ran
the downstream suites, adapted, against upstream release 93; its numbers are
below and its artefacts are listed under `## Notes`.

### Defect 1 (MC-046, MISSING upstream): a gate command inherits the manifest as stdin

`scripts/gates.sh` reads `project.conf` on the gate loop's stdin
(`while IFS= read -r line; do ... done < "$CONF"`, lines 341-681) and runs each
gate inside that loop with no stdin redirect, line 560:

```bash
  ( cd "$ROOT/$cwd" && eval "$cmd" ) 2>&1 | tee "$log"
```

A gate command that reads stdin - `cat`, a tool that drains its input,
anything that waits for a prompt - reads the unread rest of the manifest. The
loop sees EOF and ends. Every later gate never runs, never appears in the
summary and is never counted, and nothing reports it missing. A failing
required gate after the stdin-reader therefore turns into "All required gates
passed", exit 0. The `cksum` check at line 849 (`CONF_AT_PARSE`) does not fire,
because the file is unchanged; only the read position moved. This is a
confirmed false-certification defect, which `rules.md` law 3 exists to
prevent.

Measured on upstream release 93 with the adapted downstream suite
(`mc046.test.sh`, two gates: `eats` runs `cat >/dev/null; printf 'Tests 1
passed\n'`, then `later`):

```
  a gate that reads its stdin cannot delete the gates after it
    FAIL the gate after a stdin-reading gate still runs
         expected to contain: === gate: later (required) ===
         actual:
         === gate: eats (required) ===
         cat >/dev/null; printf 'Tests 1 passed\n'
         Tests 1 passed

         --- gate summary ---
         PASS         eats (1s, observed 1)
         ...
         All required gates passed (1 ran, 0 unconfigured, 0 known).
    FAIL a failing required gate after a stdin-reading gate is reported FAIL
         expected a summary line: FAIL         later (<n>s, exit 1) -> .claude/state/gate-logs/later.log
    FAIL a gate reads zero bytes of stdin, whatever gates.sh was given
         expected: stdin-bytes=0
         actual:   stdin-bytes=57
gates: 3 passed, 19 failed
```

With `</dev/null` on line 560 and nothing else: `gates: 22 passed, 0 failed`.

The same shape, untested downstream and upstream, is in `scripts/doctor.sh`
line 268, which evals each `discovery` command inside `done < "$CONF"` (line
275). Reproduced at PLANNED on a `make_project_fixture` copy, stdin from
`/dev/null`:

```
discovery | eats  | . | cat >/dev/null; true
discovery | later | . | false
```

```
Test discovery
  ok       eats         discovered
rc=0
```

`later` is `false`, so it should print `MISSING  later` and doctor should exit
1; with `later` alone in the manifest it does (`MISSING  later        nothing
discovered by: false`, rc=1). After `eats` it vanishes and doctor exits 0.

### Defect 2 (MC-047, PARTIAL upstream): nothing checks that every declared gate was reached

Upstream already refuses an in-place rewrite of `project.conf` mid-run
(`FAIL config: .claude/harness/project.conf changed while the gates were
running`, via `cksum`). It lacks the general invariant behind it: **every
`gate` line declared at parse time (`GATE_IDS`, read at line 154 before any gate
runs) must be reached by the run loop, or the run is refused by name.** The
`cksum` catches one cause of loss; the invariant catches the class, whatever the
cause, including causes nobody has reported yet. Downstream proved the two are
independent: with the accounting applied but NOT `</dev/null`, the stdin case
is *refused* instead of certified:

```
         --- gate summary ---
         PASS         eats (0s, observed 1)
         FAIL         later (declared in project.conf but never accounted for)
         ...
         1 declared gate(s) never accounted for; this run certifies nothing.
         ...
         1 required gate(s) failed.
```

Adapted downstream suite `mc047.test.sh` on upstream release 93: `gates: 29
passed, 37 failed` (every refusal, seam and record assertion; the healthy-run
pins pass). With the prototype applied: `66 passed, 0 failed`. The full
upstream `.claude/tests/gates.test.sh` with the prototype applied: `507
passed, 0 failed`, so no existing pin moves.

### Why one story, not two

The two fixes edit the same loop in the same file (lines 338-681 of
`gates.sh`), and the accounting's "reached" record sits two lines under the
`field 2 "$line" id` the stdin fix's loop reads. Two stories would collide on
every line (`story-authoring`, Sizing, second axis) and together they are one
RED→GREEN cycle: the tests exist downstream and are adapted; GREEN is about 25
lines in `gates.sh` and one token in `doctor.sh`.

### Which required gate would fail if this broke

None in `project.conf`, as for every harness story: the harness has no gate
over itself. The regression tests live in `.claude/tests/gates.test.sh` and
`.claude/tests/doctor.test.sh`, which CI runs through `bash
scripts/selftest.sh` as a blocking step. The invariant also runs on every CI
job, because CI runs `bash scripts/gates.sh` in full against the real
manifest; a false refusal there blocks every PR, which is why AC-11 exists.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

**Definitions used by every criterion.** All fixtures come from
`make_project_fixture` / `write_conf` (`.claude/tests/_lib.sh`); every gate
command is a `printf`/`cat`/`wc`/`exit` one-liner. "Runs" means the gate's
`=== gate: <id>` banner appears and its outcome line appears under
`--- gate summary ---`. Runs are made with stdin at end-of-input and
descriptors 3-9 closed (`</dev/null 3<&- ... 9<&-`) unless the criterion says
otherwise, so that a gate which drains a descriptor can only reach what
`gates.sh` gave it, never the suite's terminal.

- **Declared.** One entry per `gate` line in `project.conf`, per line, read
  before any gate command runs. Applies to runs that execute gates, not to
  `--list` or `--audit`.
- **Accounted for.** A declared entry whose line the run loop reached, whatever
  it then did with it: ran it, reported it `UNCONFIGURED`, refused it as a
  manifest error, left it out by `--fast`, or filtered it by `--gate`/`--required`.
- **Lost.** A declared entry not accounted for, whether required or optional,
  and whether or not a filter would have excluded it.
- **Refusal.** For each lost gate, in manifest order, the summary line
  `FAIL         <id> (declared in project.conf but never accounted for)` (13-column
  prefix like every summary line), then, after the summary, the line
  `<N> declared gate(s) never accounted for; this run certifies nothing.` The
  run exits 1, does not print `All required gates passed`,
  `.claude/state/last-gate-run` says `RESULT=fail`, and a full `--story` run
  records `result: fail` in the story.

### Defect 1: the gate loop's stdin

- **AC-1** — *The reported bug, as its permanent regression test.* Given a
  manifest whose first required gate reads all of its stdin
  (`cat >/dev/null; printf 'Tests 1 passed\n'`, evidence `Tests [1-9][0-9]* passed`),
  when a full run executes, then:
  (a) if the second required gate prints `Tests 2 passed` and exits 0, both
  gates run, both are `PASS` in the summary, the run reads
  `All required gates passed (2 ran, 0 unconfigured, 0 known).` and exits 0;
  (b) if the second required gate is `exit 1`, the summary holds
  `FAIL         later (<n>s, exit 1) -> .claude/state/gate-logs/later.log`,
  the run prints `1 required gate(s) failed.`, does not print `All required
  gates passed`, and exits 1.
  *Control (measured, release 93):* (a) prints `(1 ran, ...)` with no `later`
  banner; (b) exits 0 and certifies the run. Red on arrival.
- **AC-2** — *A gate cannot reach the manifest through any inherited
  descriptor.* Given a first required gate that drains fd 0 and every fd 3 to 9
  (`for fd in 0 3 4 5 6 7 8 9; do cat <&$fd >/dev/null; done 2>/dev/null;
  printf 'Tests 1 passed\n'`) followed by a required `exit 1` gate, when a full
  run executes, then the second gate runs and is reported `FAIL ... exit 1`,
  the run prints `1 required gate(s) failed.` and exits 1.
  *Why:* the obvious fix, reading the manifest on fd 3, passes AC-1 and
  relocates the defect; downstream measured it. This criterion rejects it.
  *Control (measured, release 93):* `later` absent, exit 0.
- **AC-3** — *A gate reads end-of-input, not the manifest and not the caller's
  stdin.* Given a required gate `printf 'stdin-bytes=%s\n' "$(wc -c | tr -d ' ')"`
  followed by one more gate, when `gates.sh` is run with data piped into it
  (`printf 'CALLER-DATA\n' | bash scripts/gates.sh`, descriptors 3-9 left as
  the suite has them), then the run reaches `--- gate summary ---` and the first
  gate's log (`.claude/state/gate-logs/count.log`) contains `stdin-bytes=0`.
  *Why the pipe:* in a terminal the inherited stdin is the TTY, where a
  stdin-reading gate blocks forever; a finite pipe makes that fail instead of
  hang. *Control (measured, release 93):* `stdin-bytes=57`, the byte length of
  the rest of the manifest.
- **AC-4** — *`--fast` and `--required` give the same guarantee as a full
  run.* Given the AC-1(b) manifest plus a required `slow_one`
  (`printf 'Tests 3 passed\n'`) with a `slow` line, when `--fast` runs, then
  `later` is reported `FAIL ... exit 1`, `--fast skipped: slow_one` is printed,
  `1 required gate(s) failed.` is printed and it exits 1. Given the AC-1(b)
  manifest, when `--required` runs, the same `FAIL`, count line and exit 1.
  *Control (measured, release 93):* both exit 0; `--fast` never prints the skip
  line because the `slow_one` line was eaten too.
- **AC-5** — *`doctor.sh`'s discovery loop has the same defect, and the same
  fix.* Given `discovery | eats | . | cat >/dev/null; true` followed by
  `discovery | later | . | false`, when `bash scripts/doctor.sh` runs from the
  fixture with stdin at end-of-input, then the output contains
  `MISSING  later` and doctor exits 1.
  *Control (measured at PLANNED, release 94 tree):* `ok       eats
  discovered`, no `later` line, exit 0.

### Defect 2: the run accounts for every declared gate

- **AC-6** — *The reproduction: a gate that rewrites the manifest in place
  cannot make a later gate vanish from a certified run.* Given
  ```
  gate | first | required | . | printf 'BOOTSTRAPPED=yes\n' > .claude/harness/project.conf; printf 'Tests 1 passed\n'
  gate | later | required | . | printf 'Tests 2 passed\n'
  ```
  when a full run executes, then **either** `later` runs (banner, `PASS
  later`, `(2 ran, 0 unconfigured, 0 known)`, exit 0) **or** the run refuses
  and names `later` with the refusal line, exit 1. In no case does it print
  `All required gates passed` with `later` absent from the output. With `later`
  changed to `exit 1`: exit 1, and the summary has a line beginning
  `FAIL         later (` - the gate's own or the refusal - and no `All required
  gates passed`.
  *Why a disjunction:* the product claim is "never a false certification", not
  a mechanism; snapshotting the manifest would also satisfy it.
  *Control (measured, release 93):* today's `cksum` check already turns this
  into `FAIL config: ... changed while the gates were running`, exit 1, but
  `later` is named nowhere - the first case passes on arrival only if the
  refusal names `later`, so it is red on arrival; the second case's `FAIL
  later (` line is red on arrival.
- **AC-7** — *The fault-injection seam loses exactly what it names, and says
  so before any gate runs.* Given three required gates `a`, `b`, `c`, each
  `printf 'Tests 1 passed\n'`, when a full run executes with
  `GATES_FAULT_LOSE='b'` in the environment, then no `=== gate: b (` banner
  appears, `a` and `c` run, and a line beginning `note: GATES_FAULT_LOSE is set`
  that names `b` is printed before the first `=== gate:` banner. With
  `GATES_FAULT_LOSE='a c'`, neither `a` nor `c` has a banner and `b` runs.
  *Why a seam ships:* after Defect 1 is fixed and the `cksum` check exists, no
  deterministic real loss remains for the invariant's tests to be red against;
  the seam is a loss that survives every future rewrite of the loop. It can
  only make a run fail (AC-8), announces itself, and reads nothing CI sets.
  *Control (measured, release 93):* the variable is ignored, all three banners
  appear.
- **AC-8** — *A lost gate refuses the run.* Given the AC-7 manifest:
  (a) with `GATES_FAULT_LOSE='b'`: the refusal line for `b`, the line
  `1 declared gate(s) never accounted for; this run certifies nothing.`, no
  `All required gates passed`, exit 1;
  (b) with `GATES_FAULT_LOSE='a c'`: refusal lines for `a` then `c` in that
  order, `2 declared gate(s) ...`, exit 1;
  (c) with `b` changed to `optional` and `GATES_FAULT_LOSE='b'`: the same
  refusal and count, no `WARN         b`, exit 1. A lost optional gate is not a
  warning: losing it means the runner is broken.
  *Control (measured, release 93):* all three run, exit 0. This is red for the
  seam's absence, not the invariant's; DV-2 earns the invariant after GREEN.
- **AC-9** — *The refusal reaches the story record and the stamp.* Given the
  AC-7 manifest, a fixture story `T-47` at phase GATES on branch
  `story/T-47-fixture` with the fixture tree staged (`git add -A`; upstream
  refuses to record off the story branch or with an untracked gated file), and
  `GATES_FAULT_LOSE='b'`, when `gates.sh --story T-47` runs in full, then the
  story's `## Gate results` block has a line matching `^ *result: fail`, its
  summary lines include the refusal line for `b` (indented four spaces), and
  `.claude/state/last-gate-run` contains the line `RESULT=fail`.
  *Control (measured, release 93):* `result: pass (3 ran, ...)`, `RESULT=pass`.
- **AC-10** — *The subsets refuse a lost gate and never blame one they
  excluded.* Given the AC-7 manifest plus a required `s` with a `slow` line and
  an optional `o`, each `printf 'Tests 1 passed\n'`, with `GATES_FAULT_LOSE='b'`:
  (a) `--fast`: `b` refused, `--fast skipped: s` printed, no refusal names `s`,
  `1 declared gate(s) ...`, exit 1;
  (b) `--required`: `b` refused, no refusal names `o`, count 1, exit 1;
  (c) `--gate b`: `b` refused, no `no gate named` error (it is declared), count
  1, exit 1 not 2;
  (d) `--gate a`: `b` is still refused, count 1, exit 1 - a lost line was never
  reached to be excluded, so a filter that would have excluded it does not
  excuse it.
  *Control (measured, release 93):* all four exit 0.
- **AC-11** — *No false refusal: every disposition counts as accounted for.*
  These are the negative controls on the invariant, and they pass on arrival.
  Two manifests, outputs pinned whole (every status line, the `--fast` skip
  line and the verdict, timings masked to `(Ns`), which must stay byte-for-byte
  what they are on release 94, with no line containing `never accounted for`:
  - *Healthy* (`a` required with evidence; `k` optional `exit 1` with a waiver;
    `w` optional `exit 1`; `u` optional with no command; `s` required with
    evidence and a `slow` line), under full, `--fast`, `--required`, `--gate w`
    and `--gate u`. Full run:
    ```
    PASS         a (Ns, observed 3)
    KNOWN        k (Ns, exit 1; fixture: known red) -> .claude/state/gate-logs/k.log
    WARN         w (Ns, exit 1, optional) -> .claude/state/gate-logs/w.log
    UNCONFIGURED u
    PASS         s (Ns, observed 2)
    All required gates passed (4 ran, 1 unconfigured, 1 known).
    ```
    exit 0; `--fast` the same minus `s`, plus `--fast skipped: s` and `(3 ran,
    ...)`; `--required` only `a` and `s`, `(2 ran, 0 unconfigured, 0 known)`;
    `--gate w` only the `WARN` line and `(1 ran, ...)`; `--gate u` only
    `UNCONFIGURED u` and `(0 ran, 1 unconfigured, 0 known)`.
  - *Manifest errors*, one gate per refusal that happens before a gate runs
    (`slow` with no reason; `floor | e_floor | abc`; `ci-factor | e_cif | 3.4`;
    a waiver on a required gate; a required gate with no command) plus one that
    runs:
    ```
    FAIL         e_slow (marked slow with no reason in project.conf)
    FAIL         e_floor (floor 'abc' is not a number)
    FAIL         e_cif (ci-factor has no source; say which CI run it was measured from)
    FAIL         e_waive (has a waiver but is required; waivers are for optional gates only)
    FAIL         e_nocmd (required gate has no command in project.conf)
    PASS         ok (Ns, observed 1)
    5 required gate(s) failed.
    ```
    exit 1. (Downstream's `e_nocnt`/`no-count` row is dropped: upstream has no
    `no-count` line; that is HARNESS-055.)
  *Control:* these earn their red under DV-2's mutation variants, which make
  the invariant forget one disposition at a time; GATES records which.

## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. -->

**Writes:** `scripts/gates.sh`, `scripts/doctor.sh`, `.claude/tests/gates.test.sh`, `.claude/tests/doctor.test.sh`, `.claude/tests/sigpipe.test.sh`

### C-1: the stdin fix, one token per loop

`scripts/gates.sh` line 560 becomes

```bash
  ( cd "$ROOT/$cwd" && eval "$cmd" ) </dev/null 2>&1 | tee "$log"
```

`scripts/doctor.sh` line 268 becomes

```bash
  if ( set +o pipefail; cd "$ROOT/$cwd" 2>/dev/null && eval "$cmd" ) </dev/null >/dev/null 2>&1; then
```

The redirect goes on the subshell, not inside `eval`, so it covers every
command the gate line runs. `gates.sh` opens no descriptor in 3-9 for a gate to
inherit, which is why AC-2 holds with no further change; RED may amend this
block if it finds one.

### C-2: the accounting (the "reach-based" variant, chosen)

Before the run loop, after `fails=0; warns=0; ...` (line 338), the seam and
the record:

```bash
# Every gate line the loop REACHES is recorded here, before any filter or
# refusal can `continue` past it; after the loop the list is compared with
# GATE_IDS, read at parse time before any gate ran. A declared gate the loop
# never reached (a gate drained or truncated the manifest under it) refuses the
# run by name. GATES_FAULT_LOSE is the test seam: the gate lines it names are
# treated as never read. It can only make a run fail, and says so up front.
reached=""; fault_lose=""
if [ -n "${GATES_FAULT_LOSE:-}" ] && [ "$LIST" = 0 ] && [ "$AUDIT" = 0 ]; then
  fault_lose=" $GATES_FAULT_LOSE "
  printf 'note: GATES_FAULT_LOSE is set; this run will lose: %s\n' "$GATES_FAULT_LOSE"
fi
```

In the loop, immediately after `field 2 "$line" id` (line 349) and before
`field 3 "$line" req`:

```bash
  case "$fault_lose" in *" $id "*) continue ;; esac
  reached="$reached $id"
```

After the loop, immediately before `CONF_CHANGED=0` (line 848), so the refusal
lands inside the summary block and the exit status, stamp and count line follow
from the existing `fails` path:

```bash
# Declared against reached, per line and in manifest order: each reached entry
# pays off one declared one. What is left was never read, so this run can say
# nothing about it, and a run that cannot account for its manifest certifies
# nothing - required or optional, filtered or not.
lost=0; unpaid=" $reached "
set -f
for d in $GATE_IDS; do
  case "$unpaid" in
    *" $d "*) unpaid="${unpaid/" $d "/ }" ;;
    *) results="$results\nFAIL         $d (declared in project.conf but never accounted for)"; lost=$((lost+1)); fails=$((fails+1)) ;;
  esac
done
set +f
```

And before the existing `if [ "$fails" -gt 0 ]; then printf '\n%d required
gate(s) failed.\n'` (line 1009):

```bash
if [ "$lost" -gt 0 ]; then
  printf '\n%d declared gate(s) never accounted for; this run certifies nothing.\n' "$lost"
fi
```

Semantics behind each piece:

- **Per line, not per unique id.** `GATE_IDS` holds one entry per `gate`
  line; `reached` holds one per line reached; each reached entry pays off one
  declared one (`${unpaid/" $d "/ }` removes one occurrence). A manifest that
  declares `unit` twice and reaches it once is one lost gate.
- **`set -f` around the word split** so a gate id containing a glob character
  cannot expand against the working directory.
- **Lost gates count into `fails`.** So the existing paths produce `RESULT=fail`,
  `result: fail (N required gate(s) failed)` in the record, the `N required
  gate(s) failed.` line and exit 1 with no new branch. The count line is
  additional and comes before it. This is the prototype's shape, measured
  `507 passed, 0 failed` on the full upstream suite. Downstream instead reports
  `result: fail (N declared gate(s) never accounted for, M required gate(s)
  failed)` and exits 1 on `lost` separately; RED may amend to that shape with a
  reason, and AC-9 is satisfied by either.
- **The seam is consulted in every mode that runs a gate command**, `--fast`,
  `--required` and `--gate` included, and in neither `--list` nor `--audit`,
  which execute nothing and have exited before the comparison.
- **`--gate <typo>` still exits 2** before the loop (line 208); `--gate b`
  with `b` lost exits 1 because `b` is in `GATE_IDS`.

**Why reach-based rather than downstream's per-disposition recording.**
Downstream records `accounted` at each of eight sites that dispose of a line
(ran, unconfigured, five manifest-error refusals, `--fast` skip, two filters).
Reach-based records once, at the top of the loop body. The reported class, and
every cause anyone has found - stdin drain, descriptor drain, in-place
truncation, the seam - loses a line by *never reaching it*, and reach-based
catches all of those. What it cannot catch is a line that is reached and then
dropped without any disposition, which would be a `continue` added to the loop
with no summary line: a defect in `gates.sh`'s own code rather than in a gate
command, and one that AC-11's whole-summary pins would show as a missing line
in any case. Eight sites is eight places for the next edit to the loop to
forget one and cause a false refusal on every CI job; one site cannot be
forgotten. The tests are behavioural, so if a later story wants per-disposition
recording it can replace C-2 without touching them.

### C-3: the sigpipe pins move with the source

`.claude/tests/sigpipe.test.sh` line 568 pins
`scripts/gates.sh:580:why="could not launch: $(` and its C-5 freshness
assertion fails as "stale" when the line no longer holds that text. C-2 inserts
11 lines before the loop and 2 inside it, all above line 580, and C-1 inserts
none, so after GREEN that line is **593**. The `:74` pin for `gates.sh` and
the `:68`/`:140` pins for `doctor.sh` are above every insertion and do not
move.

RED updates line 568 to `scripts/gates.sh:593:why="could not launch: $(` and
watches `C-5 freshness: all twelve status-discarded lines are still where this
suite says they are` go red against the unchanged source, which is this test's
honest red. GREEN then lands the blocks exactly as C-2 gives them so that the
line is 593. If GREEN cannot land on 593 for a reason it records, it does not
touch the test file: it returns to RED for the one-line pin change under
`## Regressions`, which is the route `rules.md` gives for a gate failure whose
only fix is a test-file write. The comment-only references `gates.sh:432` and
`gates.sh:428` in that file are prose, already drifted, and not this story's.

### C-4: the tests

Port the adapted downstream suites into the existing files rather than as new
suites, so `selftest.sh` picks them up with no wiring:

- AC-1 to AC-4 and AC-6 to AC-11 go into `.claude/tests/gates.test.sh` as new
  `describe` blocks, using the existing `gates()` runner plus a `gates_isolated`
  variant (`</dev/null 3<&- 4<&- 5<&- 6<&- 7<&- 8<&- 9<&-`) and a `seam <ids>
  [args]` runner that sets `GATES_FAULT_LOSE` for that one process. `unset
  GATES_FAULT_LOSE` at the top of the block so a caller's environment cannot
  leak into AC-11. The adapted sources are reproduced verbatim under `## Notes`
  (the scratch directory they came from is deleted); RED may restructure them
  but keeps every assertion.
- AC-5 goes into `.claude/tests/doctor.test.sh`, using its `run_doctor` (which
  sets `out` and `rc`); assert on `rc` as well as the text, for the reason that
  file's header gives.
- Needles: the refusal line is asserted as a **whole line** (`grep -Fxq`), not a
  substring, so a refusal naming `ab` cannot pass for `b`; "not certified" is
  asserted as the absence of `All required gates passed` **together with** the
  presence of the refusal and exit 1, never the absence alone.

### Oracle partition

- **Mechanical** (pin exactly, nothing open-ended): AC-1 to AC-10. Every
  expected string is given above and was measured on release 93 or at PLANNED.
- **Settled** (read the numbers out, do not re-derive): AC-11's two pinned
  summaries, measured on release 93 and unchanged on 94. If RED measures a
  different healthy summary on the current tree, that is a finding to report,
  not a number to adjust.
- **Oracle-free:** none.

### Callers of a changed signature

No exported signature changes. `GATES_FAULT_LOSE` is a new environment
variable read only by `gates.sh`; nothing in the tree sets it
(`rg GATES_FAULT_LOSE` at PLANNED: no matches).

### Test-only dependencies

None. bash, git and coreutils, as for every harness suite.

## Deferred verifications

<!-- One block per entry; the owning phase pastes the result. -->

**DV-1 (defect put back, central claim of Defect 1). Owner: GATES.** With
`</dev/null` removed from the gate subshell in `scripts/gates.sh` and the
accounting left in place, AC-1 to AC-4 **must** go red - and go red as a
*refusal* of `later`, not as a certification, which is what makes Defect 2
independent of Defect 1. Predicted from the triage's `mc046-nodn.out` (the same
mutation applied to the prototype): exactly these 11 assertions red,
everything else green:

```
    FAIL the gate after a stdin-reading gate still runs
    FAIL and so does the gate after it
    FAIL and both are counted as having run
    FAIL a run of two passing gates exits 0
    FAIL a failing required gate after a stdin-reading gate is reported FAIL
    FAIL a gate after one that drains fds 0 and 3-9 still runs and is reported FAIL
    FAIL a gate reads zero bytes of stdin, whatever gates.sh was given
    FAIL --fast: a failing gate after a stdin-reading gate is reported FAIL
    FAIL --fast: the slow gate after them is still seen, and skipped
    FAIL --fast: the run says a required gate failed
    FAIL --required: a failing gate after a stdin-reading gate is reported FAIL
```

RED cannot run it: there is no fix to remove. Run as
`bash scripts/mutate.sh scripts/gates.sh 's|) </dev/null 2>&1 \| tee "$log"|) 2>\&1 \| tee "$log"|' -- bash .claude/tests/gates.test.sh`
and paste the FAIL lines and the summary count, then the green re-run.

**DV-2 (defect put back, central claim of Defect 2). Owner: GATES.** With the
refusal disabled and the seam kept - mutate `for d in $GATE_IDS; do` to
`for d in ; do` - AC-7 stays green (the seam still loses `b`), and every
assertion in AC-6, AC-8, AC-9 and AC-10 that names a refusal line, the count
line, `RESULT=fail`/`result: fail`, exit 1 or the absence of `All required
gates passed` **must** go red; AC-6's first case must classify as
`false-cert`. RED cannot run it: there is no invariant to disable. Paste the
FAIL lines, the count, and the green re-run. Then one variant for AC-11's
controls: mutate `reached="$reached $id"` to `reached="$reached"` (the
invariant forgets every disposition) and confirm every AC-11 row goes red with
a `never accounted for` line; paste the count.

**DV-3 (defect put back, AC-5). Owner: GATES.** With `</dev/null` removed from
`scripts/doctor.sh` line 268, AC-5 **must** go red: `ok       eats
discovered`, no `MISSING  later`, exit 0. Run through `mutate.sh` against
`bash .claude/tests/doctor.test.sh` only; paste the red and the green re-run.

**DV-4 (the pin). Owner: GATES.** `bash .claude/tests/sigpipe.test.sh` is
green on the committed tree, with `C-5 freshness: all twelve status-discarded
lines are still where this suite says they are` passing and line 593 of
`gates.sh` holding `why="could not launch: $(`. RED records the same assertion
red against the unchanged source (C-3). Paste `sed -n 593p scripts/gates.sh`
and the suite's summary line.

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

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-052` from `.claude/harness/models.conf`.
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

- **`no-count` lines** (`FAIL ... (marked no-count with no reason ...)`,
  downstream's `e_nocnt` row). Upstream has no such line; that is
  HARNESS-055. The AC-11 manifest-errors fixture drops that row.
- **`table_get`** (downstream MC-045's fork-free table lookup, present in the
  triage prototype diff). That is HARNESS-057; this story keeps
  `table_lookup` and does not touch any lookup site.
- **The order of the record's lines** - where the refusal sits relative to
  the `FAIL config:` line when both fire (AC-6). Either order satisfies AC-6.
- **A gate that `rm`s the manifest, or rewrites it atomically.** An atomic
  rewrite (`> tmp && mv`) loses nothing, because the loop keeps the old inode;
  `rm` ends the loop and is refused by the same invariant. Neither gets its
  own test here.
- **A reached-then-dropped line** (C-2, the one class reach-based recording
  cannot see). If a later story adds a `continue` to the loop with no summary
  line, AC-11's pins are what catch it. Per-disposition recording is a
  follow-up, not this story.
- **The trailing-newline-drop bug** noted during the triage (a last manifest
  line with no `\n` is never read by `read -r`; `nonl.sh` in the scratch
  directory). A separate story; it affects declared and reached alike, so the
  invariant neither catches nor is confused by it.
- **The stale prose comments** `gates.sh:432` and `gates.sh:428` in
  `sigpipe.test.sh`, which are not pins.
- **`doctor.sh`'s other `done < "$CONF"` loop** at line 158, which parses and
  evals nothing.
- Any change to what `--list` or `--audit` print.

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

## Handoff: RED -> GREEN

<!-- Filled by the Test Developer at the end of RED. This is the ONLY channel
     to the Feature Developer, whose context is fresh. Must contain:
       * the exact command that runs the new tests
       * the failure output, and why it is the RIGHT failure
       * every file touched, and which AC each test covers
       * the EXPORT SHAPE the tests already pin
       * any test that passed on arrival, and the probe or negative control
         that earns it
       * the EXPECTED VALUE of every negative control, as a table
       * anything discovered that changes the approach -->

## Gate results

<!-- Written by scripts/gates.sh itself on every full run, stamped with the
     commit and a hash of the code it ran against. Do not paste or edit it:
     check-boundaries.sh refuses a PR whose recorded run does not match the
     code being merged. -->

## Notes

### Provenance

- Downstream commits: `git -C D:/manhwa-cropper show a60eb69` (MC-046) and
  `git -C D:/manhwa-cropper show b440b59` (MC-047); story files
  `D:/manhwa-cropper/docs/backlog/stories/MC-046.md` and `MC-047.md`. MC-047's
  Context carries the full argument for the seam (three options, why the
  seam) and its `## Notes` the open questions the user settled; read it before
  re-litigating either.
- Triage 2026-10-11, against upstream release 93 (identical to 94 in these
  files), in a session scratch directory that no longer exists. What the next
  agent needs from it is below, verbatim.
- `rg GATES_FAULT_LOSE` and `rg 'never accounted for'` on the upstream tree
  at PLANNED: no matches outside this story.

### The adapted downstream suites, verbatim

Both ran green (22/22, 66/66) on upstream release 93 with the prototype of
C-1 and C-2 applied, and red as the Context records without it. They assume
`_lib.sh`'s `make_project_fixture`, `write_conf`, `story`, `describe`,
`assert_eq`, `assert_contains`, `_ok`, `_bad`, `summary`. The `# adapted:`
comments mark the three lines that differ from downstream.

`mc046.test.sh` (AC-1 to AC-4):

```bash
gates_isolated() {
  ( cd "$FIX" && bash scripts/gates.sh "$@" 2>&1 ) </dev/null 3<&- 4<&- 5<&- 6<&- 7<&- 8<&- 9<&-
}

# assert_gate_failed <what> <id> <output>   The summary line for a required gate
# that exited 1, by id: `FAIL         <id> (<n>s, exit 1) -> <its log>`. The
# duration is the one field not pinned.
assert_gate_failed() {
  case "$3" in
    *"FAIL         $2 ("*"s, exit 1) -> .claude/state/gate-logs/$2.log"*) _ok "$1" ;;
    *) _bad "$1" "expected a summary line: FAIL         $2 (<n>s, exit 1) -> .claude/state/gate-logs/$2.log
actual:   $3" ;;
  esac
}

# assert_lacks <what> <needle> <haystack>
assert_lacks() {
  case "$3" in
    *"$2"*) _bad "$1" "expected NOT to contain: $2
actual:                   $3" ;;
    *) _ok "$1" ;;
  esac
}

describe "a gate that reads its stdin cannot delete the gates after it"

# AC-1(a): the reported bug. Today: `later` is absent, "(1 ran, ...)", exit 0.
write_conf "$FIX" <<'EOF'
gate     | eats  | required | . | cat >/dev/null; printf 'Tests 1 passed\n'
gate     | later | required | . | printf 'Tests 2 passed\n'
evidence | eats  | Tests [1-9][0-9]* passed
evidence | later | Tests [1-9][0-9]* passed
EOF
out="$(gates_isolated)"; rc=$?
assert_contains "the gate after a stdin-reading gate still runs" "=== gate: later (required) ===" "$out"
assert_contains "the stdin-reading gate passes"          "PASS         eats (" "$out"
assert_contains "and so does the gate after it"          "PASS         later (" "$out"
assert_contains "and both are counted as having run" \
  "All required gates passed (2 ran, 0 unconfigured, 0 known)." "$out"
assert_eq "a run of two passing gates exits 0" "0" "$rc"

# AC-1(b): worse than reported. Today: exit 0, "All required gates passed".
AC1B_CONF="gate     | eats  | required | . | cat >/dev/null; printf 'Tests 1 passed\n'
gate     | later | required | . | exit 1
evidence | eats  | Tests [1-9][0-9]* passed"
printf '%s\n' "$AC1B_CONF" | write_conf "$FIX"
out="$(gates_isolated)"; rc=$?
assert_gate_failed "a failing required gate after a stdin-reading gate is reported FAIL" later "$out"
assert_contains "and the run says a required gate failed" "1 required gate(s) failed." "$out"
assert_lacks "and does not certify the run" "All required gates passed" "$out"
assert_eq "and exits 1" "1" "$rc"

describe "a gate cannot reach the manifest through any inherited descriptor"

# AC-2. The obvious fix - read the manifest on fd 3 instead of fd 0 - passes
# AC-1 and relocates the defect: the eval'd command inherits fd 3 and a gate
# that reads it drains the manifest exactly as before. This gate reads 0 and
# every descriptor 3 to 9 an ordinary command can reach by accident.
write_conf "$FIX" <<'EOF'
gate     | eats  | required | . | for fd in 0 3 4 5 6 7 8 9; do cat <&$fd >/dev/null; done 2>/dev/null; printf 'Tests 1 passed\n'
gate     | later | required | . | exit 1
evidence | eats  | Tests [1-9][0-9]* passed
EOF
out="$(gates_isolated)"; rc=$?
assert_gate_failed "a gate after one that drains fds 0 and 3-9 still runs and is reported FAIL" later "$out"
assert_contains "and the run says a required gate failed" "1 required gate(s) failed." "$out"
assert_lacks "and does not certify the run" "All required gates passed" "$out"
assert_eq "and exits 1" "1" "$rc"

describe "a gate reads end-of-input, not the manifest and not the caller's stdin"

# AC-3. Today the gate reads the rest of the manifest. Under the fd-3-only fix
# it reads whatever gates.sh was given - here a pipe, in a terminal the TTY,
# where it would block forever. The pipe is finite, so this test cannot block
# whichever of those it meets; it fails instead.
write_conf "$FIX" <<'EOF'
gate  | count | required | . | printf 'stdin-bytes=%s\n' "$(wc -c | tr -d ' ')"
gate  | after | required | . | printf 'Tests 2 passed\n'
EOF
rm -f "$FIX/.claude/state/gate-logs/count.log"
out="$(printf 'CALLER-DATA\n' | ( cd "$FIX" && bash scripts/gates.sh 2>&1 ))"
assert_contains "a run given data on stdin still finishes" "--- gate summary ---" "$out"
seen="$(grep '^stdin-bytes=' "$FIX/.claude/state/gate-logs/count.log" 2>/dev/null)"
assert_eq "a gate reads zero bytes of stdin, whatever gates.sh was given" "stdin-bytes=0" "$seen"

describe "--fast and --required give the same guarantee as a full run"

# AC-4. The subsets run the same loop. (--gate <id> is deliberately absent: a
# filtered-out gate hits `continue` before anything runs, so it has no defect.)
printf '%s\n%s\n%s\n' "$AC1B_CONF" \
  "gate     | slow_one | required | . | printf 'Tests 3 passed\n'" \
  "slow     | slow_one | stands in for a release build; RED has no use for it" \
  | write_conf "$FIX"
out="$(gates_isolated --fast)"; rc=$?
assert_gate_failed "--fast: a failing gate after a stdin-reading gate is reported FAIL" later "$out"
assert_contains "--fast: the slow gate after them is still seen, and skipped" "--fast skipped: slow_one" "$out"
assert_contains "--fast: the run says a required gate failed" "1 required gate(s) failed." "$out"
assert_eq "--fast: and exits 1" "1" "$rc"

printf '%s\n' "$AC1B_CONF" | write_conf "$FIX"
out="$(gates_isolated --required)"; rc=$?
assert_gate_failed "--required: a failing gate after a stdin-reading gate is reported FAIL" later "$out"
assert_contains "--required: the run says a required gate failed" "1 required gate(s) failed." "$out"
assert_eq "--required: and exits 1" "1" "$rc"
```

`mc047.test.sh` (AC-6 to AC-11):

```bash
# The seam is set per call and never exported, so no later block inherits it.
# It is unset here as well, so that a caller's environment cannot leak into the
# no-false-refusal controls at the end.
unset GATES_FAULT_LOSE

# seam <ids> [gates.sh args...]   A run with GATES_FAULT_LOSE set for that one
# process only.
seam() {
  local lose="$1"; shift
  ( cd "$FIX" && GATES_FAULT_LOSE="$lose" bash scripts/gates.sh "$@" 2>&1 ) </dev/null
}

# assert_line <what> <line> <output>   <line> is a WHOLE line of <output>, not a
# substring of one: a refusal naming `ab` must not pass for `b`.
assert_line() {
  if printf '%s\n' "$3" | grep -Fxq -- "$2"; then _ok "$1"
  else _bad "$1" "expected a line exactly: $2
actual:   $3"; fi
}

# assert_no_line <what> <line> <output>
assert_no_line() {
  if printf '%s\n' "$3" | grep -Fxq -- "$2"; then _bad "$1" "expected NO line: $2
actual:   $3"
  else _ok "$1"; fi
}

# first_line_no <prefix> <output>   The number of the first line that starts
# with <prefix>, compared literally; empty when there is none.
first_line_no() {
  printf '%s\n' "$2" | awk -v p="$1" 'index($0, p) == 1 { print NR; exit }'
}

# refusal <id>   The summary line for a lost gate, 13-column prefix and all.
refusal() { printf 'FAIL         %s (declared in project.conf but never accounted for)' "$1"; }

# lost_count <n>   The line under the summary that counts them.
lost_count() { printf '%s declared gate(s) never accounted for; this run certifies nothing.' "$1"; }

describe "a gate that rewrites project.conf in place cannot make a later gate vanish from a certified run"

# AC-6. `first` reads no stdin: it truncates the manifest by path. The loop
# streams project.conf from an open descriptor, so its next read lands past the
# new end of file and `later` is never reached.
#
# ac1_outcome <output> <exit>   Classifies a run as exactly one of:
#   ran        `later` ran and passed, and both gates were counted, exit 0
#   refused    the refusal line names `later`, no pass line, exit 1
#   false-cert "All required gates passed" and `later` absent: the defect
#   other      anything else, which is not an acceptable outcome either
ac1_outcome() {
  if [ "$2" = 0 ] \
     && printf '%s\n' "$1" | grep -Fxq '=== gate: later (required) ===' \
     && printf '%s\n' "$1" | grep -q '^PASS         later (' \
     && printf '%s\n' "$1" | grep -Fxq 'All required gates passed (2 ran, 0 unconfigured, 0 known).'; then
    printf 'ran'
  elif [ "$2" = 1 ] \
     && printf '%s\n' "$1" | grep -Fxq -- "$(refusal later)" \
     && ! printf '%s\n' "$1" | grep -Fq 'All required gates passed'; then
    printf 'refused'
  elif printf '%s\n' "$1" | grep -Fq 'All required gates passed' \
     && ! printf '%s\n' "$1" | grep -Fq 'later'; then
    printf 'false-cert'
  else
    printf 'other'
  fi
}

# Each case writes the manifest afresh: the first gate destroys it.
write_conf "$FIX" <<'EOF'
gate | first | required | . | printf 'BOOTSTRAPPED=yes\n' > .claude/harness/project.conf; printf 'Tests 1 passed\n'
gate | later | required | . | printf 'Tests 2 passed\n'
EOF
out="$(gates_isolated)"; rc=$?
outcome="$(ac1_outcome "$out" "$rc")"
case "$outcome" in
  ran|refused) _ok "the gate after an in-place rewrite of project.conf either runs or is refused by name" ;;
  *) _bad "the gate after an in-place rewrite of project.conf either runs or is refused by name" \
       "outcome: $outcome (exit $rc); wanted 'ran' or 'refused'
$out" ;;
esac
case "$outcome" in
  false-cert) _bad "and the run never certifies itself with that gate absent from the output" \
       "certified a pass (exit $rc) without mentioning 'later':
$out" ;;
  *) _ok "and the run never certifies itself with that gate absent from the output" ;;
esac

write_conf "$FIX" <<'EOF'
gate | first | required | . | printf 'BOOTSTRAPPED=yes\n' > .claude/harness/project.conf; printf 'Tests 1 passed\n'
gate | later | required | . | exit 1
EOF
out="$(gates_isolated)"; rc=$?
assert_eq "a failing required gate after an in-place rewrite fails the run" "1" "$rc"
if printf '%s\n' "$out" | grep -q '^FAIL         later ('; then
  _ok "and the summary has a FAIL line for it, its own or the refusal"
else
  _bad "and the summary has a FAIL line for it, its own or the refusal" \
    "expected a line starting: FAIL         later (
actual:   $out"
fi
assert_lacks "and the run is not certified" "All required gates passed" "$out"

describe "GATES_FAULT_LOSE loses exactly the gates it names, and says so before any gate runs"

# AC-7. Today the variable is ignored and all three gates run.
SEAM_CONF="gate | a | required | . | printf 'Tests 1 passed\n'
gate | b | required | . | printf 'Tests 1 passed\n'
gate | c | required | . | printf 'Tests 1 passed\n'"

printf '%s\n' "$SEAM_CONF" | write_conf "$FIX"
out_b="$(seam b)"; rc_b=$?
assert_lacks    "a gate the seam names never runs"        "=== gate: b (" "$out_b"
assert_contains "the gate before it still runs"           "=== gate: a (required) ===" "$out_b"
assert_contains "and so does the gate after it"           "=== gate: c (required) ===" "$out_b"

note_no="$(first_line_no 'note: GATES_FAULT_LOSE is set' "$out_b")"
banner_no="$(first_line_no '=== gate:' "$out_b")"
if [ -n "$note_no" ]; then
  _ok "the seam announces itself with a note: GATES_FAULT_LOSE is set line"
  note_line="$(printf '%s\n' "$out_b" | sed -n "${note_no}p")"
  if printf '%s\n' "$note_line" | tr -c 'A-Za-z0-9_.-' '\n' | grep -Fxq b; then
    _ok "and the note names the gate it will lose"
  else
    _bad "and the note names the gate it will lose" "note line does not name 'b': $note_line"
  fi
else
  _bad "the seam announces itself with a note: GATES_FAULT_LOSE is set line" \
    "no line starts 'note: GATES_FAULT_LOSE is set':
$out_b"
  _bad "and the note names the gate it will lose" "there is no note line to name it"
fi
if [ -n "$note_no" ] && [ -n "$banner_no" ] && [ "$note_no" -lt "$banner_no" ]; then
  _ok "and the note comes before the first gate banner"
else
  _bad "and the note comes before the first gate banner" \
    "note at line '${note_no:-none}', first '=== gate:' at line '${banner_no:-none}'"
fi

out_ac="$(seam 'a c')"; rc_ac=$?
assert_lacks    "a seam naming two gates loses the first" "=== gate: a (" "$out_ac"
assert_lacks    "and the second"                          "=== gate: c (" "$out_ac"
assert_contains "and runs the one it does not name"       "=== gate: b (required) ===" "$out_ac"

describe "a lost gate refuses the run"

# AC-8, on the two runs above. Today: all three gates run, exit 0.
assert_line  "(a) a lost gate gets its own refusal line"   "$(refusal b)" "$out_b"
assert_line  "(a) and the refusals are counted"            "$(lost_count 1)" "$out_b"
assert_lacks "(a) and the run is not certified" "All required gates passed" "$out_b"
assert_eq    "(a) and exits 1" "1" "$rc_b"

assert_line  "(b) two lost gates: the first is refused"    "$(refusal a)" "$out_ac"
assert_line  "(b) and the second"                          "$(refusal c)" "$out_ac"
a_no="$(first_line_no "$(refusal a)" "$out_ac")"
c_no="$(first_line_no "$(refusal c)" "$out_ac")"
if [ -n "$a_no" ] && [ -n "$c_no" ] && [ "$a_no" -lt "$c_no" ]; then
  _ok "(b) in manifest order"
else
  _bad "(b) in manifest order" "refusal of a at line '${a_no:-none}', of c at line '${c_no:-none}'"
fi
assert_line  "(b) and both are counted"                    "$(lost_count 2)" "$out_ac"
assert_lacks "(b) and the run is not certified" "All required gates passed" "$out_ac"
assert_eq    "(b) and exits 1" "1" "$rc_ac"

# (c) A lost OPTIONAL gate is not a WARN: losing it means the runner is broken.
printf '%s\n' "$SEAM_CONF" | sed 's/^gate | b | required |/gate | b | optional |/' | write_conf "$FIX"
out="$(seam b)"; rc=$?
assert_line  "(c) a lost optional gate is refused like a required one" "$(refusal b)" "$out"
assert_line  "(c) and counted"                              "$(lost_count 1)" "$out"
assert_lacks "(c) not merely warned about"                  "WARN         b" "$out"
assert_lacks "(c) and the run is not certified" "All required gates passed" "$out"
assert_eq    "(c) and exits 1" "1" "$rc"

describe "the refusal reaches the story record and the stamp"

# AC-9. Today the record reads `result: pass (3 ran, ...)`.
printf '%s\n' "$SEAM_CONF" | write_conf "$FIX"
story "$FIX" T-47 GATES </dev/null
git -C "$FIX" checkout -q -b story/T-47-fixture 2>/dev/null   # adapted: upstream refuses to record off the story branch
git -C "$FIX" add -A 2>/dev/null   # adapted: upstream refuses to record while a gated file is untracked
rm -f "$FIX/.claude/state/last-gate-run"
out="$(seam b --story T-47)"
rec="$(awk '/^## Gate results/ { f = 1; next } f && /^## / { exit } f' "$FIX/docs/backlog/stories/T-47.md")"
if printf '%s\n' "$rec" | grep -Eq '^ *result: fail( |$)'; then
  _ok "a full run that lost a gate records result: fail"
else
  _bad "a full run that lost a gate records result: fail" "## Gate results:
$rec
run output:
$out"
fi
assert_line "and the record carries the refusal line" "    $(refusal b)" "$rec"
assert_line "and the stamp says RESULT=fail" "RESULT=fail" \
  "$(cat "$FIX/.claude/state/last-gate-run" 2>/dev/null)"
git -C "$FIX" checkout -q - 2>/dev/null   # adapted

describe "--fast, --required and --gate refuse a lost gate, and never blame one they excluded"

# AC-10. `s` is slow, `o` optional. A lost line was never reached to be
# excluded, so a filter that would have excluded it does not excuse it.
# Today all four runs exit 0.
printf '%s\n%s\n%s\n%s\n' "$SEAM_CONF" \
  "gate | s | required | . | printf 'Tests 1 passed\n'" \
  "slow | s | fixture: stands in for a release build" \
  "gate | o | optional | . | printf 'Tests 1 passed\n'" > "$FIX/ac5.conf"

write_conf "$FIX" < "$FIX/ac5.conf"
out="$(seam b --fast)"; rc=$?
assert_line    "(a) --fast: the lost gate is refused"            "$(refusal b)" "$out"
assert_line    "(a) --fast: the slow gate is reported skipped"   "--fast skipped: s" "$out"
assert_no_line "(a) --fast: and is not blamed as lost"           "$(refusal s)" "$out"
assert_line    "(a) --fast: exactly one gate is counted lost"    "$(lost_count 1)" "$out"
assert_eq      "(a) --fast: and exits 1" "1" "$rc"

write_conf "$FIX" < "$FIX/ac5.conf"
out="$(seam b --required)"; rc=$?
assert_line    "(b) --required: the lost gate is refused"        "$(refusal b)" "$out"
assert_no_line "(b) --required: the optional gate it left out is not blamed" "$(refusal o)" "$out"
assert_line    "(b) --required: exactly one gate is counted lost" "$(lost_count 1)" "$out"
assert_eq      "(b) --required: and exits 1" "1" "$rc"

write_conf "$FIX" < "$FIX/ac5.conf"
out="$(seam b --gate b)"; rc=$?
assert_line    "(c) --gate b: the lost gate it selected is refused" "$(refusal b)" "$out"
assert_lacks   "(c) --gate b: b is declared, so it is not a typo" "no gate named" "$out"
assert_line    "(c) --gate b: exactly one gate is counted lost"   "$(lost_count 1)" "$out"
assert_eq      "(c) --gate b: and exits 1, not 2" "1" "$rc"

write_conf "$FIX" < "$FIX/ac5.conf"
out="$(seam b --gate a)"; rc=$?
assert_line    "(d) --gate a: a lost gate it did not select is still refused" "$(refusal b)" "$out"
assert_line    "(d) --gate a: exactly one gate is counted lost"   "$(lost_count 1)" "$out"
assert_eq      "(d) --gate a: and exits 1" "1" "$rc"
rm -f "$FIX/ac5.conf"

describe "no false refusal: every disposition counts as accounted for"

# AC-11, the negative controls on the invariant: it runs on every CI job, so a
# false refusal would block every PR. Each summary is pinned whole - every
# status line and the verdict, timings masked - because a healthy run must
# stay byte-for-byte what it is today. These pass on arrival (there is no
# invariant yet); each earns its red after GREEN by a mutation that makes the
# invariant forget one disposition (DV-2).
#
# verdict_of <output>   The status lines, the --fast skip line and the verdict,
# with each `(<n>s` masked to `(Ns`.
verdict_of() {
  printf '%s\n' "$1" | sed -n -E \
    -e '/^(PASS|FAIL|WARN|KNOWN|UNCONFIGURED) /{s/\(([0-9]+)s/(Ns/;p;}' \
    -e '/^--fast skipped/p' \
    -e '/^All required gates passed/p' \
    -e '/^[0-9]+ required gate\(s\) failed\.$/p'
}

HEALTHY_CONF="gate     | a | required | . | printf 'Tests 3 passed\n'
evidence | a | Tests [1-9]
gate     | k | optional | . | exit 1
waiver   | k | fixture: known red
gate     | w | optional | . | exit 1
gate     | u | optional | . |
gate     | s | required | . | printf 'Tests 2 passed\n'
evidence | s | Tests [1-9]
slow     | s | fixture: stands in for a release build"

# ac6_row <label> <expected verdict_of> <expected exit> [gates.sh args...]
ac6_row() {
  local label="$1" want="$2" want_rc="$3" o r
  shift 3
  printf '%s\n' "$HEALTHY_CONF" | write_conf "$FIX"
  o="$( ( cd "$FIX" && bash scripts/gates.sh "$@" 2>&1 ) </dev/null )"; r=$?
  assert_eq    "$label: the summary is exactly what it was" "$want" "$(verdict_of "$o")"
  assert_eq    "$label: and so is the exit code" "$want_rc" "$r"
  assert_lacks "$label: and nothing is called unaccounted for" "never accounted for" "$o"
}

ac6_row "healthy, full run" "PASS         a (Ns, observed 3)
KNOWN        k (Ns, exit 1; fixture: known red) -> .claude/state/gate-logs/k.log
WARN         w (Ns, exit 1, optional) -> .claude/state/gate-logs/w.log
UNCONFIGURED u
PASS         s (Ns, observed 2)
All required gates passed (4 ran, 1 unconfigured, 1 known)." 0

ac6_row "healthy, --fast" "PASS         a (Ns, observed 3)
KNOWN        k (Ns, exit 1; fixture: known red) -> .claude/state/gate-logs/k.log
WARN         w (Ns, exit 1, optional) -> .claude/state/gate-logs/w.log
UNCONFIGURED u
--fast skipped: s
All required gates passed (3 ran, 1 unconfigured, 1 known)." 0 --fast

ac6_row "healthy, --required" "PASS         a (Ns, observed 3)
PASS         s (Ns, observed 2)
All required gates passed (2 ran, 0 unconfigured, 0 known)." 0 --required

ac6_row "healthy, --gate w" "WARN         w (Ns, exit 1, optional) -> .claude/state/gate-logs/w.log
All required gates passed (1 ran, 0 unconfigured, 0 known)." 0 --gate w

ac6_row "healthy, --gate u" "UNCONFIGURED u
All required gates passed (0 ran, 1 unconfigured, 0 known)." 0 --gate u

# One gate per refusal that happens before a gate runs, plus one that runs.
# (Downstream's e_nocnt row is dropped: upstream has no no-count line.)
write_conf "$FIX" <<'EOF'
gate      | e_slow  | required | . | printf 'Tests 1 passed\n'
slow      | e_slow  |
gate      | e_floor | required | . | printf 'Tests 1 passed\n'
evidence  | e_floor | Tests [1-9]
floor     | e_floor | abc
gate      | e_cif   | required | . | printf 'Tests 1 passed\n'
evidence  | e_cif   | Tests [1-9]
ci-factor | e_cif   | 3.4
gate      | e_waive | required | . | printf 'Tests 1 passed\n'
waiver    | e_waive | fixture: a bypass
gate      | e_nocmd | required | . |
gate      | ok      | required | . | printf 'Tests 1 passed\n'
evidence  | ok      | Tests [1-9]
EOF
out="$( ( cd "$FIX" && bash scripts/gates.sh 2>&1 ) </dev/null )"; rc=$?
assert_eq "manifest errors: the summary is exactly what it was" \
"FAIL         e_slow (marked slow with no reason in project.conf)
FAIL         e_floor (floor 'abc' is not a number)
FAIL         e_cif (ci-factor has no source; say which CI run it was measured from)
FAIL         e_waive (has a waiver but is required; waivers are for optional gates only)
FAIL         e_nocmd (required gate has no command in project.conf)
PASS         ok (Ns, observed 1)
5 required gate(s) failed." "$(verdict_of "$out")"
assert_eq    "manifest errors: and so is the exit code" "1" "$rc"
assert_lacks "manifest errors: and nothing is called unaccounted for" "never accounted for" "$out"
```

### Things the next agent should know

- `gates.test.sh` already has 38 `describe` blocks and takes over two minutes
  on this machine; run the new blocks in isolation while iterating (copy them
  under a scratch `_lib.sh` sourcing wrapper, or run the whole file in the
  background), and the whole file once before handing off.
- The triage prototype's full-suite result (`507 passed, 0 failed`) included
  HARNESS-057's `table_get`; the C-2 blocks above are the prototype with that
  part removed, so the count on this story's branch is the same number plus
  the new assertions.
- Lost gates land in `fails`, so with the in-place rewrite (AC-6) a run shows
  both `FAIL config: ... changed while the gates were running` and the
  refusal, and `2 required gate(s) failed.` That is correct and expected.
