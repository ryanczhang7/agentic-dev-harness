---
id: HARNESS-053
title: The phase lock judges a quoted file name containing parentheses, instead of letting the write through
slug: the-phase-lock-judges-a-quoted-file-name
epic: 
type: fix
status: in-progress
phase: GATES
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
    `bash scripts/mutate.sh .claude/hooks/lib.sh '/^  tr /{s/[\]016[\]017//; s/()//}' -- bash scripts/selftest.sh lib`
    (changes only the `tr` line, to exactly today's
    `tr '\001\002\003\004\005\006\007\010' '|&;>< \t\n'`. *Corrected at the
    end of GREEN:* PLANNED wrote `s/\\016\\017//`, which the feature-developer
    found leaves `\016\017` in place on this host's GNU sed 4.9 and so builds
    a different mutant - `tr` with set1 longer than set2, parens mapped to
    newline. The orchestrator reproduced it independently with a dry run
    against the committed line: `sed -n '/^  tr /{s/\\016\\017//; s/()//; p}'`
    prints `tr '...\010\016\017' '|&;>< \t\n'` - `()` removed, escapes kept -
    while the bracketed form prints exactly today's line. On a bare
    `x\016\017y` input both spellings work, so the difference is specific to
    the real line, which is why the probe is against the tree.)
    - AC-5b's round trip **must** go red (parens come back as
    `\016`/`\017`), and in phase-guard AC-1..AC-3 **must** report
    `blocked, but on the wrong path`.
  RED cannot run this: the lines to delete do not exist yet. Confirm both
  suites green on the restored file, run `bash scripts/mutate.sh --check`,
  and paste the output here.

  *Result (a) (GATES, 2026-10-13).* For phase-guard I used the C-8 slice
  (`bash .claude/state/h053-slice.sh`, the nine C-2 assertions verbatim)
  instead of the 45-minute whole suite, as DV-1 permits. The whole suite runs
  in the full self-test before REVIEW.

  `bash scripts/mutate.sh .claude/hooks/lib.sh '/if (c == "[()]")  return/d' -- bash scripts/selftest.sh lib`
  turned exactly AC-5a red, as predicted:

  ```
      FAIL HARNESS-053 AC-5a: no ( or ) survives masking in: rm 'src/x (1).ts'
           expected: 0
           actual:   1
  lib: 282 passed, 1 failed
  === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_hooks_lib.sh.20261013T033140Z.209077.bak) ===
    121:       if (c == "(")  return "\016"
    122:       if (c == ")")  return "\017"
  ```

  The same expression with `-- bash .claude/state/h053-slice.sh` turned the six
  `assert_blocked` cases red, with the Context's wrong paths and `not blocked
  at all`. The three `assert_allowed` controls stayed green:

  ```
      FAIL blocks: HARNESS-053 AC-1: quoted redirect target containing parens
           blocked, but on the wrong path (wanted 'src/my (1).ts'): ... path:     src/my    category: source
      FAIL blocks: HARNESS-053 AC-2: rm of a quoted name containing parens
           not blocked at all
      FAIL blocks: HARNESS-053 AC-2: touch of a quoted name containing parens
           not blocked at all
      FAIL blocks: HARNESS-053 AC-2: tee into a quoted name containing parens
           not blocked at all
      FAIL blocks: HARNESS-053 AC-2: mv onto a quoted name containing parens
           not blocked at all
      FAIL blocks: HARNESS-053 AC-3: rm of a backslash-escaped name containing parens
           blocked, but on the wrong path (wanted 'src/x (1).ts'): ... path:     src/x    category: source
  paren-slice: 3 passed, 6 failed
  === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_hooks_lib.sh.20261013T033910Z.217332.bak) ===
  ```

  *Result (b) (GATES, 2026-10-13)*, using the corrected expression above.
  `bash scripts/mutate.sh .claude/hooks/lib.sh '/^  tr /{s/[\]016[\]017//; s/()//}' -- bash scripts/selftest.sh lib`
  turned exactly AC-5b red. The parens come back as `\016`/`\017` (`cat -v`
  shows `^N`/`^O`), as predicted:

  ```
      FAIL HARNESS-053 AC-5b: round trip: rm 'src/x (1).ts'
           expected: rm 'src/x (1).ts'
           actual:   rm 'src/x ^N1^O.ts'
  lib: 282 passed, 1 failed
  === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_hooks_lib.sh.20261013T034842Z.228975.bak) ===
    250:   tr '\001\002\003\004\005\006\007\010\016\017' '|&;>< \t\n()'
  ```

  The same expression with `-- bash .claude/state/h053-slice.sh` makes all six
  AC-1..AC-3 cases report `blocked, but on the wrong path`. In each, the
  candidate is the whole name with its parens still masked: masking now
  works, so nothing is truncated or declined, but the guard reports a path
  that was never unmasked. The three controls stay green:

  ```
      FAIL blocks: HARNESS-053 AC-1: ... (wanted 'src/my (1).ts'): ... path:     src/my ^N1^O.ts    category: source
      FAIL blocks: HARNESS-053 AC-2: ... (wanted 'src/x (1).ts'):  ... path:     src/x ^N1^O.ts     category: source
      FAIL blocks: HARNESS-053 AC-2: ... (wanted 'src/x (1).ts'):  ... path:     src/x ^N1^O.ts     category: source
      FAIL blocks: HARNESS-053 AC-2: ... (wanted 'src/t (1).ts'):  ... path:     src/t ^N1^O.ts     category: source
      FAIL blocks: HARNESS-053 AC-2: ... (wanted 'src/m (1).ts'):  ... path:     src/m ^N1^O.ts     operand:  destination of mv   category: source
      FAIL blocks: HARNESS-053 AC-3: ... (wanted 'src/x (1).ts'):  ... path:     src/x ^N1^O.ts     category: source
  paren-slice: 3 passed, 6 failed
  === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_hooks_lib.sh.20261013T035624Z.237783.bak) ===
    250:   tr '\001\002\003\004\005\006\007\010\016\017' '|&;>< \t\n()'
  ```

  *Green re-run on the restored tree*, which is also DV-2's "after":

  ```
  check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
  check-grep-count: scanned 49 shell file(s), 0 finding(s)
  mutate: no stranded mutation; nothing of a previous run is in the tree.
  lib: 283 passed, 0 failed
  assertion floors: all 1 suite(s) met their declared floor (283 assertions executed, 283 declared).
  paren-slice: 9 passed, 0 failed
  ```

  `lib.sh` was confirmed identical to the GREEN commit (`git diff --quiet
  53aee95 -- .claude/hooks/lib.sh`) before `gates.sh` ran. The whole
  phase-guard suite (378) runs in the full self-test before REVIEW.

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

  *Result (GATES, 2026-10-13).* On the committed fix (`53aee95`), before any
  mutation, both guards exit 0 with:

  ```
  check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
  check-grep-count: scanned 49 shell file(s), 0 finding(s)
  ```

  Under DV-1(a), run as
  `bash scripts/mutate.sh .claude/hooks/lib.sh '/if (c == "[()]")  return/d' -- bash -c 'bash scripts/check-sigpipe.sh 2>&1 | tail -1; bash scripts/check-grep-count.sh 2>&1 | tail -1'`.
  That mutation is the pre-fix masker for every consumer that does not
  unmask, and neither guard unmasks:

  ```
  check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
  check-grep-count: scanned 49 shell file(s), 0 finding(s)
  === mutate: command exited 0; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_hooks_lib.sh.20261013T034047Z.219311.bak) ===
  ```

  The lines are identical with and without the wider mask, and the finding
  count is 0 on both. A quoted paren in a real harness script carries no
  weight in either guard. The file count is 49, not the triage's 51, because
  `main` has moved since. The "after" re-run on the restored tree is under
  DV-1's block, with the green re-run.

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

- RED, `test-developer`, dispatched with `model: opus`; the agent reported
  running on Opus 5.5 (`claude-opus-5-5`). As planned. Orchestrator
  (`/advance-story`) ran on Fable 5.1, then Opus 5.5 after a session model change.
- GREEN, `feature-developer`, dispatched with `model: opus`; the agent reported
  running on Opus 5.5 (`claude-opus-5-5`). As planned. Orchestrator on Fable 5.1.

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

Two levels, both the cheapest that can falsify the criterion:

- **Integration, through the real guard** (`.claude/tests/phase-guard.test.sh`,
  last block, `describe "HARNESS-053: a paren inside a quoted argument is data
  (0937c76)"`, under `set_phase "$FIX" RED` on the file's shared `make_fixture`
  tree). AC-1..AC-4 are claims about the denial the hook emits, so they are
  judged with `assert_blocked` (exact, whole `path:` field) and
  `assert_allowed`. Exactly C-2's nine, verbatim; nothing added.
