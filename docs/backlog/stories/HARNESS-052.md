---
id: HARNESS-052
title: A gate that reads stdin cannot swallow the gates after it, and a run accounts for every declared gate
slug: a-gate-that-reads-stdin-cannot-swallow-t
epic: 
type: fix
status: in-progress
phase: GATES
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

After the loop, before `CONF_CHANGED=0` (line 848), so the refusal
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

*Amended in GREEN (placement only, no code change):* the block sits above the
seven-line comment that documents `CONF_CHANGED` ("Folded into `results`
rather than reported as a separate early exit ..."), not between that comment
and `CONF_CHANGED=0`, so the comment stays attached to the code it describes.
Both positions are after every `results` append in the loop and before the
summary is printed, so the refusal lands in the same place in the output, and
both are below line 593, so C-3's pin is unaffected.

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

*Result (GATES, 2026-10-12, run exactly as above).* Red with exactly the 11
predicted assertions and nothing else; restored and verified by `mutate.sh`:

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
gates: 584 passed, 11 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_gates.sh.20261012T191332Z.803.bak) ===
  573:   ( cd "$ROOT/$cwd" && eval "$cmd" ) </dev/null 2>&1 | tee "$log"
```

So with the stdin fix removed the accounting still refuses `later` rather
than certifying the run: Defect 2's invariant is independent of Defect 1's fix.
Green re-run: see DV-4's block.

**DV-2 (defect put back, central claim of Defect 2). Owner: GATES.** With the
refusal disabled and the seam kept - mutate `for d in $GATE_IDS; do` to
`for d in ; do` - AC-7 stays green (the seam still loses `b`), and every
assertion in AC-6, AC-8, AC-9 and AC-10 that names a refusal line, the count
line, `RESULT=fail`/`result: fail`, exit 1 or the absence of `All required
gates passed` **must** go red; AC-6's first case must classify as `other`
(exit 1 from the existing `cksum` refusal, `later` named nowhere - the
`false-cert` outcome is unreachable while that check stands; the PO's original
prediction said `false-cert` and was corrected at the end of RED on the
test-developer's finding, measured as `other` on the release 94 tree). RED
cannot run it: there is no invariant to disable. Paste the
FAIL lines, the count, and the green re-run. Then one variant for AC-11's
controls: mutate `reached="$reached $id"` to `reached="$reached"` (the
invariant forgets every disposition) and confirm every AC-11 row goes red with
a `never accounted for` line; paste the count.

*Result (GATES, 2026-10-12), first mutation*,
`bash scripts/mutate.sh scripts/gates.sh 's|^for d in \$GATE_IDS; do$|for d in ; do|' -- bash .claude/tests/gates.test.sh`.
No AC-7 assertion went red. Every refusal, count, `RESULT=fail`, `result: fail`,
exit-1 and not-certified assertion in AC-6, AC-8, AC-9 and AC-10 went red. AC-6's
first case classified as `other`, as corrected, and its "never certifies itself"
assertion stayed green:

```
    FAIL the gate after an in-place rewrite of project.conf either runs or is refused by name
         outcome: other (exit 1); wanted 'ran' or 'refused'
    FAIL and the summary has a FAIL line for it, its own or the refusal
    FAIL (a) a lost gate gets its own refusal line
    FAIL (a) and the refusals are counted
    FAIL (a) and the run is not certified
    FAIL (a) and exits 1
    FAIL (b) two lost gates: the first is refused
    FAIL (b) and the second
    FAIL (b) in manifest order
    FAIL (b) and both are counted
    FAIL (b) and the run is not certified
    FAIL (b) and exits 1
    FAIL (c) a lost optional gate is refused like a required one
    FAIL (c) and counted
    FAIL (c) and the run is not certified
    FAIL (c) and exits 1
    FAIL a full run that lost a gate records result: fail
    FAIL and the record carries the refusal line
    FAIL and the stamp says RESULT=fail
    FAIL (a) --fast: the lost gate is refused
    FAIL (a) --fast: exactly one gate is counted lost
    FAIL (a) --fast: and exits 1
    FAIL (b) --required: the lost gate is refused
    FAIL (b) --required: exactly one gate is counted lost
    FAIL (b) --required: and exits 1
    FAIL (c) --gate b: the lost gate it selected is refused
    FAIL (c) --gate b: exactly one gate is counted lost
    FAIL (c) --gate b: and exits 1, not 2
    FAIL (d) --gate a: a lost gate it did not select is still refused
    FAIL (d) --gate a: exactly one gate is counted lost
    FAIL (d) --gate a: and exits 1
