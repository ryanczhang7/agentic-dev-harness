---
id: HARNESS-055
title: A gate can declare that its evidence line carries no count, and a floor on it is refused
slug: a-gate-can-declare-that-its-evidence-lin
epic: 
type: feature
status: in-progress
phase: GREEN
branch: story/HARNESS-055-a-gate-can-declare-that-its-evidence-lin
depends_on: [HARNESS-052]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/gates.sh, .claude/tests/gates.test.sh, .claude/tests/profiles.test.sh, .claude/tests/sigpipe.test.sh, .claude/tests/floors.conf, .claude/skills/quality-gates/SKILL.md, .claude/skills/quality-gates/reference/configuring.md, .claude/skills/stack-profiles/reference/new-profile.md, .claude/skills/stack-profiles/reference/rust-cargo.md, .claude/skills/stack-profiles/reference/node-typescript.md, .claude/skills/stack-profiles/reference/python-uv.md, .claude/skills/stack-profiles/reference/web-static.md, .claude/harness/project.conf, README.md]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

**The defect.** `scripts/gates.sh`'s `work_count()` reads the first run of
digits at or after the evidence match as the gate's count of work, and it
cannot tell a count from a stopwatch, a version, or any other number that
happens to sit there. Cargo's warm-cache line is

    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.29s

so a gate whose evidence regex is `Finished .* profile` reports the **elapsed
seconds** as `observed`. Harmless while nothing reads the number; a coin-toss
gate the moment someone adds `floor | lint | 5` in good faith, because the gate
then passes or fails on how warm the build cache is. Nothing refuses that
today, and `--audit` refusing a floor with no evidence line makes a floor look
like a protected thing.

**Reproduced on this tree, 2026-10-11, release 93 (`gates.sh` unchanged in
94).** A fixture whose `lint` gate prints `... in 5.29s` with
`evidence | lint | Finished .* profile` and `floor | lint | 5`:

    PASS         lint (0s, observed 5, floor 5)
    All required gates passed

That is the stopwatch being graded as five units of work and clearing a floor
of five.

**The trap ships pre-installed.** Four of the five stack profiles carry an
evidence regex with no count under it, undeclared:

- `rust-cargo.md:38-40` - `Finished .* profile` on `lint`, `typecheck`, `build`
  (seconds)
- `node-typescript.md:52` - `built in [0-9]` on `build` (seconds)
- `web-static.md:35` - `built in` on `build` (seconds)
- `python-uv.md:34` - `Successfully built` on `build` (`foo-0.1.0.tar.gz`, a
  version)

godot is left alone: its alternation yields no digits on one branch, which
already fails loudly.