- **Unit, on the masker** (`.claude/tests/lib.test.sh`, appended to
  `describe "mask_shell_quotes: operators inside quotes stop being operators"`).
  AC-5 is a claim about `mask_shell_quotes`/`unmask_shell_quotes` themselves.

| # | Test (label) | Asserts | AC | Today |
|---|---|---|---|---|
| 1 | `HARNESS-053 AC-1: quoted redirect target containing parens` | `echo x > 'src/my (1).ts'` blocked on `src/my (1).ts` | AC-1 | red (path `src/my `) |
| 2 | `HARNESS-053 AC-2: rm of a quoted name containing parens` | `rm 'src/x (1).ts'` blocked on `src/x (1).ts` | AC-2 | red (not blocked) |
| 3 | `HARNESS-053 AC-2: touch of a quoted name containing parens` | `touch 'src/x (1).ts'` blocked on `src/x (1).ts` | AC-2 | red (not blocked) |
| 4 | `HARNESS-053 AC-2: tee into a quoted name containing parens` | `echo x \| tee 'src/t (1).ts'` blocked on `src/t (1).ts` | AC-2 | red (not blocked) |
| 5 | `HARNESS-053 AC-2: mv onto a quoted name containing parens` | `mv docs/notes.md 'src/m (1).ts'` blocked on `src/m (1).ts` | AC-2 | red (not blocked) |
| 6 | `HARNESS-053 AC-3: rm of a backslash-escaped name containing parens` | `rm src/x\ \(1\).ts` blocked on `src/x (1).ts` | AC-3 | red (path `src/x`) |
| 7 | `HARNESS-053 AC-4: quoted docs target containing parens` | `echo x > 'docs/my (1).md'` allowed | AC-4 | green (control) |
| 8 | `HARNESS-053 AC-4: cp from a quoted name containing parens, writing docs` | `cp 'src/a (1).ts' docs/notes.md` allowed | AC-4 | green (control) |
| 9 | `HARNESS-053 AC-4: parens and arrow inside a quoted command substitution` | `git commit -m "$(printf '%s' 'a (b) > c')"` allowed | AC-4 | green (control) |
| 10 | `HARNESS-053 AC-5a: no ( or ) survives masking in: rm 'src/x (1).ts'` | `awk '/[()]/'` over the masked text finds nothing (prints `0`) | AC-5 | red (`1`) |
| 11 | `HARNESS-053 AC-5b: round trip: rm 'src/x (1).ts'` | mask then unmask returns the input byte for byte | AC-5 | green (earned by DV-1(b)) |