gates: 564 passed, 31 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_gates.sh.20261012T192441Z.18426.bak) ===
  860: for d in $GATE_IDS; do
```

*Result, second mutation (AC-11's controls)*,
`bash scripts/mutate.sh scripts/gates.sh 's|^  reached="\$reached \$id"$|  reached="$reached"|' -- bash .claude/tests/gates.test.sh`.
`gates: 507 passed, 88 failed`. Every declared gate in every fixture is now
refused (e.g. `FAIL         unit (declared in project.conf but never accounted
for)`), so every exit-0 control across the file goes red, the pre-existing ones
included. AC-11 had 18 assertions, and 17 of them went red:

```
    FAIL healthy, full run: the summary is exactly what it was
    FAIL healthy, full run: and so is the exit code
    FAIL healthy, full run: and nothing is called unaccounted for
    FAIL healthy, --fast: the summary is exactly what it was
    FAIL healthy, --fast: and so is the exit code
    FAIL healthy, --fast: and nothing is called unaccounted for
    FAIL healthy, --required: the summary is exactly what it was
    FAIL healthy, --required: and so is the exit code
    FAIL healthy, --required: and nothing is called unaccounted for
    FAIL healthy, --gate w: the summary is exactly what it was
    FAIL healthy, --gate w: and so is the exit code
    FAIL healthy, --gate w: and nothing is called unaccounted for
    FAIL healthy, --gate u: the summary is exactly what it was
    FAIL healthy, --gate u: and so is the exit code
    FAIL healthy, --gate u: and nothing is called unaccounted for
    FAIL manifest errors: the summary is exactly what it was
    FAIL manifest errors: and nothing is called unaccounted for
gates: 507 passed, 88 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_gates.sh.20261012T193514Z.34081.bak) ===
  362:   reached="$reached $id"
```

The one AC-11 assertion that stayed green is `manifest errors: and so is the
exit code`. That fixture already exits 1, so a refusal cannot change its exit
code; its summary and "unaccounted for" assertions are what caught the
mutation.

**DV-3 (defect put back, AC-5). Owner: GATES.** With `</dev/null` removed from
`scripts/doctor.sh` line 268, AC-5 **must** go red: `ok       eats
discovered`, no `MISSING  later`, exit 0. Run through `mutate.sh` against
`bash .claude/tests/doctor.test.sh` only; paste the red and the green re-run.

*Result (GATES, 2026-10-12)*,
`bash scripts/mutate.sh scripts/doctor.sh 's|) </dev/null >/dev/null 2>&1; then|) >/dev/null 2>\&1; then|' -- bash .claude/tests/doctor.test.sh`.
AC-5 went red, the AC-5 control stayed green, and the file was restored:

```
    FAIL AC-5: the discovery line after a stdin-reading one is still checked, and reported MISSING
    FAIL AC-5: and doctor exits 1 for it
doctor: 62 passed, 2 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_doctor.sh.20261012T194117Z.49908.bak) ===
  268:   if ( set +o pipefail; cd "$ROOT/$cwd" 2>/dev/null && eval "$cmd" ) </dev/null >/dev/null 2>&1; then
```

**DV-4 (the pin). Owner: GATES.** `bash .claude/tests/sigpipe.test.sh` is
green on the committed tree, with `C-5 freshness: all twelve status-discarded
lines are still where this suite says they are` passing and line 593 of
`gates.sh` holding `why="could not launch: $(`. RED records the same assertion
red against the unchanged source (C-3). Paste `sed -n 593p scripts/gates.sh`
and the suite's summary line.

*Result (GATES, 2026-10-12)*, on the tree after DV-1 to DV-3 had been restored:

```
$ sed -n 593p scripts/gates.sh
      why="could not launch: $(clean_log "$log" | grep -Eom1 -- "$blockpat" | head -1)"
$ bash .claude/tests/sigpipe.test.sh </dev/null | tail -1
sigpipe: 82 passed, 0 failed
```

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

