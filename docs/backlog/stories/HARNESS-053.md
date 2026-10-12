---
id: HARNESS-053
title: The phase lock judges a quoted file name containing parentheses, instead of letting the write through
slug: the-phase-lock-judges-a-quoted-file-name
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-053-the-phase-lock-judges-a-quoted-file-name
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/hooks/lib.sh, .claude/tests/phase-guard.test.sh, .claude/tests/lib.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

A port of the first half of manhwa-cropper commit `0937c76` ("Fix two defects
in the phase guard's write-target extraction", 2026-09-10;
`git -C D:/manhwa-cropper show 0937c76`). Triaged 2026-10-11 against upstream
release 93; `.claude/hooks/lib.sh` is unchanged in release 94, and the
triage's `up/` copy of it is byte-identical to this tree's. The second half of
that commit - the `sed -i` operand walk - is already upstream as
`write_candidates` / `_WC_AWK` and is not this story (see `## Out of scope`).
Upstream must carry this before manhwa-cropper's harness is refreshed, or the
refresh overwrites the downstream fix (memory: "port before refresh").

**The defect.** `mask_shell_quotes` (`.claude/hooks/lib.sh:104`) turns every
operator inside a quoted, escaped or heredoc span into a control character so
the extractors see structure and not data. It masks `| & ; > < SP TAB LF` and
leaves `(` and `)` alone. Every extractor treats a paren as a terminator,
because a subshell's paren really does end a target, so a paren inside a
*quoted* file name survives masking as syntax and either truncates the
candidate or leaks into it. Two consequences, both observed on this tree:

- **A hole (fail-open).** For `rm`, `touch`, `tee` and the destination of
  `mv`, the candidate is the whole masked token, e.g. `src/x\006(1).ts`.
  `path_is_implausible` (`lib.sh:933`) sees a literal `(` and - correctly, by
  its own rule - declines the write as a leaked parse: allowed, only logged.
  A write to a frozen source file whose quoted name contains a paren is
  never examined.
- **A truncation (wrong path).** The redirect extractor's class
  `[^|&;><()[:space:]]+` stops at the paren, so `echo x > 'src/my (1).ts'` is
  judged on `src/my ` (with a trailing space) and
  `echo x > 'docs/my (1).md'` is allowed only because `docs/my ` happens to
  classify as docs. The backslash-escaped form `rm src/x\ \(1\).ts` is
  blocked on `src/x`.

**Reproduced on this tree.** The triage's `paren.test.sh` (14 cases; the
cases are the Contract's C-2, verbatim) against unpatched upstream:

```
  RED: a paren inside a quoted argument is data (0937c76 cases)
    ok   allows: sed -i -e with parens in the script, writing a test
    ok   allows: sed -i with parens in the script, writing a test
    ok   allows: cp from a quoted name containing parens, writing docs
    ok   blocks: sed -i -e with parens, writing source
    ok   blocks: sed -i with parens, writing source
    FAIL blocks: quoted target containing parens
         blocked, but on the wrong path (wanted 'src/my (1).ts'): BLOCKED by the harness phase lock.    story:    T-1   phase:    RED   path:     src/my    category: source  [...]
    FAIL blocks: rm of a quoted name containing parens
         not blocked at all

  RED: extra coverage, same defect through every extractor
    FAIL blocks: touch of a quoted name containing parens
         not blocked at all
    FAIL blocks: tee into a quoted name containing parens
         not blocked at all
    FAIL blocks: mv onto a quoted name containing parens
         not blocked at all
    FAIL blocks: rm of a backslash-escaped name containing parens
         blocked, but on the wrong path (wanted 'src/x (1).ts'): BLOCKED by the harness phase lock.    story:    T-1   phase:    RED   path:     src/x    category: source  [...]
    ok   allows: quoted docs target containing parens
    ok   blocks: control: an unquoted subshell paren still terminates
    ok   allows: control: parens and arrow inside a quoted command substitution

paren: 8 passed, 6 failed
```

With the downstream fix applied to a copy of this tree (C-1), the same file
reports `paren: 14 passed, 0 failed`, and the full suites on that copy were
`phase-guard: 369 passed, 0 failed`, `lib: 281 passed, 0 failed`,
`sigpipe: 82 passed, 0 failed`, `grep-count: 20 passed, 0 failed`.
`check-sigpipe.sh` and `check-grep-count.sh` over the real tree printed the
same two lines before and after
(`check-sigpipe: scanned 51 shell file(s), 47 with pipefail, 0 finding(s)`;
`check-grep-count: scanned 51 shell file(s), 0 finding(s)`). That matters
because `mask_shell_quotes` has consumers beyond the guard: `masked_lines`
(`lib.sh:304`) feeds both tree-wide guards, so this story changes a rule over
the tree's own commands, and DV-2 is its real-tree probe.