AC-4's fourth case (`(echo x > src/main.ts)` blocked on `src/main.ts`) is
already pinned at `phase-guard.test.sh:509` and, per AC-4 and C-2, is not
re-added.

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

**Model.** RED ran on `opus` (Claude Opus 5.5, `claude-opus-5-5`), the agent
definition's own `model:`; no override was given in the dispatch.

**Commands** (both are the gate's view; the summary lines below come from them):

    bash scripts/selftest.sh lib            # ~3 min on this host
    bash scripts/selftest.sh phase-guard    # ~45 min on this host; run it alone

Iteration slice (C-8), nine assertions in ~38 s, gitignored and left in place
for GREEN and the DVs: `bash .claude/state/h053-slice.sh </dev/null` (it
sources `_lib.sh`, makes a fixture and holds the C-2 block verbatim, under the
name `paren-slice`). It is regenerated from the test file with:

    { echo '#!/usr/bin/env bash'; echo '. "D:/agentic-dev-harness/.claude/tests/_lib.sh"'; echo 'FIX="$(make_fixture)"'; sed -n '/^describe "HARNESS-053/,/^summary/p' .claude/tests/phase-guard.test.sh | sed 's/^summary "phase-guard"/summary "paren-slice"/'; } > .claude/state/h053-slice.sh

**Failure output** (2026-10-13, this tree, `lib.sh` unchanged; FAIL + reason,
the denial text after `path:` trimmed):

    lib (bash scripts/selftest.sh lib):
        FAIL HARNESS-053 AC-5a: no ( or ) survives masking in: rm 'src/x (1).ts'
             expected: 0
             actual:   1
    lib: 282 passed, 1 failed

    phase-guard (bash scripts/selftest.sh phase-guard):
        FAIL blocks: HARNESS-053 AC-1: quoted redirect target containing parens
             blocked, but on the wrong path (wanted 'src/my (1).ts'): BLOCKED by the harness phase lock.    story:    T-1   phase:    RED   path:     src/my    category: source  [...]
        FAIL blocks: HARNESS-053 AC-2: rm of a quoted name containing parens
             not blocked at all
        FAIL blocks: HARNESS-053 AC-2: touch of a quoted name containing parens
             not blocked at all
        FAIL blocks: HARNESS-053 AC-2: tee into a quoted name containing parens
             not blocked at all
        FAIL blocks: HARNESS-053 AC-2: mv onto a quoted name containing parens
             not blocked at all
        FAIL blocks: HARNESS-053 AC-3: rm of a backslash-escaped name containing parens
             blocked, but on the wrong path (wanted 'src/x (1).ts'): BLOCKED by the harness phase lock.    story:    T-1   phase:    RED   path:     src/x    category: source  [...]
    phase-guard: 372 passed, 6 failed

**Why it is the right red.** The six phase-guard FAILs are exactly the six of
the Context's triage run, with the same reported wrong paths (`src/my ` with
its trailing space, `src/x`) and `not blocked at all` for the four
`path_is_implausible` declines. The three `assert_allowed` controls are green.
In lib, AC-5a is red because the masked text still carries the parens (`awk`
found one: `actual: 1`), and AC-5b is green. No other assertion in either suite
changed state: before this story lib was 281 executed / phase-guard 369 with
none failing on this tree; the only FAIL lines in both runs are this story's.