- RED, `test-developer`, dispatched with `model: opus`; the agent reported
  running on Opus 5.5 (`claude-opus-5-5`). As planned. Orchestrator
  (`/advance-story`) ran on Fable 5.1.
- GREEN, `feature-developer`, dispatched with `model: opus`; the agent reported
  running on Opus 5.5 (`claude-opus-5-5`). As planned. Orchestrator on Fable 5.1.

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

Level: integration throughout. Every test drives the real `scripts/gates.sh` /
`scripts/doctor.sh` copied into the suite's `make_project_fixture` tree, with a
`write_conf` manifest of `printf`/`cat`/`wc`/`exit` one-liners - the contract
under test is the runner's loop over its manifest, which no smaller unit holds.

| Where | describe block | AC | Assertions |
|---|---|---|---|
| `gates.test.sh` | `HARNESS-052 AC-1: a gate that reads its stdin cannot delete the gates after it` | AC-1 (a), (b) | 9 |
| `gates.test.sh` | `HARNESS-052 AC-2: a gate cannot reach the manifest through any inherited descriptor` | AC-2 | 4 |
| `gates.test.sh` | `HARNESS-052 AC-3: a gate reads end-of-input, not the manifest and not the caller's stdin` | AC-3 | 2 |
| `gates.test.sh` | `HARNESS-052 AC-4: --fast and --required give the same guarantee as a full run` | AC-4 | 7 |
| `gates.test.sh` | `HARNESS-052 AC-6: a gate that rewrites project.conf in place ...` | AC-6 | 5 |
| `gates.test.sh` | `HARNESS-052 AC-7: GATES_FAULT_LOSE loses exactly the gates it names ...` | AC-7 | 9 |
| `gates.test.sh` | `HARNESS-052 AC-8: a lost gate refuses the run` | AC-8 (a)(b)(c) | 15 |
| `gates.test.sh` | `HARNESS-052 AC-9: the refusal reaches the story record and the stamp` | AC-9 | 3 |
| `gates.test.sh` | `HARNESS-052 AC-10: --fast, --required and --gate refuse a lost gate ...` | AC-10 (a)-(d) | 16 |
| `gates.test.sh` | `HARNESS-052 AC-11: no false refusal - every disposition counts as accounted for` | AC-11 | 18 |
| `doctor.test.sh` | `HARNESS-052 AC-5: a discovery command that reads stdin cannot delete the discovery lines after it` | AC-5 | 3 (1 control) |
| `sigpipe.test.sh` | existing `C-5 freshness: ...` assertion, pin moved 580 -> 593 | C-3 / DV-4 | 1 (changed, not added) |

88 new assertions in `gates.test.sh` (22 for AC-1..AC-4, 66 for AC-6..AC-11 -
the same 22 and 66 the triage counted downstream), 3 in `doctor.test.sh`.

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

RED dispatched as `test-developer`, running on Opus 5.5 (`claude-opus-5-5`); no
model override was given in the dispatch.

### Commands

```bash
bash .claude/tests/gates.test.sh     # AC-1..AC-4, AC-6..AC-11 (several minutes here, run concurrently with another suite; the new blocks alone took 2m36s)
bash .claude/tests/doctor.test.sh    # AC-5
bash .claude/tests/sigpipe.test.sh   # C-3 / DV-4 pin
```

### Failure output on arrival (unchanged `scripts/gates.sh`, `scripts/doctor.sh`)