**Why both halves of the lock.** A lock with false positives teaches the
agent that blocks are noise (the truncation half); a lock with holes is not a
lock (the fail-open half). The fix is two `maskchar` lines and the matching
`tr` set; the value is the regression block that pins every extractor.

Required gate that fails if this story's artifact broke: `selftest`, through
`.claude/tests/phase-guard.test.sh` (`bash scripts/selftest.sh phase-guard`)
and `.claude/tests/lib.test.sh` (`bash scripts/selftest.sh lib`).

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC. -->

All ACs are judged through the guard the way the suite already does it:
`assert_blocked`/`assert_allowed` from `.claude/tests/_lib.sh` on a
`make_fixture` tree with the story in RED, where `src/**` is frozen source
and `docs/**` is writable. "Blocked on `<path>`" means the denial's
`path:` field is exactly `<path>`, whole, as `assert_blocked` asserts.

- **AC-1 (a quoted redirect target is judged whole)** - Given RED, when the
  command is `echo x > 'src/my (1).ts'`, then it is blocked on
  `src/my (1).ts`. *(Today: blocked on `src/my `.)*
- **AC-2 (a quoted name is not declined as a leaked parse)** - Given RED,
  when the command is any of `rm 'src/x (1).ts'`, `touch 'src/x (1).ts'`,
  `echo x | tee 'src/t (1).ts'` or `mv docs/notes.md 'src/m (1).ts'`, then
  it is blocked on, respectively, `src/x (1).ts`, `src/x (1).ts`,
  `src/t (1).ts`, `src/m (1).ts`. *(Today: none of the four is blocked at
  all; each candidate is declined by `path_is_implausible`.)*
- **AC-3 (a backslash-escaped paren is data too)** - Given RED, when the
  command is `rm src/x\ \(1\).ts`, then it is blocked on `src/x (1).ts`.
  *(Today: blocked on `src/x`.)*
- **AC-4 (nothing that was right becomes wrong)** - Given RED:
  `echo x > 'docs/my (1).md'` is allowed; `cp 'src/a (1).ts' docs/notes.md`
  is allowed; `git commit -m "$(printf '%s' 'a (b) > c')"` is allowed; and
  `(echo x > src/main.ts)` is still blocked on `src/main.ts` (an unquoted
  paren is still a subshell; this one is already pinned at
  `phase-guard.test.sh:509` and is not re-added). *(All true today; the
  first two by accident - see C-2.)*
- **AC-5 (the masker itself)** - Given the text `rm 'src/x (1).ts'`, when
  it is passed through `mask_shell_quotes`, then the output contains no
  literal `(` and no literal `)`; and when that output is passed through
  `unmask_shell_quotes`, the result is the input, byte for byte. *(Today the
  first half fails: both parens survive masking.)*

Oracle partition: every criterion is **mechanical** - an exact path in a
denial, an exact masked/unmasked string. Nothing is invented or calibrated.
The fix (C-1) is **settled**: read it out of the downstream commit, do not
redesign it.

## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. -->