**Files touched**

- `.claude/tests/phase-guard.test.sh` - one block of nine, before `summary`
  (the preceding HARNESS-045 block leaves the phase at GREEN; the new block
  sets RED itself, and nothing follows it but `summary`).
- `.claude/tests/lib.test.sh` - two `assert_eq` after the `for cmd` loop of
  the `operators inside quotes` block. AC-5a uses the block's one-awk shape
  (`awk '/[()]/ { h = 1 } END { print h + 0 }' <<<"$masked"`), not `grep -q`.
- `.claude/tests/floors.conf` - `lib` 281 -> 283, `phase-guard` 369 -> 378,
  plus a HARNESS-053 comment paragraph in the file's style.
- `.claude/tests/selftest.test.sh` - the mirrored table (`lib 283`,
  `phase-guard 378`) and the `lib is floored at its 283 executed assertions`
  case. `bash .claude/tests/selftest.test.sh </dev/null` -> `selftest: 268
  passed, 0 failed`.
- this story: `## Test plan`, this section.

**What the tests pin: GREEN builds C-1 exactly, in `.claude/hooks/lib.sh` and
nowhere else.** Three edits: the two `maskchar` lines after the TAB line
(`lib.sh:113`) mapping `(` -> `\016` and `)` -> `\017`; the `tr` at
`lib.sh:241` (the function starts at `:240`, not as C-1 says) widened to
`'\001\002\003\004\005\006\007\010\016\017' '|&;>< \t\n()'`; and the mapping
comment above `mask_shell_quotes` gaining `( -> \016   ) -> \017` and the
sentence on why not VT/FF. Do not touch `path_is_implausible` (C-3) or any
extractor: the extractors are correct to stop at a paren once a quoted one can
no longer reach them. Note the exact `maskchar` spelling DV-1(a) deletes:
`if (c == "(")  return "\016"` - TWO spaces before `return`, as C-1 shows; the
DV-1(a) sed `'/if (c == "[()]")  return/d'` depends on it.