**Why declared, not inferred.** "The regex has no digit class" is the obvious
test and it is wrong in both directions: `Finished .* profile` has none and
matches a stopwatch, while `TOTAL` (the coverage regex) has none and is
followed by a real region count a floor may legitimately use. Changing the
cargo regexes is not possible either: cargo prints one `Compiling <crate>` line
per crate on a cold cache and nothing but `Finished` on a warm one, which is
the same fact that makes those regexes weak already (`rust-cargo.md`, "weak on
purpose").

**The downstream fix, and why it has to come upstream now.** manhwa-cropper
fixed this on 2026-09-15 in commit `f0ee3e2` ("harness: refuse a floor on a
gate whose evidence regex has no count"): a `no-count | <gate id> | <why>`
declaration, a declared gate reporting `observed -`, any floor on it refused at
audit time and run time both, the reason required, and an orphan id failing the
audit - all modelled on `slow`. That project's `project.conf` (lines 249-251)
now declares `no-count` for `lint`, `typecheck` and `build`. Upstream's parser
drops any kind it does not recognise (`gates.sh:155`, `case "$kind" in
evidence|...|skipped-when) ;; *) continue`), so after a harness refresh those
three lines become **silently inert** and `--audit` still prints "Manifest
audit passed". Porting is what stops a refresh deleting a consumer's protection
without a word.

**Triage of `f0ee3e2`'s 11 assertions, verbatim, against this tree
(2026-10-11):** 4 passed, 7 failed. The seven: declared -> `observed -`; the
audit refuses a floor on a no-count gate; the run refuses it rather than
passing on the clock (two assertions); no-count without a reason fails the
audit; no-count naming no gate fails the audit; and the audit's
`1 manifest problem` count. With a prototype port of the `gates.sh` hunks:
11/0, and the full upstream `gates.test.sh` with that port: `gates: 507 passed,
0 failed`. The assertions are in `## Contract`, C-5.

**Required gate that fails if this story's artifact broke:** `selftest`,
through `.claude/tests/gates.test.sh` (`bash scripts/selftest.sh gates`) for
the behaviour and `.claude/tests/profiles.test.sh` (`bash scripts/selftest.sh
profiles`) for the four shipped profiles. CI's `gates.yml` runs `selftest.sh`
and `gates.sh --audit` on every PR. This repository's own gates in
`project.conf` have no commands, so `bash scripts/gates.sh` here exercises
nothing of this; the selftest is the gate.

**Ordering.** `depends_on: [HARNESS-052]` because both stories edit
`scripts/gates.sh` and the line-number pins in `.claude/tests/sigpipe.test.sh`;
two stories moving the same pins in parallel cannot both be right. Serialised,
not merged: the behaviours are unrelated. The pin numbers in C-8 below were
computed against release 94's `gates.sh`; **if HARNESS-052 lands first and
moves lines, RED recomputes them** from the contract's verbatim diff (the
method is in C-8).

## Acceptance criteria

All criteria are **mechanical** (an exact output shape of a shell script over a
fixture manifest); none is oracle-free. The fixture lines are the ones
`f0ee3e2` used and the triage reproduced; RED may reword assertion names but
the manifests and needles are the contract.

- **AC-1** - Given a manifest with `gate | lint | required | . | printf
  'Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.29s\n'`,
  `evidence | lint | Finished .* profile` and `no-count | lint | the digits
  after it are elapsed seconds, not a count`, when `bash scripts/gates.sh`
  runs, then the summary line for `lint` contains `observed -` and
  `PASS         lint`.
  *Control (passes today, stays as the record of the mechanism):* the same
  manifest without the `no-count` line prints `observed 0` - the stopwatch
  reported as a count.
  *Control (passes today, must keep passing):* the same declared manifest
  with the gate printing `nothing to do` instead fails with `no evidence of
  work` - `no-count` withholds the measurement, it never excuses liveness.

- **AC-2** - Given the AC-1 declared manifest with the gate printing
  `... in 5.29s` and `floor | lint | 5` added, when `bash scripts/gates.sh
  --audit` runs, then the output contains `declared no-count` and
  `1 manifest problem`, and the exit status is non-zero.
  *Control (the defect, fails today):* without the port this manifest passes
  the audit and the run prints `PASS         lint (0s, observed 5, floor 5)`.

- **AC-3** - Given the AC-2 manifest, when `bash scripts/gates.sh` runs (no
  `--audit`), then `lint` is reported `FAIL         lint` with a reason
  containing `declared no-count`, and the run does not say
  `All required gates passed`.

- **AC-4** - Given `no-count | lint |` (no reason) on a configured `lint`
  gate, when `bash scripts/gates.sh --audit` runs, then it prints
  `marked no-count with no reason` and fails; and on a plain run the gate is
  reported `FAIL         lint (marked no-count with no reason in
  project.conf)` without its command being run.

- **AC-5** - Given `no-count | lnit | ...` (an id naming no configured gate)
  beside `floor | lint | 5`, when `bash scripts/gates.sh --audit` runs, then
  it prints `names no configured gate` and fails. (The misspelt line defends
  nothing; the floor it meant to prevent is still there.)

- **AC-6** - Given `gate | coverage | required | . | printf 'TOTAL  1629  16
  99.02%%\n'`, `evidence | coverage | TOTAL` and `floor | coverage | 1000`
  with **no** `no-count` line, when `bash scripts/gates.sh` runs, then the
  summary contains `observed 1629, floor 1000`. A digit-class-free regex is
  not treated as count-free: the property is declared, never inferred.
  *(Passes today; it is the negative control on the design and must keep
  passing after GREEN.)*

- **AC-7** - Given the AC-1 declared manifest, when `bash scripts/gates.sh
  --list` runs, then the `lint` block carries a line
  `no-count: the digits after it are elapsed seconds, not a count (no floor
  possible)`; and when `bash scripts/gates.sh --audit` runs on it, the `ok`
  block for `lint` carries `no-count: the digits after it are elapsed
  seconds, not a count (reports `observed -`; no floor possible)` and the
  audit passes.

- **AC-8** - Given the four shipped profiles, when `bash scripts/selftest.sh
  profiles` runs, then each of `rust-cargo.md` (`lint`, `typecheck`,
  `build`), `node-typescript.md` (`build`), `python-uv.md` (`build`) and
  `web-static.md` (`build`) carries a `no-count` line with a non-empty
  reason for exactly those gates, and the profile checker enforces three new
  invariants, fixture-checked before being pointed at the profiles: a floor on
  a no-count gate is a `floor` problem (`is declared no-count, so there is no
  count to compare against`); a no-count naming an unconfigured gate is an
  `orphan`; a no-count with no reason is a `no-count` problem.
  *Control:* a fixture profile carrying `floor | build | 5` beside
  `no-count | build | seconds` must be reported; one carrying the floor on a
  gate with a real count must not.

## Contract

**Writes:** `scripts/gates.sh`, `.claude/tests/gates.test.sh`, `.claude/tests/profiles.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/tests/floors.conf`, `.claude/skills/quality-gates/SKILL.md`, `.claude/skills/quality-gates/reference/configuring.md`, `.claude/skills/stack-profiles/reference/new-profile.md`, `.claude/skills/stack-profiles/reference/rust-cargo.md`, `.claude/skills/stack-profiles/reference/node-typescript.md`, `.claude/skills/stack-profiles/reference/python-uv.md`, `.claude/skills/stack-profiles/reference/web-static.md`, `.claude/harness/project.conf`, `README.md`

RED may amend any block below in place, with a reason; GREEN builds what the
amended block says. No existing export changes signature: `work_count()`,
`table_lookup()` and the parser loop keep their shapes, and `work_count` stays
"a dumb reader of digits" - the callers decide whether to believe it.

**Re-anchored 2026-10-13 (Lead PO, before RED).** HARNESS-052 is DONE and
moved `scripts/gates.sh` from 1027 to 1057 lines. C-2's diff still applies
with `patch` (hunks 9-13 at +13); GREEN applies it that way or by hand against
the context lines, not by the stale numbers. C-8's pins are recomputed below.
README anchors are now `:253` and `:372`. The `quality-gates/SKILL.md`
sentence C-7 cites is line-wrapped (`...before anyone commits to a` / `floor.`)
in "The gate that shrank"; it exists.

### C-1 - the manifest grammar

    no-count | <gate id> | <why its evidence regex measures nothing>

- Parsed by the same loop as `slow`/`ci-factor`, into a new `NOCOUNTS` table
  (`"<id><TAB><why>"` lines). The reason is `rest 3`, so it may contain `|`.
- Looked up per gate beside the `ci-factor` lookup:
  `nocountwhy=$(table_lookup "$NOCOUNTS" "$id"); is_nocount=$?`
  (`is_nocount = 0` means declared, as `is_slow` does.)
- **Semantics of `is_nocount = 0`:** the gate's evidence regex proves
  liveness only. Liveness is still asserted exactly as before (the `no
  evidence of work` branch runs first and is untouched). The count is withheld
  (`observed="-"`), and the summary therefore reads `observed -`. Any `floor`
  on the gate is a manifest error, refused before the gate runs.
- **The empty reason** is a manifest error of its own, checked before the
  floor checks (so `no-count | lint |` plus `floor | lint | 5` reports the
  missing reason, as `slow` does).
- **An orphan id** (`no-count` naming no `gate` line) fails `--audit`, in the
  orphan loop after `ci-factor`'s. It is silent on a plain run, as the other
  orphans are.

### C-2 - `scripts/gates.sh`, the exact change

The diff below is the whole production change, built on 2026-10-12 against
release 94 (`scripts/gates.sh`, 1027 lines) and syntax-checked; it is
`f0ee3e2`'s `gates.sh` hunks re-anchored on this tree's parser (which also
knows `ondemand`, `covers`, `blocked-when`, `skipped-when`). GREEN writes it
as given, comments included - the comment lengths decide the pin numbers in
C-8. Scratch build result: 1079 lines, `bash -n` clean.

```diff
21,24c21,27
< # shrinks from 47 tests to 3 fails instead of passing faster. `waiver` lines
< # name an optional gate that is known to fail, and why, so that WARN in the
< # summary always means something changed. All three are described in the
< # quality-gates skill.
---
> # shrinks from 47 tests to 3 fails instead of passing faster. `no-count` lines
> # say the opposite about a gate - that its evidence regex proves liveness but
> # measures nothing, so the digits sitting under it are not a count of work and
> # a floor on them would be nonsense. Such a gate reports `observed -`, and a
> # floor declared on it is refused. `waiver` lines name an optional gate that is
> # known to fail, and why, so that WARN in the summary always means something
> # changed. All four are described in the quality-gates skill.
88c91
<     -h|--help) sed -n '2,42p' "$0"; exit 0 ;;
---
>     -h|--help) sed -n '2,45p' "$0"; exit 0 ;;
140c143
< EVIDENCE=""; WAIVERS=""; FLOORS=""; SLOWS=""; ONDEMANDS=""; CIFACTORS=""; COVERS=""; BLOCKEDWHEN=""; SKIPPEDWHEN=""; GATE_IDS=""
---
> EVIDENCE=""; WAIVERS=""; FLOORS=""; SLOWS=""; ONDEMANDS=""; CIFACTORS=""; COVERS=""; BLOCKEDWHEN=""; SKIPPEDWHEN=""; NOCOUNTS=""; GATE_IDS=""
155c158
<   case "$kind" in evidence|waiver|floor|slow|ondemand|ci-factor|covers|blocked-when|skipped-when) ;; *) continue ;; esac
---
>   case "$kind" in evidence|waiver|floor|slow|ondemand|ci-factor|covers|blocked-when|skipped-when|no-count) ;; *) continue ;; esac
177a181,182
>     no-count) NOCOUNTS="$NOCOUNTS$tid$TAB$tval
> " ;;
277a283,292
> #
> # The sharper consequence is that this function ALWAYS returns whatever digits
> # it finds, and cannot tell a count from a stopwatch. `Finished .* profile`
> # proves cargo ran and measures nothing: the digits after it are the elapsed
> # time, so a warm cache "observes 0" and a cold one "observes 2". That is not
> # detectable from the regex either - `TOTAL` has no digit class and is followed
> # by a real region count - so it is DECLARED, with a `no-count` line, and the
> # callers below consult that instead of guessing. Nothing here changes: this
> # function stays a dumb reader of digits, and its callers decide whether to
> # believe them.
418a434
>   nocountwhy=$(table_lookup "$NOCOUNTS" "$id"); is_nocount=$?
424a441
>     [ "$is_nocount" = 0 ] && printf '%-12s %-9s %-6s no-count: %s (no floor possible)\n' "" "" "" "${nocountwhy:-no reason given}"
453,455c470,484
<   # A floor is measured out of the evidence match, so it needs one, and it has
<   # to be a number. Both are checked before anything runs: a floor that cannot
<   # be evaluated would otherwise sit in project.conf looking like protection.
---
>   # A `no-count` line with no reason is the same failure as a `slow` one: the
>   # next person needs to know WHY the regex measures nothing, or they will read
>   # the line as a shrug and delete it.
>   if [ "$is_nocount" = 0 ] && [ -z "$nocountwhy" ]; then
>     if [ "$AUDIT" = 1 ]; then
>       printf 'FAIL %-12s marked no-count with no reason; say what its evidence regex measures instead\n' "$id"
>     else
>       results="$results\nFAIL         $id (marked no-count with no reason in project.conf)"
>     fi
>     fails=$((fails+1)); continue
>   fi
>   # A floor is measured out of the evidence match, so it needs one, it has to
>   # be a number, and the match has to contain a count rather than a stopwatch.
>   # All three are checked before anything runs: a floor that cannot be
>   # evaluated would otherwise sit in project.conf looking like protection.
463a493,499
>     # The dangerous case, and the quiet one: /$exp/ matches, a number is found,
>     # the floor compares cleanly against it, and the number means nothing. A
>     # floor on `Finished .* profile` passes or fails on how warm the build
>     # cache is. Refusing it is the whole point of the no-count declaration.
>     if [ -z "$floor_broken" ] && [ "$is_nocount" = 0 ]; then
>       floor_broken="floor cannot be measured: $id is declared no-count ($nocountwhy)"
>     fi
538a575
>     [ "$is_nocount" = 0 ] && printf '     %-12s no-count: %s (reports `observed -`; no floor possible)\n' "" "$nocountwhy"
584a622,626
>   elif [ "$exp" != "<none>" ] && [ "$exp" != "-" ] && [ "$is_nocount" = 0 ]; then
>     # Live, but unmeasurable by declaration. Print the dash rather than the
>     # digits work_count would have found: a number nobody may act on is worse
>     # than no number, because it reads exactly like one somebody may.
>     observed="-"
722a765,774
>   # Same for a no-count: it is the thing standing between a real gate and a
>   # floor on a stopwatch, and a misspelt id leaves that gate undefended while
>   # looking, in project.conf, exactly as though it were covered.
>   while IFS="$TAB" read -r nid _; do
>     [ -n "$nid" ] || continue
>     case " $GATE_IDS " in
>       *" $nid "*) ;;
>       *) printf 'FAIL %-12s a `no-count` line names no configured gate\n' "$nid"; fails=$((fails+1)) ;;
>     esac
>   done <<< "$NOCOUNTS"
```

Reading notes for GREEN, one per hunk that is not self-evident:

- `2,42p` -> `2,45p`: the header grew by three lines, and the help range
  moves by the same three so it still ends on the same paragraph.
- The `elif ... observed="-"` branch sits **between** the `noevidence` branch
  and the `work_count` branch: liveness is checked first, so the "nothing to
  do" control in AC-1 still fails with `no evidence of work`; and a declared
  gate never reaches `work_count`, so no floor arithmetic runs on it (the
  floor was refused before the gate ran anyway).
- `observed="-"` makes the existing pass-line code print `observed -` with no
  further change: `[ -n "$observed" ]` is true for `-`.
- The `--list` line uses `${nocountwhy:-no reason given}` because `--list`
  runs before the reason check; the audit/run paths have already refused an
  empty reason by the time they print.

### C-3 - exact message text (the needles RED pins)

| Where | Text |
|---|---|
| summary, declared, passing | `PASS         lint (<n>s, observed -)` |
| `--audit`, floor on a no-count gate | `FAIL lint         floor cannot be measured: lint is declared no-count (<why>)` then `1 manifest problem` |
| plain run, floor on a no-count gate | `FAIL         lint (floor cannot be measured: lint is declared no-count (<why>))` |
| `--audit`, empty reason | `FAIL lint         marked no-count with no reason; say what its evidence regex measures instead` |
| plain run, empty reason | `FAIL         lint (marked no-count with no reason in project.conf)` |
| `--audit`, orphan id | ``FAIL lnit         a `no-count` line names no configured gate`` |
| `--list`, declared | `no-count: <why> (no floor possible)` on the gate's block |
| `--audit` ok block, declared | ``no-count: <why> (reports `observed -`; no floor possible)`` |

Column widths follow the existing `%-12s` convention; RED should match
substrings (`assert_contains`) rather than whole lines, as the existing suite
does, and anchor on the phrase plus the gate id where the opposite phrase is
also a substring (`rules.md`, the needle rule: `declared no-count` cannot be
negated into a match; `observed -` cannot either, since `observed 0` does not
contain it).

### C-4 - `.claude/tests/gates.test.sh`, the new block

Insert after `describe "the count is reported even with no floor"` (line 114)
and before `describe "required_gates: ..."`. Verbatim from `f0ee3e2`; 11
assertions, all run through the existing `gates()` and `write_conf` helpers:

```bash
# ---------------------------------------------------------------------------
describe "no-count: an evidence regex that proves liveness and measures nothing"

# The field report: cargo's `Finished \`dev\` profile ... in 0.29s` proves the
# tool ran and offers no count, so work_count reports the ELAPSED TIME. It read
# 0, then 2, then 6 across runs of the same unchanged workspace. Harmless while
# decorative; a coin-toss gate the moment somebody puts a floor under it.
write_conf "$FIX" <<'EOF'
gate     | lint | required | . | printf 'Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.29s\n'
evidence | lint | Finished .* profile
EOF
out="$(gates)"
assert_contains "undeclared, the stopwatch is reported as a count" "observed 0" "$out"

write_conf "$FIX" <<'EOF'
gate     | lint | required | . | printf 'Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.29s\n'
evidence | lint | Finished .* profile
no-count | lint | the digits after it are elapsed seconds, not a count
EOF
out="$(gates)"
assert_contains "declared, the number is withheld" "observed -" "$out"
assert_contains "and liveness still holds"         "PASS         lint" "$out"

# The same gate with nothing to say still fails: `no-count` withholds the
# measurement, it does not excuse the gate from proving it ran.
write_conf "$FIX" <<'EOF'
gate     | lint | required | . | printf 'nothing to do\n'
evidence | lint | Finished .* profile
no-count | lint | the digits after it are elapsed seconds, not a count
EOF
out="$(gates)"
assert_contains "no-count does not weaken the evidence assertion" "no evidence of work" "$out"

describe "no-count: a floor on it is refused"

write_conf "$FIX" <<'EOF'
gate     | lint | required | . | printf 'Finished `dev` profile [unoptimized + debuginfo] target(s) in 5.29s\n'
evidence | lint | Finished .* profile
no-count | lint | the digits after it are elapsed seconds, not a count
floor    | lint | 5
EOF
out="$(gates --audit)"
assert_contains "the audit refuses it" "declared no-count" "$out"
assert_contains "and the audit fails"  "1 manifest problem" "$out"

# Refused at run time too, not only under --audit: a floor that would otherwise
# have PASSED here purely because the fixture's stopwatch read 5.29s.
out="$(gates)"
assert_contains "the run refuses it"  "FAIL         lint" "$out"
assert_contains "rather than passing on the clock" "declared no-count" "$out"

describe "no-count: a line that defends nothing is a manifest error"

write_conf "$FIX" <<'EOF'
gate     | lint | required | . | printf 'Finished `dev` profile in 0.29s\n'
evidence | lint | Finished .* profile
no-count | lint |
EOF
out="$(gates --audit)"
assert_contains "no-count without a reason fails the audit" "marked no-count with no reason" "$out"

write_conf "$FIX" <<'EOF'
gate     | lint | required | . | printf 'Finished `dev` profile in 0.29s\n'
evidence | lint | Finished .* profile
no-count | lnit | a typo, so lint is left open to a floor on its stopwatch
floor    | lint | 5
EOF
out="$(gates --audit)"
assert_contains "no-count naming no gate fails the audit" "names no configured gate" "$out"

# A count-free regex is not detectable from the regex, which is why it is
# declared. `TOTAL` has no digit class either, and the number after it is a
# real one a floor may use.
write_conf "$FIX" <<'EOF'
gate     | coverage | required | . | printf 'TOTAL  1629  16  99.02%%\n'
evidence | coverage | TOTAL
floor    | coverage | 1000
EOF
out="$(gates)"
assert_contains "a digit-class-free regex may still measure" "observed 1629, floor 1000" "$out"
```

RED adds, beyond the verbatim block, what AC-3, AC-4 (plain run) and AC-7
need and `f0ee3e2` did not assert: `assert_not_contains "... All required
gates passed"` on the AC-3 run; the plain-run empty-reason line; the `--list`
line and the `--audit` ok line of AC-7. Four to six more assertions.

**Which of these pass on arrival (RED must say so in the handoff):** the
`observed 0` control, the `no evidence of work` control, and the `observed
1629, floor 1000` control pass on today's tree; they pin existing behaviour and
are earned by DV-3 below. Everything else is red until GREEN: the triage ran
the block verbatim on release 93 and got 4 passed, 7 failed, the seven being
exactly the non-control assertions.

### C-5 - `.claude/tests/profiles.test.sh`

Two parts. The **checker** (`profile_problems`'s awk program) gains, in the
same style as its `slow` and `ondemand` rules:

```awk
    /^[[:space:]]*no-count[[:space:]]*\|/  { id = t($2); nc[id] = 1; ncwhy[id] = rest(3); next }
```

and, in `END`, after the existing orphan lines and the `floor ... has no
evidence line` loop:

```awk
      for (id in nc)   if (!(id in gates)) print "orphan\tno-count names `" id "`, which this profile does not configure"

      # The same refusal gates.sh makes: a floor measured out of a regex that
      # was declared to measure nothing compares against a stopwatch.
      for (id in fl)
        if (id in nc)
          print "floor\tfloor on `" id "` is declared no-count, so there is no count to compare against"

      for (id in nc)
        if (ncwhy[id] == "")
          print "no-count\t`" id "` is marked no-count with no reason"
```

The per-profile `check` list becomes:

```bash
  check orphan         "no evidence, floor, no-count, slow or ondemand line names an unconfigured gate"
  check floor          "every floor has an evidence line, and a count, to measure"
  check no-count       "every no-count line carries a reason"
```

(RED reads the current wording of those lines - upstream's `orphan` line
already names `ondemand` - and extends rather than replaces.)

**The instrument is checked before it is pointed at the profiles**, as the
suite already does for `ondemand` under `describe "the checker recognises an
ondemand line (HARNESS-015, C-5)"`: a fixture profile in `$WORK` carrying
`floor | build | 5` beside `no-count | build | seconds` must yield the `floor`
line; one with `no-count | nope | why` must yield the `orphan` line; one with
`no-count | build |` must yield the `no-count` line; and a fixture with
`floor | unit | 40` on a gate with a real evidence regex and no `no-count` must
yield none of the three. That is AC-8's control, and it is what makes the
per-profile assertions mean something when the profiles are clean.

**Also an AC-8 assertion per profile that the declaration is present**: for
each of the four profiles, the expected gate ids carry a `no-count` line
(`rust-cargo.md`: `lint`, `typecheck`, `build`; the other three: `build`), so
that the checker's "every no-count carries a reason" cannot be satisfied by a
profile carrying none. Without this, deleting the four lines leaves the suite
green.

**Selftest floors** (`.claude/tests/floors.conf`): `gates` is 507, `profiles`
is 102, `sigpipe` is 82. RED raises `gates` and `profiles` to the executed
count it reads off `bash scripts/selftest.sh <suite>` after the new assertions
run (never off call sites); `sigpipe` does not change.

### C-6 - the four profiles, verbatim lines

In each profile's `## Evidence of work` block, directly under the evidence
line(s) they refer to:

`rust-cargo.md` (after the three `Finished` lines, one blank line, then):

    no-count | lint     | `Finished .* profile` is liveness-only; the digits after it are elapsed seconds
    no-count | typecheck| `Finished .* profile` is liveness-only; the digits after it are elapsed seconds
    no-count | build    | `Finished .* profile` is liveness-only; the digits after it are elapsed seconds

`node-typescript.md` (after `evidence | build       | built in [0-9]`):

    no-count | build       | `built in 1.23s` is liveness-only; the digits are elapsed seconds

`python-uv.md` (after `evidence | build     | Successfully built`):

    no-count | build     | `Successfully built foo-0.1.0.tar.gz` is liveness-only; the digits are a version

`web-static.md` (after `evidence | build       | built in`):

    no-count | build       | `built in 1.23s` is liveness-only; the digits are elapsed seconds

Plus, in `rust-cargo.md`, after the "weak on purpose" paragraph (ends `...from
the `unit` gate failing loudly if it is not.`), the paragraph from `f0ee3e2`
beginning "Which is why all three carry a `no-count` line." (quoted in full in
`## Notes`, "Downstream prose to port").

### C-7 - the documentation, by section

Prose is from `f0ee3e2` (`git -C D:/manhwa-cropper show f0ee3e2 -- <path>`),
adapted where this tree has moved on. The adaptations are the whole list;
everything else in that commit's doc hunks is verbatim:

- `.claude/skills/quality-gates/SKILL.md`: in "The gate that shrank", the
  sentence ending `...before anyone commits to a floor.` gains ` - except
  where there is no count to print, which is the next section.`; a new `###
  The regex with no number under it` follows it, before `### The directory
  nobody was testing`; and the numbered "Rules for triage" list gains item 6
  ("Adding a `no-count` line to silence a floor that is failing honestly is
  the same move...") after item 5. Both texts are in `## Notes`.
- `.claude/skills/quality-gates/reference/configuring.md`: the kinds block
  reads "Seven more kinds" here (upstream has `ondemand`, `covers`,
  `blocked-when`, `skipped-when`); it becomes "Eight more kinds" with
  `no-count  | <gate id> | <why its evidence regex measures nothing>` as the
  second line, and the paragraph after it gains the `no-count` clause.
  "Writing an evidence line" gains step 6 ("Look at what sits immediately
  after the match..."). The `-` paragraph gains "Where it proves it ran but
  counts nothing, that is `no-count`, not `-`: liveness still holds and must
  still be asserted." The `--audit` paragraph lists "a floor, no-count or
  slow line it cannot honour".
- `.claude/skills/stack-profiles/reference/new-profile.md`: "These rules are
  enforced" lists `no-count` among the orphan kinds, "every `floor` has an
  evidence line to measure out of and is not on a `no-count` gate", and
  "every `no-count`, `slow` and `ondemand` line carries a reason". "Writing
  the evidence lines": "Two failure modes" becomes "Three failure modes" with
  the "A number that is not a count" bullet between Caching and Flags.
- `.claude/harness/project.conf`: the comment block after the `floor` rules
  (before `# Format:  discovery`) gains the `no-count` format block ("NOT
  EVERY EVIDENCE REGEX HAS A NUMBER UNDER IT...") and the floor rules gain
  the three `no-count` bullets; the evidence-rules bullet list gains "Proving
  liveness and measuring volume are two different jobs..." **without** the
  "In THIS file that is `lint`, `typecheck` and `build`" sentence - this
  repository's gates have no commands and declare nothing. No `no-count`
  line is added to this file's own gate table.
- `README.md`: the paragraph at line 252 ("A `floor` line goes one
  further...") gains the no-count sentences from `f0ee3e2`'s README hunk, and
  the `gates.yml` bullet at line 370 reads "a `floor` with no evidence line or
  on a `no-count` gate, and a `slow` or `no-count` line with no reason or
  naming no gate".

### C-8 - the two line pins in `.claude/tests/sigpipe.test.sh`

`sigpipe.test.sh:567-568` pin, **by line number**, two command substitutions
in `gates.sh` as status-discarded lines (C-5 freshness: a pin whose line no
longer holds the needle fails as a stale fixture, not as a passing exclusion):

    scripts/gates.sh:74:BOOTSTRAPPED="$(grep
    scripts/gates.sh:580:why="could not launch: $(

With C-2 written as given, those lines move to **77** (the header grew by
three) and **617** (three in the header, two in the parser's `case`, ten in
the `work_count` comment, one lookup, one `--list` line, twelve in the reason
block and floor comment, seven in `floor_broken`, one `--audit` ok line:
+37) - *against release 94*. **Recomputed by the Lead PO on 2026-10-13, after
HARNESS-052 landed:** `scripts/gates.sh` is now 1057 lines and the pins today
are `:74` and `:593` (`sigpipe.test.sh:567-568` already say so). C-2 applied
to a scratch copy of today's file with `patch`: all 13 hunks apply, hunks 9-13
at a uniform +13 offset, `bash -n` clean, 1109 lines, and
`grep -n 'could not launch: \$(\|BOOTSTRAPPED="\$(grep'` prints **77** and
**630**. RED writes the two pins
as `scripts/gates.sh:77:` and `scripts/gates.sh:630:` and records in the
handoff that it did; the suite will then fail in RED (stale pin against the
unported file) for the right reason, alongside the gates suite. GREEN
confirms with `grep -n 'could not launch: \$(\|BOOTSTRAPPED="\$(grep'
scripts/gates.sh` before handing off and pastes the two lines into its
report. If GREEN's file lands them elsewhere, that is a stale pin in a test
file GREEN cannot write: the route is a return to RED to move the pin, with a
`## Regressions` entry, exactly as HARNESS-046's notes anticipated for "a
refactor that moves line 580". **If HARNESS-052 has moved these lines by the
time this story starts, RED recomputes:** apply C-2's diff to a scratch copy
of the then-current `scripts/gates.sh` (`patch <copy> <diff>` works on the
normal-format diff above) and read the numbers off `grep -n`.

### C-9 - oracle partition and controls

| AC | Kind | Instruction to RED |
|---|---|---|
| AC-1..AC-7 | mechanical | pin the needles in C-3 exactly; manifests in C-4 are the fixture |
| AC-8 | mechanical | fixture-check the three checker rules before the per-profile loop; pin presence per profile |

Negative controls are in-line in the criteria: the undeclared `observed 0`
(the mechanism), the `TOTAL 1629` floor (declared-not-inferred), the `nothing
to do` run (liveness untouched), and the 5.29s-with-floor-5 manifest (the
defect: passes today with `observed 5, floor 5`).

### C-10 - what the tests must NOT constrain

The exact wording of comments in `gates.sh`; the order of the `--list` and
`--audit` ok lines relative to `ci-factor`/`covers` beyond "after `floor`"; and
the HARNESS-024 AC-3 byte-for-byte `--list` assertion, whose synthetic
manifest carries no `no-count` line and so prints exactly what it printed
before (the new `--list` line is conditional on `is_nocount`).

## Deferred verifications

- **DV-1 - defect put back (the story's central claim). Owner: GATES.**
  Condition: with the no-count floor refusal removed from `gates.sh` - the
  three-line `if [ -z "$floor_broken" ] && [ "$is_nocount" = 0 ]` block
  neutralised - the AC-2/AC-3 fixture (`... in 5.29s`, `floor | lint | 5`,
  declared) **must** go back to passing the audit and printing
  `PASS         lint (0s, observed -, floor 5)` on the run, and exactly the
  four assertions `the audit refuses it`, `and the audit fails`, `the run
  refuses it`, `rather than passing on the clock` must go red; nothing else.
  *(Amended after RED, 2026-10-13: RED's second describe pins the same
  refusal four more times - `the audit's refusal ... names lint and why`,
  `and the audit exits non-zero`, `the run's refusal names lint and why`,
  `and the run does not say the required gates passed` - so the prediction
  is **eight** red, all in the floor-on-no-count fixtures, and nothing
  outside them.)*
  (With the `observed="-"` branch in place the run reports `observed -`
  rather than `observed 5`, and the floor is printed but never compared: a
  declared gate never reaches `work_count`. The stopwatch is still being
  waved through; it is just no longer printed as a number.) RED cannot run
  this: there is no refusal to remove. Run as
  `bash scripts/mutate.sh scripts/gates.sh 's/floor_broken="floor cannot be measured: /floor_broken=""; : "/' -- bash scripts/selftest.sh gates`
  - which turns the assignment into an empty assignment followed by a no-op
  `: "..."` holding the rest of the string, so the file still parses and only
  the refusal is gone. Do not match on `[ "$is_nocount" = 0 ]; then`: the
  `observed="-"` branch ends the same way and would be hit too. Confirm
  `gates` is green again on the restored file, and paste the output here.

- **DV-2 - the rule probed against the real tree, not only fixtures
  (`rules.md`, "A rule is probed against the tree it judges"). Owner: GATES.**
  Condition: with `floor | build | 5` injected into the shipped
  `rust-cargo.md` directly under its `no-count | build` line, `bash
  scripts/selftest.sh profiles` **must** fail the `every floor has an evidence
  line, and a count, to measure` check for `rust-cargo.md`, naming `build`;
  and with the three `no-count` lines deleted from `rust-cargo.md` instead,
  the presence assertion for that profile **must** fail. RED cannot run this
  against the real profile: the lines do not exist yet. Run each as
  `bash scripts/mutate.sh .claude/skills/stack-profiles/reference/rust-cargo.md '<sed expr>' -- bash scripts/selftest.sh profiles`,
  confirm green on the restored file, and paste the output here.

- **DV-3 - earning the three assertions that pass on arrival. Owner: GATES.**
  Condition: with `observed="$(work_count "$log" "$exp")"` replaced by
  `observed=""` in `gates.sh`, the `undeclared, the stopwatch is reported as
  a count` (`observed 0`) and `a digit-class-free regex may still measure`
  (`observed 1629, floor 1000`) assertions **must** go red (the second as
  `floor of 1000 declared, but no number was found`), together with the
  suite's pre-existing `observed 132` and floor assertions; and with the
  defect put back that the third control exists for - a declared gate
  excused from liveness, by guarding the `noevidence` branch with
  `[ "$is_nocount" != 0 ]` - `no-count does not weaken the evidence
  assertion` **must** go red, and it is predicted to be the **only** red
  (no other fixture in the suite declares `no-count` and reaches the run), so
  this is the single-assertion mutation the orchestrator's verification
  ladder prefers. Two mutations, one run each:
  `bash scripts/mutate.sh scripts/gates.sh 's/observed="$(work_count "$log" "$exp")"/observed=""/' -- bash scripts/selftest.sh gates`
  and
  `bash scripts/mutate.sh scripts/gates.sh 's/\[ "$exp" != "-" \] && ! clean_log "$log"/[ "$exp" != "-" ] \&\& [ "$is_nocount" != 0 ] \&\& ! clean_log "$log"/' -- bash scripts/selftest.sh gates`
  (the second matches exactly one line: the `noevidence` elif is the only
  `! clean_log "$log"` in the file). Paste both outputs here, each followed
  by the green re-run on the restored file.

- **DV-4 - earning the two assertions RED found green on arrival that DV-3
  does not cover (PO decision, 2026-10-13; `rules.md`, "one mutation that
  earns each test written against code that already exists"). Owner:
  GATES.** `and liveness still holds` (C-4 #3) passes today because an
  undeclared gate passes; after GREEN it pins that a *declared* gate still
  reaches PASS. `and a declared gate with no floor passes the audit` (RED's
  #14) passes today because the line is ignored. One mutation each, against
  the `gates` suite, as RED proposed and measured on a scratch port
  (22/2 and 23/1 of RED's own blocks):
  `bash scripts/mutate.sh scripts/gates.sh 's/^    observed="-"$/    observed="-"; outcome=noevidence; why="probe: declared gate failed"/' -- bash scripts/selftest.sh gates`
  must turn `and liveness still holds` red (with `declared, the number is
  withheld` beside it, since the same line prints both) and nothing outside
  the declared-gate fixtures; and
  ``bash scripts/mutate.sh scripts/gates.sh '/reports `observed -`; no floor possible/s/$/ \&\& fails=$((fails+1))/' -- bash scripts/selftest.sh gates``
  must turn exactly `and a declared gate with no floor passes the audit` red
  - the single-assertion mutation the orchestrator's verification ladder
  prefers. Paste both outputs here, each with the green re-run on the
  restored file. If the second expression does not match GREEN's exact text
  (it anchors on the `--audit` ok line of C-2), GATES adapts it and says so.

## Amendments

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-055` from `.claude/harness/models.conf`.
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

- RED: `test-developer` on `opus` (claude-opus-5-5, its declared `model:`; no override in the dispatch). Planned `opus`; no change.
- GREEN: `feature-developer` on `opus` (claude-opus-5-5, its declared `model:`; no override). Planned `opus`; no change.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

- **`--no-fail-fast` on the rust profile's `unit` and `coverage` gates**
  (manhwa-cropper `b8ded77`/`b23198c`, MC-057/058): `cargo test --workspace
  --no-fail-fast`, `cargo llvm-cov --workspace --no-fail-fast
  --fail-under-lines 100`, the paragraph explaining that cargo stops at the
  first failing test binary, and the warning that `cargo llvm-cov
  --ignore-run-fail` exits 0 on failing tests and must never sit on a required
  gate. Missing upstream entirely, ~15 lines of `rust-cargo.md`, no mechanism
  in common with this story, and no test demands it (`profiles.test.sh` does
  not pin the cargo gate commands). It is a `chore` of its own, filed
  separately; it touches `rust-cargo.md`, so it runs after this story, not
  beside it.
- **The gate-record ordering change** (`dccbbf6`, "never overwrite a record
  whose `run:` is later than this run's start"): HARNESS-056. The scratch
  `port.diff` that fed this story carried both; only the `no-count` hunks are
  here.
- Inferring `no-count` from the regex. Decided against for the reason in
  Context (`TOTAL`), and the AC-6 control pins the decision.
- Changing the cargo `Finished` regexes, or declaring `no-count` on godot.
- A `no-count` line in **this** repository's `project.conf` gate table: its
  gates have no commands. Only the comment block changes.
- The `.claude/tests/selftest.test.sh:204` comment that still says
  "gates.sh:112 drops any kind it does not recognise" (the line is 155 today
  and 158 after this story). A stale comment in a test file about a different
  mechanism; not this story's.
- Any rewording of existing `gates.test.sh` assertions, and any change to
  `work_count()` itself.

## Design notes

## Test plan

Every criterion is mechanical (C-9): exact substrings and exit statuses of
`scripts/gates.sh` over fixture manifests, and exact problem lines from the
profile checker. Nothing is re-derived and no metric is invented; the needles
are C-3's, and where a bare phrase could be satisfied by its opposite the
assertion carries the gate id and the reason as well.

| Level | Where | What it falsifies |
|---|---|---|
| integration (script over a fixture manifest) | `.claude/tests/gates.test.sh`, two describes after `the count is reported even with no floor` | AC-1..AC-7 |
| unit (the checker over fixture profiles) | `.claude/tests/profiles.test.sh`, `the checker recognises a no-count line (HARNESS-055, AC-8)` | the three new checker rules, and that they do not fire on a counted floor or a clean declaration |
| static (the shipped files) | `.claude/tests/profiles.test.sh`, `the profiles whose evidence regex counts nothing say so` plus the per-profile `check` loop | AC-8 against the four real profiles |
| freshness pin | `.claude/tests/sigpipe.test.sh:567-568` | C-8: the two status-discarded lines in `gates.sh` moved by exactly C-2's growth |

Edges covered: declared with no floor (passes, `observed -`), declared with a
floor (refused at audit and run), declared with an empty reason (refused at
audit and run, command not run), an orphan id beside a live floor, a declared
gate that does no work (liveness untouched), an undeclared stopwatch (the
mechanism, `observed 0`), and a digit-class-free regex with a real count
(`TOTAL`, declared-not-inferred). Out of scope pinned: none beyond AC-6's
"never inferred" control; godot is not asserted either way.

## Handoff: RED -> GREEN

**Model.** RED ran on `opus` (Claude Opus 5.5, `claude-opus-5-5`), as planned;
no override.

### Commands

    bash scripts/selftest.sh gates      # ~25 min on this machine (measured 25m07s, 2026-10-13)
    bash scripts/selftest.sh profiles   # ~3.3 min
    bash scripts/selftest.sh sigpipe    # ~17.5 min
    bash scripts/check-sigpipe.sh       # 0 findings (49 files)
    bash scripts/check-grep-count.sh    # 0 findings (49 files)
    bash scripts/selftest.sh selftest   # 268 passed, 0 failed (the floor tables agree)
    bash scripts/gates.sh --fast        # "All required gates passed (0 ran, 5 unconfigured)": runs nothing here

One suite at a time: the run lock refuses a second harness run in the same
worktree (it refused `gates.sh --fast` while `selftest` ran). All timings
above are LOCAL; none is from CI. No test in this story owns a timeout.

### Failure output, verbatim (RED, 2026-10-13, `gates.sh` unchanged)

`gates` - 19 red, exactly the non-control assertions; nothing else in the
suite went red. Excerpt (the full log is 295 lines; every FAIL line is below,
then the first three failures in full):

```
  no-count: an evidence regex that proves liveness and measures nothing
    FAIL declared, the number is withheld
  no-count: a floor on it is refused
    FAIL the audit refuses it
    FAIL and the audit fails
    FAIL the run refuses it
    FAIL rather than passing on the clock
  no-count: a line that defends nothing is a manifest error
    FAIL no-count without a reason fails the audit
    FAIL no-count naming no gate fails the audit
  no-count: what HARNESS-055 adds beyond the ported block (AC-2, AC-3, AC-4, AC-5, AC-7)
    FAIL --list shows the no-count reason beside the gate
    FAIL --audit's ok block shows the no-count reason
    FAIL the audit's refusal of a floor on a no-count gate names lint and why it was declared
    FAIL and the audit exits non-zero
    FAIL the run's refusal names lint and why it was declared
    FAIL and the run does not say the required gates passed
    FAIL --audit names lint as marked no-count with no reason
    FAIL and that audit exits non-zero
    FAIL on a plain run, no-count without a reason fails the gate
    FAIL and the gate's command is never run
    FAIL the orphan no-count line is named by its misspelt id
    FAIL and that audit exits non-zero
```

```
    FAIL declared, the number is withheld
         expected to contain: observed -
         actual:               
         === gate: lint (required) ===
         printf 'Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.29s\n'
         Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.29s
  no-count: a floor on it is refused
    FAIL the audit refuses it
         expected to contain: declared no-count
         actual:               ok   lint         evidence: Finished .* profile
                           floor:  5
         note         no `covers` lines: gates.sh cannot tell whether a story's changed source
                      paths are exercised by any required gate. Add one per gate, e.g.
                        covers | unit | src/**
         
         Manifest audit passed.
    FAIL the run refuses it
         expected to contain: FAIL         lint
         actual:               
         === gate: lint (required) ===
         printf 'Finished `dev` profile [unoptimized + debuginfo] target(s) in 5.29s\n'
         Finished `dev` profile [unoptimized + debuginfo] target(s) in 5.29s
         
         --- gate summary ---
         PASS         lint (0s, observed 5, floor 5)

gates: 600 passed, 19 failed

assertion floors: all 1 suite(s) met their declared floor (600 assertions executed, 507 declared).
1 of 1 harness suite(s) FAILED.
```

That run was taken before the floor was raised; with `gates 619` the suite is
also 19 below its floor until GREEN. The last failure above is the defect
itself, reproduced: `PASS         lint (0s, observed 5, floor 5)`.

`profiles` - 4 red, the four presence assertions:

```
  the profiles whose evidence regex counts nothing say so (HARNESS-055, AC-8)
    FAIL rust-cargo.md declares no-count on exactly build, lint and typecheck (Finished .* profile is a stopwatch)
         expected: build lint typecheck
         actual:   
    FAIL node-typescript.md declares no-count on exactly build (built in [0-9] is a stopwatch)
         expected: build
         actual:   
    FAIL python-uv.md declares no-count on exactly build (Successfully built is followed by a version)
         expected: build
         actual:   
    FAIL web-static.md declares no-count on exactly build (built in is a stopwatch)
         expected: build
         actual:   

profiles: 112 passed, 4 failed

assertion floors: all 1 suite(s) met their declared floor (112 assertions executed, 102 declared).
1 of 1 harness suite(s) FAILED.
```

(Also before the floor rise; with `profiles 116` it is 4 below until GREEN.)

`sigpipe` - 1 red, the C-8 freshness pin, stale against the unported file:

```
  C-5: the twelve status-discarded lines in this tree are excluded by the rule, not by markers
    FAIL C-5 freshness: all twelve status-discarded lines are still where this suite says they are
         expected: 12 lines, none stale
         actual:   12 lines,
           scripts/gates.sh:77 no longer holds [BOOTSTRAPPED="$(grep] - it holds: 
           scripts/gates.sh:630 no longer holds [why="could not launch: $(] - it holds:         results="$results\nPASS         $id (${dur}s) -- no evidence line: a vacuous pass would go unnoticed"

sigpipe: 81 passed, 1 failed
FAIL sigpipe  did 81 units of work, below the floor of 82 in .claude/tests/floors.conf
```

### What each assertion asserts

`.claude/tests/gates.test.sh`, describes inserted between `the count is
reported even with no floor` and `required_gates: ...`. **R** = red on
arrival; **G** = green on arrival (see the next table for what earns it).

| # | Assertion | Needle / check | AC | Arrival |
|---|---|---|---|---|
| 1 | undeclared, the stopwatch is reported as a count | `observed 0` | AC-1 control | G |
| 2 | declared, the number is withheld | `observed -` | AC-1 | R |
| 3 | and liveness still holds | `PASS         lint` | AC-1 | G |
| 4 | no-count does not weaken the evidence assertion | `no evidence of work` | AC-1 control | G |
| 5 | the audit refuses it | `declared no-count` | AC-2 | R |
| 6 | and the audit fails | `1 manifest problem` | AC-2 | R |
| 7 | the run refuses it | `FAIL         lint` | AC-3 | R |
| 8 | rather than passing on the clock | `declared no-count` | AC-3 | R |
| 9 | no-count without a reason fails the audit | `marked no-count with no reason` | AC-4 | R |
| 10 | no-count naming no gate fails the audit | `names no configured gate` | AC-5 | R |
| 11 | a digit-class-free regex may still measure | `observed 1629, floor 1000` | AC-6 control | G |
| 12 | --list shows the no-count reason beside the gate | `no-count: the digits after it are elapsed seconds, not a count (no floor possible)` | AC-7 | R |
| 13 | --audit's ok block shows the no-count reason | ``no-count: the digits after it are elapsed seconds, not a count (reports `observed -`; no floor possible)`` | AC-7 | R |
| 14 | and a declared gate with no floor passes the audit | rc and the exact line: `0 Manifest audit passed.` | AC-7 | G |
| 15 | the audit's refusal of a floor on a no-count gate names lint and why it was declared | `FAIL lint         floor cannot be measured: lint is declared no-count (the digits after it are elapsed seconds, not a count)` | AC-2 | R |
| 16 | and the audit exits non-zero | rc != 0 | AC-2 | R |
| 17 | the run's refusal names lint and why it was declared | `FAIL         lint (floor cannot be measured: lint is declared no-count (the digits after it are elapsed seconds, not a count))` | AC-3 | R |
| 18 | and the run does not say the required gates passed | absent: `All required gates passed` | AC-3 | R |
| 19 | --audit names lint as marked no-count with no reason | `FAIL lint         marked no-count with no reason; say what its evidence regex measures instead` | AC-4 | R |
| 20 | and that audit exits non-zero | rc != 0 | AC-4 | R |
| 21 | on a plain run, no-count without a reason fails the gate | `FAIL         lint (marked no-count with no reason in project.conf)` | AC-4 | R |
| 22 | and the gate's command is never run | the command touches `.git/h055-nocount-ran`; must be absent | AC-4 | R |
| 23 | the orphan no-count line is named by its misspelt id | ``FAIL lnit         a `no-count` line names no configured gate`` | AC-5 | R |
| 24 | and that audit exits non-zero | rc != 0 | AC-5 | R |

1-11 are C-4's block, byte for byte (the eleven `f0ee3e2` assertions). 12-24
are in a second describe, `no-count: what HARNESS-055 adds beyond the ported
block (AC-2, AC-3, AC-4, AC-5, AC-7)`, rather than interleaved, so the ported
block stays diffable against `f0ee3e2`. That is thirteen extras, not C-4's
"four to six": C-4 named the four that AC-3/4/7 strictly need; I also pinned
each C-3 line with its gate id (so `declared no-count` and `names no
configured gate` cannot be satisfied by some other gate's message) and the
non-zero exit that AC-2, AC-4 and AC-5 each state. Scope unchanged.

`.claude/tests/profiles.test.sh`:

| Assertion | AC | Arrival |
|---|---|---|
| checker: `floor` + `no-count | build | seconds` -> ``floor on `build` is declared no-count, so there is no count to compare against`` (exact, via `ondemand_probs floor`) | AC-8 | G (instrument) |
| checker: `no-count | nope | why` -> ``no-count names `nope`, which this profile does not configure`` (exact, `orphan`) | AC-8 | G (instrument) |
| checker: `no-count | build |` -> ``\`build\` is marked no-count with no reason`` (exact, `no-count`) | AC-8 | G (instrument) |
| control: `floor | unit | 40`, no no-count -> no floor/orphan/no-count line at all | AC-8 control | G (instrument) |
| control: `no-count | build | seconds` with no floor -> no floor/orphan/no-count line at all | AC-8 control | G (instrument) |
| rust-cargo.md declares no-count on exactly `build lint typecheck` | AC-8 | R |
| node-typescript.md declares no-count on exactly `build` | AC-8 | R |
| python-uv.md declares no-count on exactly `build` | AC-8 | R |
| web-static.md declares no-count on exactly `build` | AC-8 | R |
| per profile x5: `check no-count` "every no-count line carries a reason" | AC-8 | G (vacuous until the lines exist) |
| per profile x5: `check orphan` (label now names no-count) and `check floor` (label now "every floor has an evidence line, and a count, to measure") | AC-8 | G (existing assertions, relabelled, now also judging the new rules) |

The checker lives in the test file, so its fixture checks pass in RED: I wrote
the instrument, and it is checked before being pointed at the profiles. They
are not vacuous: before the awk rules existed, the three positive fixtures
would print nothing. The presence assertions are the red part; they are what
stops the per-profile `check no-count` being satisfied by a profile carrying no
line (C-5). I also ran the checker on a scratch copy of `rust-cargo.md` with
C-6's three lines inserted: `nocount_ids` read `build lint typecheck`,
`profile_problems` printed nothing, and with `floor | build | 5` appended it
printed exactly ``floor	floor on `build` is declared no-count, so there is no
count to compare against`` - DV-2's first half, predicted.

`.claude/tests/sigpipe.test.sh:567-568`: pins moved to
`scripts/gates.sh:77:BOOTSTRAPPED="$(grep` and
`scripts/gates.sh:630:why="could not launch: $(` (were `:74`, `:593`). I
re-derived them: C-2 extracted from this story, `patch` on a scratch copy of
today's `gates.sh` (1057 lines) - hunks 9-13 at offset +13, `bash -n` clean,
1109 lines - and `grep -n` printed **77** and **630**, matching the PO's
re-anchoring. **GREEN confirms with**
`grep -n 'could not launch: \$(\|BOOTSTRAPPED="\$(grep' scripts/gates.sh`
and pastes both lines into its report; if they land elsewhere, that is a
return to RED to move the pin (C-8).

### Assertions green on arrival, and what earns each

| Assertion | Earned by | Measured |
|---|---|---|
| 1 `observed 0` | DV-3 mutation 1 (`observed=""`) | not run here (GATES owns it) |
| 4 `no evidence of work` | DV-3 mutation 2 (`noevidence` guarded by `is_nocount != 0`) | not run here |
| 11 `observed 1629, floor 1000` | DV-3 mutation 1 | not run here |
| 3 `and liveness still holds` | **not in DV-3 - an addition.** It passes today because the undeclared gate passes; it pins that a *declared* gate still passes. Probe after GREEN: `bash scripts/mutate.sh scripts/gates.sh 's/^    observed="-"$/    observed="-"; outcome=noevidence; why="probe: declared gate failed"/' -- bash scripts/selftest.sh gates` | on a SCRATCH copy of C-2's port (not the repo file), my block alone: exactly `declared, the number is withheld` and `and liveness still holds` red, 22/2 |
| 14 `and a declared gate with no floor passes the audit` | **not in DV-3 - an addition.** Passes today because the line is ignored. Probe after GREEN: `bash scripts/mutate.sh scripts/gates.sh '/reports `observed -`; no floor possible/s/$/ \&\& fails=$((fails+1))/' -- bash scripts/selftest.sh gates` | on the scratch port: exactly this assertion red, 23/1 |
| profiles: five checker fixtures | the awk rules they check did not exist before this commit; GATES' DV-2 points them at the real file | DV-2 first half predicted on a scratch profile (above) |
| profiles: `check no-count` x5, relabelled `orphan`/`floor` | the four presence assertions (they make the declarations exist), and DV-2 | - |

Rows 3 and 14 need one probe each that the story's DV list does not name. I
recommend GATES add them under DV-3 (one run each, the narrowest command
holding the assertion - the gates suite); they are within `rules.md`'s "one
mutation per test written against code that already exists" budget. I have
not run them against the repository file - it has no port to mutate - and the
scratch numbers above are claims until GATES measures them on the shipped
module.

### Expected values of the controls

No assertion in the new blocks fails at import (they are shell, and they ran),
so unlike a module-missing RED every control above **did execute** in RED.
The table records what each must read after GREEN, and under the DVs.

| Control | Today (measured, RED) | After GREEN (predicted; scratch port measured 24/0) | Under DV-1 (refusal removed) | Under DV-3 m1 (`observed=""`) | Under DV-3 m2 (liveness excused) |
|---|---|---|---|---|---|
| 1 undeclared `observed 0` | pass, `PASS         lint (0s, observed 0)` | pass | pass | **red** | pass |
| 4 `nothing to do` -> `no evidence of work` | pass | pass | pass | pass | **red** (predicted the only red) |
| 11 `TOTAL 1629`, floor 1000 -> `observed 1629, floor 1000` | pass | pass | pass | **red** (`floor of 1000 declared, but no number was found`) | pass |
| AC-2 manifest, plain run | `PASS         lint (0s, observed 5, floor 5)` | `FAIL         lint (floor cannot be measured: lint is declared no-count (...))` | `PASS         lint (0s, observed -, floor 5)`; 5, 6, 7, 8 red (DV-1) and, by my reading, 15, 16, 17, 18 too | - | - |

**DV-1 note for GATES.** DV-1 says "exactly the four assertions ... must go
red; nothing else". My additions 15-18 pin the same refusal (its exact audit
line, the audit's exit, its exact run line, the absent "All required gates
passed"), so with the refusal removed I predict **eight** red, not four: 5, 6,
7, 8, 15, 16, 17, 18. That is the DV's prediction extended by my additions,
not a contradiction of its criterion; GATES should read DV-1's "nothing else"
as "nothing outside the floor-on-no-count fixtures". Not run here.

### What the tests pin, and what they leave alone

Pinned, as fact: the manifest kind is spelled `no-count`, the third field is
the reason (`rest 3`); the C-3 lines exactly as tabled (column widths of
`FAIL %-12s` included - `FAIL lint` + 9 spaces; `FAIL lnit` + 9 spaces;
`FAIL` + 9 spaces + `lint (`); `--list` and `--audit` ok lines as substrings;
`--audit` exits non-zero on each of the three refusals and prints
`Manifest audit passed.` on its own line with exit 0 for a declared gate with
no floor; an empty reason refuses the gate on a plain run **before its command
runs**. Profile checker problem ids `floor`, `orphan`, `no-count` and their
messages are the test file's own (C-5).

Not constrained (C-10): comments in `gates.sh`; where the `--list` / `--audit`
ok lines sit relative to `ci-factor`/`covers` lines; the HARNESS-024
byte-for-byte `--list` golden (its manifest has no `no-count`); the order of
the audit's FAIL lines; anything about godot.

### Files touched

- `.claude/tests/gates.test.sh` (+151: C-4 block and the HARNESS-055 additions)
- `.claude/tests/profiles.test.sh` (checker awk: parse rule, orphan, floor-on-no-count, empty reason; `check` list; two new describes)
- `.claude/tests/sigpipe.test.sh` (two pins, `:74`->`:77`, `:593`->`:630`)
- `.claude/tests/floors.conf` (gates 507->619, profiles 102->116, dated comment)
- `.claude/tests/selftest.test.sh` (mirrored table: same two values; and the
  third copy at `:564-565`, `profiles is floored at its 116 executed
  assertions`, which the first selftest run caught: `expected: 102 / actual:
  116`, `selftest: 267 passed, 1 failed`. After the fix: `selftest: 268
  passed, 0 failed`. The `profiles` floor is recorded THREE times, not two.)
- this story (`## Test plan`, this handoff)

### Floors

`gates` 507 -> **619** and `profiles` 102 -> **116**, each the EXECUTED count
(passed + failed) read off `bash scripts/selftest.sh <suite>` on this tree:
`gates: 600 passed, 19 failed`, `profiles: 112 passed, 4 failed`. Note that
only 24 of the `gates` rise are this story's: the suite already executed 595
against a floor of 507 (C-5's "gates is 507" is the floor, not the count).
`sigpipe` stays 82. Floors count passes, so until GREEN lands `gates` sits 19
below, `profiles` 4 below and `sigpipe` 1 below their floors.

### For GREEN

- Apply C-2 with `patch`; it applies to today's file (hunks 9-13 at +13). The
  scratch port passed all 24 `gates` assertions in this story's blocks
  (`scratch: 24 passed, 0 failed`); that is my block run against a scratch
  fixture, not the full suite.
- C-6's four profiles must carry the `no-count` lines so that `nocount_ids`
  reads exactly `build lint typecheck` (rust-cargo) / `build` (others). A
  `no-count` line in the profile's prose at the start of a line (after
  whitespace) would be read as a declaration: keep the prose mentions inline.
- The AC-4 plain-run test writes `.git/h055-nocount-ran` in the fixture; it
  is outside the work tree on purpose (an untracked file would trip
  HARNESS-014's untracked-file refusal in later blocks).

## Regressions

## Gate results

## Gate probes

<!-- This story changes `--audit`'s manifest rules rather than a gate command
     or an evidence line. The "watch it fail" obligation for the new refusals
     is discharged by the AC-2..AC-5 fixtures (each is a manifest the audit
     must refuse) and by DV-1/DV-2 against the real tree; GATES records those
     there. If GATES judges a `## Gate probes` block is owed as well, it says
     which probe lives here and which in DV, rather than letting one result
     live in two places. -->

## Notes

**Provenance.** Port of manhwa-cropper commit `f0ee3e2f32036575f966c3a380fb011e314287dc`
(2026-09-15, "harness: refuse a floor on a gate whose evidence regex has no
count"; 12 files, +307/-35; downstream selftest at the time 8 suites, 324
assertions). Read with `git -C D:/manhwa-cropper show f0ee3e2`. The commit
message records the field reading that motivated it (MC-026: `typecheck`
observed 0, `lint` 2 then 6 across runs of an unchanged tree, `build` 1 from
`in 1m 22s`) and that its assertions were earned by mutation there, one
mutation and one revert each.

**What is project-only in the downstream tree and what is not.** Only the
`f0ee3e2`, `b8ded77` and `b23198c` content is manhwa-cropper's own. Every
other difference between `D:/manhwa-cropper/.claude/...` and this tree is
upstream being newer (ondemand, covers, blocked-when, skipped-when, the awk
parser of HARNESS-024, the field helpers) and must **not** be ported back.
GREEN takes the diff in C-2, not the downstream file.

**Triage record (2026-10-11, orchestrator, release 93).** `f0ee3e2`'s eleven
assertions were run verbatim against this tree through a throwaway
`triage.test.sh` (`ONLY_PART=f0ee`): 4 passed, 7 failed, the seven being the
non-control assertions listed in Context. The same eleven against a prototype
port of the `gates.sh` hunks: 11 passed, 0 failed, with the observed outputs

    FAIL lint         floor cannot be measured: lint is declared no-count (the digits after it are elapsed seconds, not a count)
    1 manifest problem
    FAIL         lint (floor cannot be measured: lint is declared no-count (the digits after it are elapsed seconds, not a count))

The full upstream `gates.test.sh` with the prototype port applied (plus the
HARNESS-056 record-ordering port, which touches none of these paths):
`gates: 507 passed, 0 failed` in 47m36s wall on this machine. The scratch
directory holding that run is gone; C-2 is the no-count portion of that port
re-derived against release 94 and syntax-checked (`bash -n`), with the
comment blocks from `f0ee3e2` added so that the line pins in C-8 are
determinate.

**How the C-8 numbers were computed.** `scripts/gates.sh` at release 94 is
1027 lines, identical to the triage's `gates.sh.orig` (`cmp` clean). Applying
C-2 to a scratch copy with `patch` and adding the comment hunks gives 1079
lines, `BOOTSTRAPPED="$(grep` on line 77 and `why="could not launch: $(` on
line 617. The method is in C-8 so RED can redo it if HARNESS-052 lands first.

**Downstream prose to port** (verbatim from `f0ee3e2`, for C-6 and C-7; the
rest of the prose is short enough to take from the commit directly).

`rust-cargo.md`, after the "weak on purpose" paragraph:

    Which is why all three carry a `no-count` line. The count `gates.sh` reads is
    the first run of digits at or after the evidence match, and cargo's line is

        Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.29s

    so that number is the **elapsed time**. Read off a real cargo workspace:
    `typecheck` reported `observed 0`, `lint` `2` then `6` across runs of an
    unchanged tree, `build` `1` (from `in 1m 22s`). Harmless while it is only printed,
    and a coin-toss gate the moment somebody adds `floor | lint | 5` in good faith.
    The `no-count` lines make `gates.sh` print `observed -` instead and refuse that
    floor outright. There is no regex that fixes this — cargo prints no count on a
    warm cache, which is the same fact that makes the regexes weak to begin with.

`quality-gates/SKILL.md`, the new section:

    ### The regex with no number under it

    Proving a gate ran and measuring how much it did are two different jobs, and
    one regex is asked to do both. Some regexes can only do the first, and the
    number printed under them is not a count of anything:

        evidence | lint | Finished .* profile
        no-count | lint | `Finished .* profile` is liveness-only; the digits are seconds

    Cargo's line is ``Finished `dev` profile [unoptimized + debuginfo] target(s) in
    0.29s``, so the digits `work_count` finds are the **elapsed time**. A floor of
    5 there passes or fails on how warm the build cache is, and in `project.conf`
    it looks exactly like the floor on `unit`. A `no-count` line says the regex
    measures nothing: the gate then reports `observed -` rather than a number, and
    any floor on it is refused, under `--audit` and on a real run alike. Liveness
    is untouched — the regex must still match, or the gate still fails with `ran
    but produced no evidence of work`.

    It is declared rather than detected because it cannot be detected. "The regex
    has no digit class" is the obvious test and it is wrong both ways:
    `Finished .* profile` has none and matches a stopwatch, while `TOTAL` has none
    and is followed by a genuine region count a floor may use. The reason is
    required, and `--audit` refuses a `no-count` naming a gate that does not exist
    — a typo there leaves the gate open to exactly the floor it meant to prevent.

`quality-gates/SKILL.md`, triage rule 6:

    6. Adding a `no-count` line to silence a floor that is failing honestly is the
       same move. The line is a statement about what the regex can measure, not an
       escape hatch: if the gate really did less work, that is the floor doing its
       job. Adding one is only correct where the number never meant anything, and
       the story that adds it shows the output it read.

`new-profile.md`, the third failure mode:

    - **A number that is not a count.** `gates.sh` reads the first run of digits at
      or after the evidence match as the gate's work count, and cannot tell a count
      from a clock. ``Finished `dev` profile ... in 0.29s`` and `built in 1.23s`
      both yield elapsed seconds; `Successfully built foo-0.1.0.tar.gz` yields a
      version. That is usually the *same* gate the caching note just forced you to
      weaken, so expect them together. Add a `no-count` line with the reason: the
      gate then reports `observed -` and `--audit` refuses any floor on it. Say it
      explicitly even when it seems obvious — the whole hazard is that a stopwatch
      in the summary is indistinguishable from a count.

`project.conf`, the format block (goes after the `floor` example and before
the floor `Rules:`):

    # NOT EVERY EVIDENCE REGEX HAS A NUMBER UNDER IT, and the ones that do not are
    # the trap. `Finished .* profile` - the regex the rust profile's `lint`,
    # `typecheck` and `build` use - proves cargo ran and measures nothing: the
    # digits that follow it are the ELAPSED TIME. A floor of 5 on `lint` would
    # therefore pass or fail on how warm the build cache is, and it would look,
    # in this file, exactly like the floor on `unit`.
    #
    # Format:  no-count | <gate id> | <why its evidence regex measures nothing>
    #
    # So a gate whose evidence regex is liveness-only says so out loud. gates.sh
    # then reports `observed -` for it instead of a meaningless number, and refuses
    # any floor declared on it - at audit time and at run time both.
    #
    #   no-count | lint | `Finished .* profile` is liveness-only; the digits are seconds
    #
    # This is declared and not inferred because it cannot be inferred. "The regex
    # contains no digit class" is the obvious test and it is wrong in both
    # directions: `Finished .* profile` has none and matches a stopwatch, while
    # `TOTAL` also has none and is followed by a real region count that a floor
    # could legitimately use.

and the three bullets added to the floor `Rules:` (the first replaces the
`observed <n>` bullet's ending):

    #   - Every full run prints `observed <n>` for any gate with an evidence line,
    #     floor or not, so the number is visible before anyone commits to one -
    #     except a `no-count` gate, which prints `observed -`.
    #   - The reason on a `no-count` line is required, and `gates.sh --audit`
    #     refuses a line without one, or one naming a gate that does not exist.
    #     A misspelt id defends nothing while looking like it does.
    #   - Removing a `no-count` line is a claim that the regex now measures
    #     something. Show the count in the story that removes it.

**Filed 2026-10-12** by the Lead PO from the 2026-10-11 triage, one of six
stories planned in parallel (HARNESS-052..057) on
`harness/HARNESS-052-057-plan`; `docs/backlog/epics/` is empty, so `epic:` is
blank. `bash scripts/plan.sh conflicts` at PLANNED: HARNESS-052 and
HARNESS-056 both declare `scripts/gates.sh`; resolved by `depends_on` on 052
(shared pins) and by backlog order for 056, not by running beside either.

### RED verification (orchestrator, 2026-10-13)

RED dispatched to `test-developer`; it reported running on `opus`. Its diff
was read in full: C-4's eleven assertions verbatim plus thirteen more pinning
C-3's exact lines with the gate id and the audit exit statuses
(`gates.test.sh`, +151); the three checker rules, five fixture checks (two
controls) and four per-profile presence assertions (`profiles.test.sh`,
+73); the two C-8 pins at `:77` and `:630`; floors gates 507 -> 619 and
profiles 102 -> 116 in both tables (a third copy at `selftest.test.sh:564`
it found and updated). Nothing outside test files and this story.

Orchestrator's own runs against the unported `gates.sh` and profiles:

    $ bash scripts/selftest.sh profiles
    FAIL rust-cargo.md declares no-count on exactly build, lint and typecheck (...)
    FAIL node-typescript.md declares no-count on exactly build (...)
    FAIL python-uv.md declares no-count on exactly build (...)
    FAIL web-static.md declares no-count on exactly build (...)
    profiles: 112 passed, 4 failed
    FAIL profiles  did 112 units of work, below the floor of 116
    real 0m33s

    $ bash scripts/selftest.sh sigpipe
    FAIL C-5 freshness: all twelve status-discarded lines are still where this suite says they are
    sigpipe: 81 passed, 1 failed
    FAIL sigpipe  did 81 units of work, below the floor of 82
    real 5m5s

    $ bash scripts/selftest.sh gates
    (19 FAIL lines: the 8 non-control assertions of C-4's block and the 11
     of the second describe - every one of them a `no-count` behaviour)
    gates: 600 passed, 19 failed
    FAIL gates  did 600 units of work, below the floor of 619
    real 17m36s

Right failure, in each: the reds are exactly the behaviours GREEN supplies
(the no-count mechanism, the four profile declarations, the two moved pins),
and the three C-4 controls plus `and liveness still holds` are green as the
Contract predicted. Floors count passes, so each suite also sits below its
new floor by the same count until GREEN. `gates.sh --fast` runs nothing here.

**PO decision 2 (2026-10-13).** RED found two assertions green on arrival
that DV-3 does not earn and proposed one probe each; adopted as DV-4 (owner
GATES) rather than left to `/audit-mutations`, because `rules.md` owes one
mutation per test that passes against existing code. RED's "exactly four"
reading of DV-1 is corrected there to eight, since its additions pin the
same refusal; GATES reads DV-1's "nothing else" as "nothing outside the
floor-on-no-count fixtures".

    $ bash scripts/selftest.sh selftest
    selftest: 268 passed, 0 failed
    $ bash scripts/check-sigpipe.sh
    check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
    $ bash scripts/check-grep-count.sh
    check-grep-count: scanned 49 shell file(s), 0 finding(s)

### GREEN verification (orchestrator, 2026-10-13)

The feature-developer's diff was read in full. `scripts/gates.sh`: every
hunk is C-2's text (+62/-10), the `--list` line sits inside the
`if [ "$LIST" = 1 ]` block and the `nocountwhy` lookup beside `cifactor=`;
`grep -n` prints the pins at `77` and `630`. The four profiles carry C-6's
lines verbatim and `rust-cargo.md` the "Which is why all three carry a
`no-count` line" paragraph; `project.conf` changed comments only (no
`no-count` line in this repository's gate table); `configuring.md` says
"Eight more kinds"; README's `gates.yml` bullet names the no-count floor.

**Finding worth keeping (the feature-developer's, confirmed by reading the
diff).** C-2 is a normal-format diff, and its two pure-insertion hunks (7,
the lookup; 8, the `--list` printf) carry no context, so `patch` placed them
by stale line number after HARNESS-052's +30: the lookup landed inside the
`--fast` comment block and the `--list` line outside the `LIST` block, where
it would have printed on every run. `bash -n` and the line count - the PO's
and RED's scratch checks - cannot see a misplaced insertion. The developer
moved both by hand to where C-1/C-10 put them; the line count (1109) and
the pins are unchanged. Lesson for the next port: check `a`-hunk placement,
or carry context (`diff -u`).

Orchestrator's own runs against the shipped tree:

    $ bash scripts/selftest.sh profiles
    profiles: 116 passed, 0 failed  (floor 116 met)   real 0m55s
    $ bash scripts/selftest.sh sigpipe
    sigpipe: 82 passed, 0 failed    (floor 82 met)    real 6m30s
    $ bash scripts/selftest.sh gates
    gates: 619 passed, 0 failed     (floor 619 met)   real 12m56s
    $ bash scripts/gates.sh --audit
    Manifest audit passed.
    $ bash scripts/gates.sh --fast
    All required gates passed (0 ran, 5 unconfigured, 0 known).

Every control landed on its "expected after GREEN" value; the feature-
developer also measured each directly against the shipped `gates.sh`
(`observed 0` undeclared, `observed -` declared, `no evidence of work` on
`nothing to do`, `observed 1629, floor 1000`, the exact C-3 refusal lines,
no `All required gates passed` on the AC-3 run) and the table in its report
matched the handoff with no divergence. The DV columns are GATES' to measure.