**Writes:** `.claude/hooks/lib.sh`, `.claude/tests/phase-guard.test.sh`, `.claude/tests/lib.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

`lib.sh` classifies as `harness` and the four test-side files as `test` or
`harness` (`bash scripts/classify.sh`); the phase lock freezes none of them
in RED or GREEN, so the role boundary is honoured by the agents: RED writes
the three test files and the floors, GREEN writes `lib.sh` only. No existing
export changes signature - `mask_shell_quotes` and `unmask_shell_quotes` keep
their names and their stdin-to-stdout shape - so there is no caller list; the
consumers that matter are named in C-4 because the *mapping* they rely on
widens.

**RED may amend any block below in place, with a reason; GREEN builds what
the amended block says.**

- **C-1 The fix (settled - read out, never re-derived).** Identical to
  downstream `0937c76`'s `lib.sh` hunk, applied to this tree's
  `mask_shell_quotes` / `unmask_shell_quotes`. Three edits and nothing else:

  1. In `maskchar`, after the TAB line (`lib.sh:113`):

         if (c == "\t") return "\007"
     +   if (c == "(")  return "\016"
     +   if (c == ")")  return "\017"

  2. `unmask_shell_quotes` (`lib.sh:240`):

     -   tr '\001\002\003\004\005\006\007\010' '|&;>< \t\n'
     +   tr '\001\002\003\004\005\006\007\010\016\017' '|&;>< \t\n()'

  3. The mapping table in the comment above `mask_shell_quotes`
     (`lib.sh:98-99`) gains `( -> \016   ) -> \017`, and one sentence saying
     why not `\013`/`\014`: VT and FF are POSIX `[[:space:]]`, so the
     redirect and tee extractors' character classes would eat them and the
     target would truncate in exactly the old place - which is also why SP
     and TAB are `\006`/`\007`. A mask character has to be inert to every
     character class the extractors use, not merely unusual.

  `maskchar` is called from every masked state (single, double, subst,
  heredoc body, backslash escape, comment), so one pair of lines covers
  AC-1..AC-3 through every extractor. In the `subst` state the depth
  check on `(`/`)` runs *before* `maskchar`, so the paren that closes
  `$( ... )` is still emitted literally and the one inside `'a (b) > c'`
  is masked - AC-4's third case pins that.

- **C-2 The regression block in `phase-guard.test.sh`.** One `describe`
  block, appended after the HARNESS-045 blocks (the file's last section),
  headed `HARNESS-053: a paren inside a quoted argument is data (0937c76)`,
  under `set_phase "$FIX" RED`. Exactly these nine assertions, each label
  prefixed `HARNESS-053 AC-n:`; the commands and expected paths are the
  triage file's, verbatim:

      assert_blocked "$FIX" "echo x > 'src/my (1).ts'" 'src/my (1).ts' '... AC-1: quoted redirect target containing parens'
      assert_blocked "$FIX" "rm 'src/x (1).ts'" 'src/x (1).ts' '... AC-2: rm of a quoted name containing parens'
      assert_blocked "$FIX" "touch 'src/x (1).ts'" 'src/x (1).ts' '... AC-2: touch of a quoted name containing parens'
      assert_blocked "$FIX" "echo x | tee 'src/t (1).ts'" 'src/t (1).ts' '... AC-2: tee into a quoted name containing parens'
      assert_blocked "$FIX" "mv docs/notes.md 'src/m (1).ts'" 'src/m (1).ts' '... AC-2: mv onto a quoted name containing parens'
      assert_blocked "$FIX" 'rm src/x\ \(1\).ts' 'src/x (1).ts' '... AC-3: rm of a backslash-escaped name containing parens'
      assert_allowed "$FIX" "echo x > 'docs/my (1).md'" '... AC-4: quoted docs target containing parens'
      assert_allowed "$FIX" "cp 'src/a (1).ts' docs/notes.md" '... AC-4: cp from a quoted name containing parens, writing docs'
      assert_allowed "$FIX" "git commit -m \"\$(printf '%s' 'a (b) > c')\"" '... AC-4: parens and arrow inside a quoted command substitution'

  Six are red today (the RED handoff pastes exactly the six `FAIL` lines of
  the Context's run, with their reported wrong path or `not blocked at
  all`). Three are **green on arrival** and are false-positive controls: no
  mutation in this story's budget turns them red (under DV-1(a) the docs
  target is allowed by accident and the cp destination is unaffected; under
  DV-1(b) a mis-restored `docs/my \016 1\017.md` still classifies as docs).
  They are kept because the fix widens masking and these are the shapes
  that would show over-masking; earning them is `/audit-mutations` work and
  is said so here rather than claimed. **Keep the block to these nine.** Each
  guard assertion costs 8-15 s on this Windows host and the full
  phase-guard suite took 48 minutes in triage; do not add the two `sed -i`
  paren cases from the triage file (they pass on upstream's operand walk,
  which this story does not touch - `## Out of scope`) or the subshell
  control (already at line 509).