**Export shape.** No signature changes, so there is no caller list. Checked on
this tree: `mask_shell_quotes` (`lib.sh:104`) and `unmask_shell_quotes`
(`lib.sh:240`) keep their names and their stdin -> stdout filter shape; the
tests call them only through lib.test.sh's existing `mask`/`roundtrip` helpers
(`printf '%s' "$1" | mask_shell_quotes [| unmask_shell_quotes]`) and through the
guard hook. Not constrained: which control characters are used, provided they
are inert to every character class the extractors use (C-1 settles `\016`/`\017`;
AC-5a only requires that no literal paren survives, AC-5b that the round trip
is exact).

**Green on arrival, and what earns each.**

| Test | Earned by | Status |
|---|---|---|
| AC-5b round trip | DV-1(b): revert the `tr` set; parens come back as `\016`/`\017` and it goes red | GATES runs it; not run in RED (the line does not exist yet) |
| AC-4 `echo x > 'docs/my (1).md'` allowed | `/audit-mutations` - no mutation in this story's budget turns it red (C-2) | not claimed |
| AC-4 `cp 'src/a (1).ts' docs/notes.md` allowed | `/audit-mutations` (C-2) | not claimed |
| AC-4 `git commit -m "$(printf '%s' 'a (b) > c')"` allowed | `/audit-mutations` (C-2) | not claimed |

**Negative controls - expected values.** Every criterion is mechanical; the
controls are the three AC-4 `assert_allowed` cases, expected value `allowed`,
measured `allowed` (green) in both the slice and the whole-suite run on this
tree. Unlike a dark RED, these suites did NOT fail at import: every assertion
in both files executed, so the measured values above are real, against the
unpatched `lib.sh`. GREEN confirms they are still `allowed` against the patched
one - that is the over-masking check.

**Deferred verifications - declined in RED.** DV-1 (a) and (b) and DV-2 are
owned by GATES. RED cannot run DV-1: the lines it deletes or reverts do not
exist until GREEN writes C-1. RED did not run DV-2 either (it is a before/after
on the committed fix). Neither is claimed here.

**Discovered - for the orchestrator, not a change to the approach.**

- `scripts/selftest.sh`'s `executed_count` (`:220`) returns the **passed**
  count, not `passed + failed`, despite its name and its comment. So a
  single-suite run now reports the floors as unmet in RED (`lib` 282 < 283,
  `phase-guard` 372 < 378) and met again once GREEN turns the reds green. That
  is the same state every previous RED floor raise left (the HARNESS-045/046
  paragraphs in `floors.conf` say "sit at their floors and failing until GREEN
  lands"), so I followed the contract's `passed + failed`; flagging only that
  the helper's comment and the floor arithmetic disagree on the word
  "executed". The pre-raise run printed `assertion floors: all 1 suite(s) met
  their declared floor (372 assertions executed, 369 declared)`.
- C-1's `lib.sh:240` for the `tr` line is `:241` (the function header is at
  `:240`); line numbers only, nothing amended.