`bash .claude/tests/gates.test.sh` - every FAIL is in a HARNESS-052 block; the
507 assertions that existed before all still pass (507 is the suite's floor):

```
  HARNESS-052 AC-1: a gate that reads its stdin cannot delete the gates after it
    FAIL the gate after a stdin-reading gate still runs
         expected to contain: === gate: later (required) ===
         actual:
         === gate: eats (required) ===
         ...
         All required gates passed (1 ran, 0 unconfigured, 0 known).
    FAIL and so does the gate after it
    FAIL and both are counted as having run
    FAIL a failing required gate after a stdin-reading gate is reported FAIL
    FAIL and the run says a required gate failed
    FAIL and does not certify the run
    FAIL and exits 1
         expected: 1
         actual:   0
  HARNESS-052 AC-2: a gate cannot reach the manifest through any inherited descriptor
    FAIL a gate after one that drains fds 0 and 3-9 still runs and is reported FAIL
    FAIL and the run says a required gate failed
    FAIL and does not certify the run
    FAIL and exits 1
         expected: 1
         actual:   0
  HARNESS-052 AC-3: a gate reads end-of-input, not the manifest and not the caller's stdin
    FAIL a gate reads zero bytes of stdin, whatever gates.sh was given
         expected: stdin-bytes=0
         actual:   stdin-bytes=57
  HARNESS-052 AC-4: --fast and --required give the same guarantee as a full run
    FAIL --fast: a failing gate after a stdin-reading gate is reported FAIL
    FAIL --fast: the slow gate after them is still seen, and skipped
    FAIL --fast: the run says a required gate failed
    FAIL --fast: and exits 1
    FAIL --required: a failing gate after a stdin-reading gate is reported FAIL
    FAIL --required: the run says a required gate failed
    FAIL --required: and exits 1
  HARNESS-052 AC-6: a gate that rewrites project.conf in place cannot make a later gate vanish from a certified run
    FAIL the gate after an in-place rewrite of project.conf either runs or is refused by name
         outcome: other (exit 1); wanted 'ran' or 'refused'
    FAIL and the summary has a FAIL line for it, its own or the refusal
  HARNESS-052 AC-7: GATES_FAULT_LOSE loses exactly the gates it names, and says so before any gate runs
    FAIL a gate the seam names never runs
    FAIL the seam announces itself with a note: GATES_FAULT_LOSE is set line
    FAIL and the note names the gate it will lose
    FAIL and the note comes before the first gate banner
    FAIL a seam naming two gates loses the first
    FAIL and the second
  HARNESS-052 AC-8: a lost gate refuses the run
    FAIL (a) a lost gate gets its own refusal line
    FAIL (a) and the refusals are counted
    FAIL (a) and the run is not certified
    FAIL (a) and exits 1
    FAIL (b) two lost gates: the first is refused
    FAIL (b) and the second
    FAIL (b) in manifest order
    FAIL (b) and both are counted
    FAIL (b) and the run is not certified
    FAIL (b) and exits 1
    FAIL (c) a lost optional gate is refused like a required one
    FAIL (c) and counted
    FAIL (c) and the run is not certified
    FAIL (c) and exits 1
  HARNESS-052 AC-9: the refusal reaches the story record and the stamp
    FAIL a full run that lost a gate records result: fail
    FAIL and the record carries the refusal line
    FAIL and the stamp says RESULT=fail
         expected a line exactly: RESULT=fail
         actual:   RESULT=pass
  HARNESS-052 AC-10: --fast, --required and --gate refuse a lost gate, and never blame one they excluded
    FAIL (a) --fast: the lost gate is refused
    FAIL (a) --fast: exactly one gate is counted lost
    FAIL (a) --fast: and exits 1
    FAIL (b) --required: the lost gate is refused
    FAIL (b) --required: exactly one gate is counted lost
    FAIL (b) --required: and exits 1
    FAIL (c) --gate b: the lost gate it selected is refused
    FAIL (c) --gate b: exactly one gate is counted lost
    FAIL (c) --gate b: and exits 1, not 2
    FAIL (d) --gate a: a lost gate it did not select is still refused
    FAIL (d) --gate a: exactly one gate is counted lost
    FAIL (d) --gate a: and exits 1
  HARNESS-052 AC-11: no false refusal - every disposition counts as accounted for

gates: 539 passed, 56 failed
```

The 22 + 66 split reproduces the triage exactly: AC-1..AC-4 `3 passed, 19
failed` (triage `mc046`: 3/19), AC-6..AC-11 `29 passed, 37 failed` (triage
`mc047`: 29/37). Why each red is the right one: AC-1/2/4 show `later` absent
and `All required gates passed (1 ran, ...)`, exit 0 - the manifest was
drained; AC-3 shows `stdin-bytes=57`, the rest of the manifest; AC-6 classifies
`other` (exit 1 from `FAIL config: ... changed while the gates were running`,
`later` named nowhere) - exactly the control the story recorded; AC-7..AC-10
show all three banners and `(3 ran, ...)`, exit 0 - the seam is ignored; AC-9
shows `RESULT=pass` and a `result: pass` record. No FAIL is a syntax error, a
missing helper or a fixture problem.

`bash .claude/tests/doctor.test.sh </dev/null`:

```
  HARNESS-052 AC-5: a discovery command that reads stdin cannot delete the discovery lines after it
    FAIL AC-5: the discovery line after a stdin-reading one is still checked, and reported MISSING
         expected to contain: MISSING  later
         actual:               Harness prerequisites
         ...
         Test discovery
           ok       eats         discovered

         Everything this project needs is installed.
    FAIL AC-5: and doctor exits 1 for it
         expected: 1
         actual:   0

doctor: 62 passed, 2 failed
```

`bash .claude/tests/sigpipe.test.sh </dev/null`:

```
    FAIL C-5 freshness: all twelve status-discarded lines are still where this suite says they are
         expected: 12 lines, none stale
         actual:   12 lines,
           scripts/gates.sh:593 no longer holds [why="could not launch: $(] - it holds:         why="floor of $floor declared, but no number was found in the evidence match, so the work could not be measured"

sigpipe: 81 passed, 1 failed
```

`bash scripts/gates.sh --fast`: every gate in this repository's `project.conf`
is UNCONFIGURED (`BOOTSTRAPPED=no`), `mutation` ON REQUEST, `--fast skipped:
integration build`, `All required gates passed (0 ran, 5 unconfigured, 0
known).` Nothing about the test files reaches it; the harness suites run only
through `selftest.sh`.

### Files touched, and which AC each test covers

- `.claude/tests/gates.test.sh` - ten new `describe` blocks appended before the
  final `summary "gates"`; one line per test is the FAIL list above plus the
  passes-on-arrival list below. AC-1 (a)(b), AC-2, AC-3, AC-4 (`--fast`,
  `--required`), AC-6 (both cases), AC-7, AC-8 (a)(b)(c), AC-9, AC-10 (a)-(d),
  AC-11 (five healthy rows, one manifest-errors row).
- `.claude/tests/doctor.test.sh` - one new `describe` block before `summary
  "doctor"`: AC-5 (two assertions) and a control.
- `.claude/tests/sigpipe.test.sh` - line 568 only, `580` -> `593` (C-3).
- `docs/backlog/stories/HARNESS-052.md` - `## Test plan` and this handoff.

Departures from the `## Notes` text, every assertion kept: `describe` titles
carry a `HARNESS-052 AC-n:` prefix (test names unchanged, so DV-1's predicted
FAIL lines still match); `assert_lacks` is a one-line alias for `_lib.sh`'s
identical `assert_not_contains`; AC-10's manifest is held in a variable
(`AC10_CONF`) rather than written to `$FIX/ac5.conf`, so no untracked file is
ever in the fixture; AC-9's two `# adapted` git lines are kept verbatim.

Fixture state: the blocks assume the shared `$FIX` (`make_project_fixture`,
`project.conf` tracked by the first block) and rewrite `project.conf` per case.
The block before them ends with `checkout -- .` and `set_phase "$FIX" ""`, so
no story is active; AC-9 creates `T-47`, switches to `story/T-47-fixture` and
switches back with `checkout -`. `summary "gates"` still runs last.

### What the tests pin (no exported functions; the contract is CLI behaviour)

- `scripts/gates.sh` reads the environment variable `GATES_FAULT_LOSE`
  (space-separated gate ids). The tests pin: a line starting exactly
  `note: GATES_FAULT_LOSE is set` that contains each named id as a token, before
  the first `=== gate:` line; no `=== gate: <id> (` banner for a named id.
- The refusal summary line, whole: `FAIL         <id> (declared in project.conf but never accounted for)`
  (`FAIL` + 9 spaces), one per lost entry, in manifest order.
- The count line, whole: `<N> declared gate(s) never accounted for; this run certifies nothing.`
- A lost gate makes exit 1 (not 2, even under `--gate <lost id>`), suppresses
  `All required gates passed`, stamps `RESULT=fail`, records `result: fail` in
  the story's `## Gate results` (matched `^ *result: fail( |$)`), and the record
  carries the refusal line indented four spaces.
- AC-11 pins the existing summary lines byte-for-byte (timings masked); any new
  line beginning `PASS|FAIL|WARN|KNOWN|UNCONFIGURED ` or any change to the verdict
  line breaks it, and no output may contain `never accounted for`.
- `scripts/doctor.sh` must check a `discovery` line after one that reads stdin,
  printing `MISSING  later` and exiting 1.
- Not constrained: where the note line sits relative to other preamble output
  (only "before the first banner"); the exact wording after `is set` in the note;
  whether lost gates count into `fails` or exit on `lost` separately (C-2's
  alternative); the order of the refusal relative to `FAIL config:` (AC-6);
  the `result: fail (...)` parenthetical.

### Passed on arrival, and what earns each

| Test | Why it passes today | Earned by |
|---|---|---|
| AC-1 `the stdin-reading gate passes` | `eats` runs and passes before and after the fix | DV-1 (stays green under it; it is a precondition, not the claim) |
| AC-1 `a run of two passing gates exits 0` | release 94 exits 0 having lost `later` - the false certification | DV-1 (must go red under it, as the triage's predicted list says) |
| AC-3 `a run given data on stdin still finishes` | finite pipe, no block | precondition only; AC-3's real assertion is `stdin-bytes=0` |
| AC-6 `and the run never certifies itself with that gate absent` | the existing `cksum` check refuses the run | not earnable by DV-2 as written - see "For GREEN", AC-6 finding |
| AC-6 `a failing required gate after an in-place rewrite fails the run`, `and the run is not certified` | same `cksum` refusal | the cksum check's own suite; DV-2 |
| AC-7 `the gate before it still runs`, `and so does the gate after it`, `and runs the one it does not name` | with no seam every gate runs | guards against a seam that loses too much; DV-2 keeps them green |
| AC-8(c) `not merely warned about`; AC-10 `--fast skipped: s`, the two `assert_no_line` and `no gate named` | absence/precondition assertions that hold with no seam | DV-2 |
| AC-11, all 18 | negative controls on the invariant: there is no invariant yet | **DV-2's second variant** (`reached="$reached"`), owned by GATES |

### Negative controls - expected values

None of these ran inside a passing implementation (there is none); the values
under "measured" are what this RED run observed against unchanged source.
Confirming each against the shipped fix is GREEN's/GATES's job.

| Control | Expected after GREEN | Measured in RED (release 94 tree) |
|---|---|---|
| AC-3 stdin bytes a gate reads | `stdin-bytes=0` | `stdin-bytes=57` (the rest of the manifest) |
| AC-11 healthy, full | `PASS a (Ns, observed 3)` / `KNOWN k (...; fixture: known red) -> ...k.log` / `WARN w (Ns, exit 1, optional) -> ...w.log` / `UNCONFIGURED u` / `PASS s (Ns, observed 2)` / `All required gates passed (4 ran, 1 unconfigured, 1 known).`, exit 0 | identical (assert_eq exact against the story's text: passes) |
| AC-11 healthy, `--fast` | same minus `s`, plus `--fast skipped: s`, `(3 ran, 1 unconfigured, 1 known)`, exit 0 | identical |
| AC-11 healthy, `--required` | `PASS a`, `PASS s`, `(2 ran, 0 unconfigured, 0 known)`, exit 0 | identical |
| AC-11 healthy, `--gate w` / `--gate u` | `WARN w ...` `(1 ran, 0, 0)` / `UNCONFIGURED u` `(0 ran, 1, 0)`, exit 0 | identical |
| AC-11 manifest errors | five `FAIL e_*` lines as the AC gives, `PASS ok (Ns, observed 1)`, `5 required gate(s) failed.`, exit 1 | identical |
| AC-11, any row, under DV-2 variant `reached="$reached"` | red, with a `never accounted for` line | not runnable in RED (no invariant) |
| DV-1 (`</dev/null` removed, accounting kept) | exactly 11 FAIL lines, the list in DV-1 | not runnable in RED (no fix to remove) |
| AC-5 control: `eats` alone in doctor | exit 0 | exit 0 (passes) |
| AC-6 first case | `ran` or `refused` | `other`, exit 1 (cksum refusal, `later` unnamed) |

The healthy and manifest-error summaries measured on this tree are the story's
settled ones, byte for byte: no finding.

### Callers checked

`rg GATES_FAULT_LOSE` and `rg 'never accounted for'` over the tree outside this
story and the new tests: no match for the variable; one prose mention of "declared
but never accounted for" in `docs/backlog/stories/HARNESS-057.md:502`, which reads
nothing. The contract's callers list stands.

### C-1 / C-3 checked against the source

- `scripts/gates.sh` lines 154, 338, 341, 349, 560, 580, 681, 848, 1009 and
  `scripts/doctor.sh` 268, 275 hold what the contract says. `gates.sh` contains
  no `exec`, no `{var}>` redirect and no redirect on fds 3-9, so `</dev/null` on
  the subshell is the whole of C-1; AC-2 needs nothing more. No amendment.
- 580 + 11 (C-2's pre-loop block: 6 comment lines, `reached=...`, `if`,
  `fault_lose=`, `printf`, `fi`) + 2 (in-loop) = 593. The pin is right.

### Deferred verifications

DV-1, DV-2, DV-3 and DV-4 are **declined in RED**: each mutates or inspects a fix
that does not exist yet. They are owned by GATES, as the story says.

### For GREEN

- Land C-2's blocks exactly, line for line, or `sigpipe.test.sh`'s pin misses
  593 (C-3 says what to do if it cannot).
- Floors: `.claude/tests/floors.conf` need not move (a floor is a minimum). After
  GREEN, `gates` should read 595 passed and `doctor` 64; raising them is
  optional and is a harness-file edit.
- `sigpipe` reads `81 passed, 1 failed` until GREEN, which is below its floor of
  82 - so `selftest.sh` is red on that suite for the right reason as well.
- **AC-6 finding, for the orchestrator and GATES (DV-2's text, not a contract
  change).** DV-2 says that with `for d in ; do` "AC-6's first case must
  classify as `false-cert`". By `ac1_outcome`'s own definition it cannot while
  the existing `cksum` check stays in place: that check still refuses the run
  (exit 1, no `All required gates passed`), so the outcome is `other` - exactly
  what this RED run measured on release 94, which has no invariant at all. Under
  DV-2 expect `the gate after an in-place rewrite ... either runs or is refused
  by name` red with `outcome: other`, and `and the run never certifies itself
  ...` green. `false-cert` is reachable only with the cksum check disabled as
  well. I did not amend DV-2; GATES should record the measured outcome rather
  than the predicted one.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-12T19:54:31Z
    commit: 2d20b15
    tree:   2eea56e1d3cc7d7dacd597bdbef28ad2e268e217
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

### GREEN confirmations

Feature developer, running on Opus 5.5 (`claude-opus-5-5`); no model override
in the dispatch. C-1 and C-2 landed as written; the one departure is the
placement of the declared-vs-reached block, amended in place under C-2.
Suites run one at a time, stdin from `/dev/null` (other sessions' suites were
running on this host at the time, so wall-clock times are not meaningful):

```
$ bash .claude/tests/sigpipe.test.sh </dev/null
sigpipe: 82 passed, 0 failed
$ bash .claude/tests/doctor.test.sh </dev/null
doctor: 64 passed, 0 failed
$ bash .claude/tests/gates.test.sh </dev/null
gates: 595 passed, 0 failed
$ sed -n 593p scripts/gates.sh
      why="could not launch: $(clean_log "$log" | grep -Eom1 -- "$blockpat" | head -1)"
```

Negative controls against the shipped code (RED's table):

- AC-3: measured directly on a `make_project_fixture` copy with
  `printf 'CALLER-DATA\n' | bash scripts/gates.sh`: `count.log` holds
  `stdin-bytes=0` (RED measured 57 on the unfixed tree). Matches the expected
  value.
- AC-11: all five healthy rows and the manifest-errors row pass inside
  `gates.test.sh` (the suite compares them exactly against the story's text),
  so they are byte for byte what RED measured; no `never accounted for` line
  in any of them. Their red under DV-2's second variant is GATES' work.
- AC-5 control: `discovery | eats | . | cat >/dev/null; true` alone, doctor
  exits 0 (holds). With `later` after it: `ok       eats         discovered`,
  `MISSING  later        nothing discovered by: false`, exit 1.
- AC-6 first case: passes in the suite (outcome `ran` or `refused`); DV-2's
  `other` prediction is GATES' to measure.

Also run: `bash scripts/gates.sh --fast` -> `All required gates passed (0 ran,
5 unconfigured, 0 known).`; `bash scripts/check-sigpipe.sh` -> `scanned 49
shell file(s), 45 with pipefail, 0 finding(s)`; `bash scripts/check-grep-count.sh`
-> `scanned 49 shell file(s), 0 finding(s)`. DV-1..DV-4 not run (GATES).