- **C-3 The masker assertions in `lib.test.sh`.** Two `assert_eq` lines
  appended to the existing
  `describe "mask_shell_quotes: operators inside quotes stop being
  operators"` block (`lib.test.sh:108`), using its `mask` and `roundtrip`
  helpers (`lib.test.sh:111-112`):
  - AC-5a, red today: the masked text of `rm 'src/x (1).ts'` contains no
    `(` and no `)` - assert with the block's existing one-awk shape, not
    `grep -q` (the block's own comment says why).
  - AC-5b, green today and earned by DV-1(b): `roundtrip "rm 'src/x (1).ts'"`
    equals `rm 'src/x (1).ts'`.
  `path_is_implausible` is **not** changed: `'a(b)'` stays implausible
  (`lib.test.sh:575`), because after this fix a literal paren in a candidate
  can only mean the parse leaked syntax.

- **C-4 Consumers of the mapping, and why DV-2 exists.** `mask_shell_quotes`
  output reaches: `phase-guard.sh:145` (the guard, unmasked at `:211`),
  `write_candidates` (`lib.sh:1020` unmasks), `masked_lines` (`lib.sh:304`),
  and through it `scripts/check-sigpipe.sh:314` and
  `scripts/check-grep-count.sh:300`. Neither tree-wide guard unmasks, and
  both run over every harness shell file - so a paren inside a quoted span
  in a real script (an awk program, a `printf` format) now arrives as
  `\016`/`\017`. The triage measured no change in their findings over the
  real tree; DV-2 re-measures it on the committed fix.

- **C-5 Floors.** `.claude/tests/floors.conf` has `phase-guard | 369` and
  `lib | 281`, mirrored in `.claude/tests/selftest.test.sh` (`:537`, `:541`,
  and the `lib is floored at its 281 executed assertions` case at `:566`).
  RED adds 9 to phase-guard and 2 to lib, raises both floors by the measured
  executed count (`passed + failed` on RED's own summary lines - expected
  `phase-guard: 372 passed, 6 failed` = 378 and `lib: 282 passed, 1 failed`
  = 283), and changes both files in the same commit, or neither. Never
  lowered.

- **C-6 Oracle partition.** Every criterion is mechanical; C-1 is settled.
  The six expected failure lines in the Context are **baseline
  measurements** RED may read out (measured 2026-10-11 on a copy of this
  tree at release 93, `lib.sh` identical to HEAD).

- **C-7 Test-only dependencies.** None. Bash, awk, sed, tr, grep
  (`rules.md`, "Portability"). No manifest in this repository.

- **C-8 How to run the new block cheaply.** `bash scripts/selftest.sh
  phase-guard` is the gate's view and the only one the handoff may quote
  for the floor; for iteration, a scratch file under the gitignored
  `.claude/state/` that sources `.claude/tests/_lib.sh`, does
  `FIX="$(make_fixture)"; set_phase "$FIX" RED`, and holds only the nine
  assertions runs in under three minutes (that is what the triage did). A
  slice is for iteration and for the DV runs below; the recorded floor
  comes from the whole suite.

## Deferred verifications

- **DV-1 - defect put back (the story's central claim). Owner: GATES.**
  Condition, two halves, each run against the narrowest suite holding the
  assertion and each through `scripts/mutate.sh` so the restore is
  verified:
  - (a) With the two added `maskchar` lines deleted from the committed
    `lib.sh` -
    `bash scripts/mutate.sh .claude/hooks/lib.sh '/if (c == "[()]")  return/d' -- bash scripts/selftest.sh lib`
    (verified at PLANNED on the patched copy: deletes exactly those two
    lines and nothing else - a looser `/c == "[()]"/d` also deletes the two
    depth-counting lines in the `subst` state and breaks the awk program)
    then the same expression with `-- bash scripts/selftest.sh phase-guard`
    (or the C-8 slice, saying so) - AC-5a **must** go red in lib, and in
    phase-guard exactly the six `assert_blocked` cases of C-2 **must** go
    red with the Context's wrong paths or `not blocked at all`, while the
    three `assert_allowed` controls stay green.
  - (b) With `unmask_shell_quotes` reverted to the old `tr` set -
    `bash scripts/mutate.sh .claude/hooks/lib.sh '/^  tr /{s/\\016\\017//; s/()//}' -- bash scripts/selftest.sh lib`
    (verified at PLANNED on the patched copy: changes only the `tr` line,
    to exactly today's `tr '\001\002\003\004\005\006\007\010' '|&;>< \t\n'`)
    - AC-5b's round trip **must** go red (parens come back as
    `\016`/`\017`), and in phase-guard AC-1..AC-3 **must** report
    `blocked, but on the wrong path`.
  RED cannot run this: the lines to delete do not exist yet. Confirm both
  suites green on the restored file, run `bash scripts/mutate.sh --check`,
  and paste the output here.

- **DV-2 - real-tree probe: the two tree-wide guards built on
  `masked_lines` are unchanged by the wider mask. Owner: GATES.** Condition:
  on the committed fix, `bash scripts/check-sigpipe.sh` and
  `bash scripts/check-grep-count.sh` each exit 0 and print the same census
  line as on `main` (triage, 2026-10-11, both trees:
  `check-sigpipe: scanned 51 shell file(s), 47 with pipefail, 0 finding(s)`
  and `check-grep-count: scanned 51 shell file(s), 0 finding(s)`; the file
  count may differ if `main` moved, the finding count may not), **and** the
  mutation DV-1(a) does not change either guard's output - which is the
  probe against a real line of the tree `rules.md` asks for when a rule
  over the tree changes: if a quoted paren in a real script ever carried
  weight in either guard, masking it would move a finding. Paste all four
  census lines (before, after, and under the DV-1(a) mutation for each).

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. Omit the
     section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-053` from `.claude/harness/models.conf`.
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

- **The `sed -i` operand walk** - the second defect of `0937c76`. Upstream
  already has it (`write_candidates` / `_WC_AWK`): `sed -i s/a/b/
  src/main.ts docs/notes.md` is judged on every operand, `-e`/`-f` swallow
  their argument, and the triage's two `sed -i` paren cases pass on
  unpatched upstream. Not touched, not re-tested here.
- **The fd-redirect digit divergence.** `cp docs/notes.md src/main2>/dev/null`
  is reported by this tree as a write to `src/main` (the redirect stripper
  `lib.sh:662` takes the `2` as a file descriptor) where bash writes
  `src/main2`. It is cosmetic for the lock: the category cannot change
  (`src/main` and `src/main2` classify alike) and nothing is let through. A
  tested tweak exists from the triage (`port/.claude/hooks/lib.sh`, suite
  `extra: 7 passed, 0 failed` with it): a leading fd only counts when it
  starts a word -

      -  noredir="$(printf '%s' "$masked" | sed -E 's/[0-9]*>>?[[:space:]]*[^|&;()[:space:]]*//g')"
      +  noredir="$(printf '%s' "$masked" | sed -E \
      +    -e 's/(^|[[:space:]])[0-9]+>>?[[:space:]]*[^|&;()[:space:]]*/\1/g' \
      +    -e 's/>>?[[:space:]]*[^|&;()[:space:]]*//g')"

  with the case `assert_blocked "$FIX" 'cp docs/notes.md src/main2>/dev/null'
  src/main2 'cp dest glued to a redirect: bash writes src/main2'`. A possible
  follow-up story; it is a different line, a different rule and a different
  severity, so it is not folded in here.
- `path_is_implausible` - unchanged (C-3). A literal paren still declines.
- The `phase-guard.sh` hunk of `0937c76` - that was downstream's `sed -i`
  extractor, superseded upstream.
- Any other character the masker does not map (`{`, `}`, `` ` ``, `$`):
  not reported, not reproduced, not this story.

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
         that earns it (C-2 names three; say so rather than claim them)
       * anything discovered that changes the approach -->

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. One block per return: which test, what it asserted, what was
     wrong with it, how the defect was found, what it asserts now, and the
     PASTED probe output that earns the correction (a fence or a four-space
     indented line; prose does not count). -->

## Gate results

<!-- Written by scripts/gates.sh itself on every full run. Do not paste or
     edit it. -->

## Notes

- **Provenance.** Downstream fix: manhwa-cropper `0937c76` (2026-09-10,
  authored with Claude Opus 5), which added 15 cases to its
  `phase-guard.test.sh`; its commit message records why `\016`/`\017` and
  not `\013`/`\014`, and that the sed `-e` misparse first reported was in
  fact this truncation. Triage: 2026-10-11, orchestrator on fable, on
  scratch copies `up/` (release 93, `lib.sh` byte-identical to HEAD at
  `8048134`) and `port/` (same plus the C-1 hunk and the out-of-scope fd
  tweak). Measurements: `paren.test.sh` 8/6 on `up`, 14/0 on `port`; full
  suites on `port` phase-guard 369/0 (2870 s), lib 281/0, sigpipe 82/0,
  grep-count 20/0; `check-sigpipe.sh` and `check-grep-count.sh` identical
  on both. The scratch directory is deleted after planning; everything the
  next agent needs is above, verbatim.
- **Cost.** One guard assertion is 8-15 s here; the whole phase-guard suite
  is ~48 min. The RED handoff must still quote the whole-suite summary for
  the floor (C-5); the slice (C-8) is for iteration and the DVs.
- **Why `touches:` names five files.** `floors.conf` and `selftest.test.sh`
  are edited by every story that adds selftest assertions, so they are the
  likeliest collision with a sibling story; `plan.sh conflicts` can only see
  it if both sides declare it.