- `bash scripts/gates.sh --fast`: `All required gates passed (0 ran, 5
  unconfigured, 0 known).` - every gate here is unconfigured; nothing broke.

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. One block per return: which test, what it asserted, what was
     wrong with it, how the defect was found, what it asserts now, and the
     PASTED probe output that earns the correction (a fence or a four-space
     indented line; prose does not count). -->

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-13T04:16:18Z
    commit: 53aee95
    tree:   8e26b3556f82461cc48dc69967c5613afc8d0b35
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

### GREEN confirmations

Feature-developer, dispatched with no model override; ran on Opus 5.5
(`claude-opus-5-5`), the agent definition's own `model:`. C-1 applied as
written, three edits to `.claude/hooks/lib.sh`, nothing else; no Contract
amendment. The slice was observed red first on this tree
(`paren-slice: 3 passed, 6 failed`, the same six FAILs as the handoff), then:

    bash .claude/state/h053-slice.sh </dev/null
    paren-slice: 9 passed, 0 failed

    bash scripts/selftest.sh lib
    lib: 283 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (283 assertions executed, 283 declared).

    bash scripts/selftest.sh phase-guard      (full log: .claude/state/h053-pg-green.log)
    phase-guard: 378 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (378 assertions executed, 378 declared).

    bash scripts/check-sigpipe.sh      -> exit 0
    check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
    bash scripts/check-grep-count.sh   -> exit 0
    check-grep-count: scanned 49 shell file(s), 0 finding(s)

    bash scripts/gates.sh --fast
    All required gates passed (0 ran, 5 unconfigured, 0 known).

    git diff --stat
     .claude/hooks/lib.sh                | 11 ++++++++++-
     docs/backlog/stories/HARNESS-053.md |  2 +-
     2 files changed, 11 insertions(+), 2 deletions(-)

(The story's 2-line diff above is the uncommitted `phase: GREEN` change that
predates this dispatch; this subsection is added after the stat was taken.)

- **Negative controls.** The three AC-4 `assert_allowed` cases measured
  `allowed` against the patched `lib.sh` in both the slice and the whole
  phase-guard run (no FAIL line in either), matching RED's recorded value
  `allowed`. No over-masking shows. The pre-existing `'a(b)'` implausible case
  (`lib.test.sh:583`, inside the `for t in ...` loop; the handoff's `:575`
  is the line before the block moved) passes in the 283/0 run.
- **Census lines differ from the triage's in file count only** (49/45 here
  against 51/47 in triage, on a different tree); finding count 0 on both, as
  DV-2 requires. DV-2's before/after/under-mutation comparison is GATES' and
  was not run.
- **For GATES: DV-1(b)'s sed expression does not do what DV-1 says on this
  host's GNU sed 4.9.** A dry run of the expression with `sed -n ...p` on the
  patched file (no file change) printed
  `tr '\001\002\003\004\005\006\007\010\016\017' '|&;>< \t\n'` - the `()`
  removed, the `\016\017` NOT removed. Isolated:
  `echo 'a\016\017b' | sed 's/\\016//'` prints `a\\017b`, i.e. this sed
  mishandles `\\` followed by a digit. Under that mutant set1 is two longer
  than set2, so `tr` maps `\016`/`\017` to `\n` (last char repeated): AC-5b
  would still go red, but parens come back as newlines, not as
  `\016`/`\017` as DV-1(b) predicts. A spelling that does work here:
  `'/^  tr /{s/[\]016[\]017//; s/()//}'` (bracketed backslash;
  `echo 'a\016\017b' | sed 's/[\]016[\]017//'` prints `ab`). DV-1(a)'s
  expression was dry-run the same way and matches exactly the two new
  `maskchar` lines.
