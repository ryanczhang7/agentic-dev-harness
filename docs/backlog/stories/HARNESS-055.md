---
id: HARNESS-055
title: A gate can declare that its evidence line carries no count, and a floor on it is refused
slug: a-gate-can-declare-that-its-evidence-lin
epic: 
type: feature
status: todo
phase: PLANNED
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
+37). RED writes the two pins
as `scripts/gates.sh:77:` and `scripts/gates.sh:617:` and records in the
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

## Handoff: RED -> GREEN

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
