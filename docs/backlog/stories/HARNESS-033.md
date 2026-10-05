---
id: HARNESS-033
title: Criteria freeze at the last committed PLANNED state, not the base branch
slug: criteria-freeze-at-the-last-committed-pl
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-033-criteria-freeze-at-the-last-committed-pl
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/tests/sigpipe.test.sh, .claude/commands/advance-story.md, .claude/harness/rules.md, .claude/skills/story-authoring/reference/sections.md, scripts/new-story.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

This story is finding B of group 6, "Process", in
`docs/wiki/audits/manga-translator-port-2026-10-02.md` (GitHub issue #97). The
audit's `## Decided` item 6 B is settled and is not reopened here:
**check-boundaries 3d freezes criteria against the base branch in every phase,
contradicting law 6 and `advance-story.md`. Fix the *check*: baseline the
criteria at the story's last committed PLANNED state in the branch, else the
base.** This story implements it.

**The field evidence (issue #97, finding B).** In manga-translator, MT-019 and
MT-065 were filed and merged to `main` at PLANNED, then refined on their own
branches before RED. `advance-story.md` calls PLANNED "the last phase in which
[criteria] may change without an `## Amendments` entry", but
`check-boundaries.sh` 3d compares the criteria with the base branch whatever the
phase, so both PRs failed until an Amendments entry was written for a change the
law permits.

**Verified at PLANNED against this tree (release 75, `c7c902f`):**

- `scripts/check-boundaries.sh:301-303` is the 3d comment, and it says the
  quiet part: "any difference from the base branch needs an ## Amendments
  entry, whatever phase the edit was made in. CI cannot see when in the
  branch's history an edit happened, only that it did." The second sentence is
  false: CI checks out with `fetch-depth: 0` (`.github/workflows/boundaries.yml:17`),
  and the per-commit RED manifest check at `:539-540` already walks
  `git rev-list "$BASE"..HEAD` reading the committed phase of every commit.
- `:304-316` is the block. `:312` is the refusal, which itself says "Criteria
  are frozen once a story leaves PLANNED" - the rule the block does not
  implement. `:315` is the skip note for a story new in the PR: "story file is
  new in this PR; nothing to freeze the criteria against". That skip is a second
  hole the same design leaves: a story that is new in its PR, which is every
  story this repository has run (HARNESS-032's file first appears in its RED
  commit `a947567`), has no criteria freeze at all, in any phase.
- `.claude/tests/boundaries.test.sh:205-221` is the only 3d test: base has the
  story at PLANNED, the branch commits it at REVIEW with a changed AC, and it is
  refused with `## Acceptance criteria differ from main`. It stays green.

**The audit's constraint, from "What would have to be true for this to be
wrong":** the fix trusts the committed frontmatter's phase per commit, so a
branch that flips back to PLANNED after RED must not move the baseline. The
definition in C-1 makes that structural: the baseline is fixed by the *first*
departure from PLANNED, and nothing later is consulted.

**The required gate that fails if this breaks:** `selftest`, through
`boundaries.test.sh`. No optional gate is involved; `required_gates` stays empty.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

Every criterion is observed by running `bash scripts/check-boundaries.sh
<base>` in a real two-branch fixture repository, as `boundaries.test.sh` already
does. "Accepted" means: the output contains **no** line starting `FAIL  story
<id>: ## Acceptance criteria differ from`, and **does** contain the exact `ok`
or `note` line the criterion names. It never means exit 0, because these
fixture stories carry no `## Gate results` and 3e refuses them for that. The
messages are pinned byte for byte in C-2. `<sha7>` is the first seven
characters of the full commit id (not `git rev-parse --short`, which can be
longer).

- **AC-1 (the field case)** — Given the base branch holds the story at
  `phase: PLANNED` with criteria v1, and the story branch commits it at
  PLANNED with criteria v2, then at RED, then at REVIEW, all with v2 and no
  `## Amendments`, check-boundaries accepts the criteria and prints
  `ok    acceptance criteria unchanged since the last committed PLANNED state (<sha7>)`
  naming the branch's PLANNED commit. *Control:* today's check refuses this
  history with `## Acceptance criteria differ from main`.
- **AC-2 (a flip back cannot move the baseline)** — Given a story new in the
  PR committed at PLANNED (v1), RED (v1), PLANNED again (v2), RED (v2), REVIEW
  (v2), with no `## Amendments`, check-boundaries refuses with
  `## Acceptance criteria differ from the last committed PLANNED state (<sha7>)`
  naming the **first** PLANNED commit, not the second. And given the base
  branch already holds the story at RED with v1, a branch that commits it at
  PLANNED with v2 and then at REVIEW is refused with
  `## Acceptance criteria differ from main`.
- **AC-3 (else the base)** — Given the base holds the story at PLANNED with v1
  and the branch's first commit of it is already at RED with v2 (the refinement
  was never committed at PLANNED), check-boundaries refuses with
  `## Acceptance criteria differ from main`. The existing test at
  `boundaries.test.sh:205-221` is this case at REVIEW and stays green.
- **AC-4 (a story new in the PR)** — (a) committed at PLANNED v1, PLANNED v2,
  RED v2, REVIEW v2: accepted, with the `ok` line naming the second PLANNED
  commit. (b) first committed at RED v1, then REVIEW v2, no `## Amendments`:
  refused with
  `## Acceptance criteria differ from the first commit that left PLANNED (<sha7>)`
  naming the RED commit, where today it is skipped. (c) first committed at RED
  v1, then REVIEW v1: accepted with
  `ok    acceptance criteria unchanged since the first commit that left PLANNED (<sha7>)`.
  (d) every committed state and the working tree at PLANNED: the note
  `story <id> has not left PLANNED in any committed state; its criteria are not frozen yet`
  and no criteria refusal.
- **AC-5 (the escape hatch still works)** — The refused histories of AC-2's
  first case and AC-4(b), each with a non-empty `## Amendments` section, print
  `ok    acceptance criteria changed, with an ## Amendments entry` and no
  criteria refusal.
- **AC-6 (no history to walk)** — Given a base ref with which `HEAD` has no
  merge base (a depth-1 clone, or unrelated history), and the base holding the
  story at PLANNED v1 while the branch commits PLANNED v2 then REVIEW v2,
  check-boundaries prints the note
  `no merge base with <base>, so the branch's history cannot be walked; criteria compared with <base> itself`
  and refuses with `## Acceptance criteria differ from <base>`, which is
  today's behaviour. *Control:* the same history with a merge base is AC-1,
  accepted.
- **AC-7 (the procedure says to commit at PLANNED)** — In the real
  `.claude/commands/advance-story.md`, the text between `Create and switch to
  the story's branch` and the first `Set the phase;` after it contains
  ``while it still says `phase: PLANNED` ``. *Control:* today's file does not,
  so the assertion fails in RED.
- **AC-8 (the suite and its floors)** — A full `bash scripts/selftest.sh`
  passes. `floors.conf` and `selftest.test.sh`'s `COUNTS` row raise
  `boundaries` from 79 to the count executed after RED. `sigpipe.test.sh`'s C-5
  pins on `scripts/check-boundaries.sh` name the lines where those three
  statements now are, and its freshness assertion stays green.
  `bash scripts/check-sigpipe.sh` and `bash scripts/check-grep-count.sh` stay
  clean over the tree.

## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. This is where "RED
     tested one shape and GREEN built another" is prevented, and it is not the
     acceptance criteria: the criteria are frozen and change only through
     ## Amendments; this is a working agreement RED is expected to sharpen.
     One block per thing the story touches:
       * the files it WRITES, on one line at column 0 that starts
         `**Writes:**`, each path backticked and repository-relative:
           **Writes:** `src/core/world.ts`, `tests/world.test.ts`
         `bash scripts/plan.sh conflicts` compares it with `touches:` and prints
         DRIFT for a written file `touches:` does not cover. Without the line
         there is no DRIFT at all, and files the prose merely cites never count
       * module paths and exported names, exactly
       * exact signatures, and the types the assertions will destructure
       * THE SEMANTICS BEHIND EACH NUMBER - not clamp(latitude) but "latitude
         clamps at +/-85, and dragging DOWN brings the north into view". One
         sentence per number settles a sign error in one line
       * the accessible markup for anything user-facing: roles, labels, what is
         a sibling of what
       * the oracle partition of the criteria (settled / oracle-free /
         mechanical - see story-authoring)
       * baseline measurements the story may read out rather than re-derive,
         each with what it was measured on
       * TEST-ONLY DEPENDENCIES this story is likely to need, by name. RED
         may add them itself, but only inside the dev block - so a library
         production will ALSO use is a GREEN change and is better decided
         here than discovered mid-phase. Where the ecosystem has no dev
         block at all (go.mod, requirements.txt, *.csproj), RED cannot
         declare one and the phase round trip is yours to plan for
       * FOR EVERY EXISTING EXPORT WHOSE SIGNATURE THIS STORY CHANGES: every
         caller, source and test, grep-listed here before dispatch. RED cannot
         find these itself - the old signature still exists during RED, so a
         caller of it still compiles and is absent from RED's typecheck. One
         such file went missing and took 25 tests with it, silently, at GREEN. -->

**Writes:** `scripts/check-boundaries.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/commands/advance-story.md`, `.claude/harness/rules.md`, `.claude/skills/story-authoring/reference/sections.md`, `scripts/new-story.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

**RED may amend any block below in place, with a reason. GREEN builds what the
amended block says.**

**The phase lock enforces nothing here.** At PLANNED, `bash scripts/classify.sh`
returned `harness` for `scripts/check-boundaries.sh`,
`.claude/tests/boundaries.test.sh`, `.claude/tests/sigpipe.test.sh` and
`.claude/commands/advance-story.md`; the other paths are in the same
directories. So the split is held by discipline, as in HARNESS-030 and
HARNESS-032:

- **RED** writes only `boundaries.test.sh` and the two `boundaries` floor lines
  (`floors.conf`, `selftest.test.sh` `COUNTS`).
- **GREEN** writes `check-boundaries.sh`, `advance-story.md`, `rules.md`,
  `sections.md`, `new-story.sh`, and the three line pins in `sigpipe.test.sh`
  (C-5). The pins are a fixture that tracks where a source line sits, not an
  assertion; HARNESS-030 C-5 gave the same pin update to GREEN.

### C-1 The baseline, defined

A new function in `scripts/check-boundaries.sh`, defined above 3d with the
other helpers or immediately before the 3d block:

```
criteria_baseline <story-file>      # prints exactly one line: <kind> <rev>
```

It reads the global `$BASE`. `<rev>` is a full commit id, the literal `$BASE`
ref, or `-`.

**The states.** An ordered list of the story file's states, oldest first:

1. **the base copy**, `git show "$BASE:<story-file>"`, if it exists there;
2. **each commit of** `git rev-list --reverse --topo-order "$BASE"..HEAD` in
   which the story file exists (commits where it is absent are skipped). Not
   path-limited, and not `--first-parent`: in CI `HEAD` is a merge commit whose
   first parent is the base, so `--first-parent` would skip every branch
   commit;
3. **the working tree's copy**, last. In CI it equals `HEAD`; locally it is what
   the rest of the script already reads (3b reads the phase from it).

**The phase of a state** is the `phase:` frontmatter value of that copy, read
with `frontmatter_value` (`lib.sh:1152`) with every whitespace character removed
(`${ph//[[:space:]]/}`), because a Windows checkout can leave a `\r`. An empty
or unreadable phase counts as *not* PLANNED, which can only make the freeze
earlier, never later.

**F** is the first state whose phase is not `PLANNED`.

| Condition | Prints | Meaning |
|---|---|---|
| `git merge-base "$BASE" HEAD` fails, base copy exists | `unwalked <BASE>` | history cannot be walked (depth-1 clone, unrelated history); compare with the base, as today |
| `git merge-base` fails, no base copy | `none -` | nothing to compare with |
| no state has a non-PLANNED phase | `open -` | the story has not left PLANNED; nothing is frozen yet |
| F has a state before it, and that state is a branch commit | `planned <sha>` | the last committed PLANNED state |
| F has a state before it, and that state is the base copy | `base <BASE>` | the branch never committed the story at PLANNED: "else the base" |
| F is the first state and is the base copy | `base <BASE>` | the story had already left PLANNED on the base |
| F is the first state and is a branch commit | `first <sha>` | new in the PR, first committed outside PLANNED |
| F is the first state and is the working tree | `none -` | no committed state at all |

Every state before F is PLANNED by definition of F, so "the last committed
PLANNED state" is simply the state immediately before F. **Nothing after F is
read**, which is what makes the audit's constraint hold: a later return to
PLANNED, edited or not, cannot move the baseline.

**Why `first` (the decision the audit left open).** A story new in its PR whose
first commit is already outside PLANNED has no committed PLANNED state and no
base copy. Three answers were possible:

- *skip, as today:* leaves the criteria of every new-in-PR story editable in
  GREEN and GATES without a trace. That is every story this repository has run,
  so the skip is not an edge case, it is the common case. Rejected.
- *refuse:* there is nothing to have changed against, so a refusal would have no
  diff to show. Rejected.
- *freeze at that first commit:* chosen. It is the earliest committed record of
  the criteria after they left PLANNED. Edits made before it are
  indistinguishable from PLANNED edits, because the PLANNED → RED transition
  happens in the working tree before anything is committed, so treating them as
  PLANNED edits is the only reading the history supports. Every later change
  needs `## Amendments`, which is law 6. It is the same rule as "else the base",
  applied to the one committed copy that exists.

**Why the base copy, not the merge-base copy.** 3d already compares with
`$BASE` (the tip), and its refusal text says `differ from main`. Keeping the tip
keeps AC-3's existing needle and every message about the base unchanged. The
merge-base is used only to decide whether the history can be walked.

**No pipeline into an early-exiting reader.** Read each committed copy into a
variable first, `txt="$(git show "$rev:$sfile" 2>/dev/null)"`, then feed it
with a here-string: `frontmatter_value - <<< "$txt"`, `section - <<< "$txt"`.
The existing `git show "$BASE:$sfile" | section - ...` at `:305` is that
pipeline (`section`'s awk exits at the next heading), and it goes. HARNESS-029
and the `has_content` comment at `:52-69` say why. Keep `check-sigpipe.sh` and
`check-grep-count.sh` clean.

**Portability.** bash, awk and git only. POSIX awk: no intervals, no `\d`, no
backreferences, no `length(array)` (HARNESS-025 and HARNESS-028: a Linux-only
awk difference passed every local run once). The commit loop costs one `git
show` and no other process per commit; a PR has a handful.

### C-2 The 3d block and its messages

The 3d block obtains the baseline on **exactly this line, at column 0**, so that
DV-1's one sed expression can put the old defect back:

```
crit_base="$(criteria_baseline "$sfile")"
```

then splits it into kind and rev (e.g. `crit_kind="${crit_base%% *}"`,
`crit_rev="${crit_base#* }"`). Labels:

| kind | `<label>` |
|---|---|
| `planned` | `the last committed PLANNED state (<sha7>)` |
| `first` | `the first commit that left PLANNED (<sha7>)` |
| `base`, `unwalked` | `$BASE` (as passed: `main` in the fixture, `origin/main` in CI) |

Lines, byte for byte (`ok` and `FAIL` carry the script's existing prefixes,
`ok    ` and `FAIL  `; `note` is two spaces):

- `unwalked` first prints the note
  `no merge base with $BASE, so the branch's history cannot be walked; criteria compared with $BASE itself`,
  then compares as `base`.
- `open`: note
  `story $sid has not left PLANNED in any committed state; its criteria are not frozen yet`
- `none`: note `story file is new in this PR; nothing to freeze the criteria against`
  (today's `:315` text, kept). The same note is printed for kind `base` or
  `unwalked` when `$BASE:$sfile` does not exist. `criteria_baseline` never
  returns that combination, but DV-1's mutation does, and with this clause the
  mutated script is exactly today's 3d, so DV-1 puts back the real defect and
  not a new one.
- unchanged: `ok "acceptance criteria unchanged since <label>"`
- changed, `## Amendments` has content: `ok "acceptance criteria changed, with an ## Amendments entry"` (unchanged from `:310`)
- changed, no amendments:
  `problem "story $sid: ## Acceptance criteria differ from <label> with no ## Amendments entry. Criteria are frozen once a story leaves PLANNED, against the last state committed while it was PLANNED (else the base branch); record which AC changed, what it said, what it says now, who approved it and why."`

"Unchanged" keeps today's comparison exactly: `section ... "Acceptance criteria"`
on both sides with trailing whitespace stripped (`sed 's/[[:space:]]*$//'`, as
at `:305-306`, or an awk equivalent).

The 3d comment at `:301-303` is rewritten: it must no longer say "whatever phase
the edit was made in" or that CI cannot see when an edit happened. One or two
lines naming the rule and pointing at `criteria_baseline`.

### C-3 The tests: `.claude/tests/boundaries.test.sh`

- A new `describe` block (or blocks) after the existing "acceptance criteria are
  frozen" block at `:205-221`, which stays as it is.
- Build each history commit by commit in the existing `$FIX`, with
  `commit_all` (`:64`) after each state. A helper such as
  `history_story <id> <base-spec|-> <PHASE:criteria-text>...` that resets a
  `story/<id>-fixture` branch from `main` is suggested, not required. Use a
  **fresh story id per case** (e.g. `T-31`...): `main` already carries `T-1` at
  PLANNED from `:210-213`, and a case that needs "new in the PR" must not find
  its id there. A case that needs a base copy commits it on `main` first.
- The story's `branch:` frontmatter must match the fixture branch, or 3c
  refuses, and `sid` resolution (`:197-214`) reads the story id from that branch name.
- `sha7` in a needle is computed from the commit just made:
  `c="$(git -C "$FIX" rev-parse HEAD)"; c7="${c:0:7}"`.
- **Acceptance** is asserted as two claims: the criteria `FAIL` line is absent
  (`assert_not_contains` with needle `## Acceptance criteria differ from`), and
  the exact `ok`/`note` line is present. **Refusal** uses the existing
  `refused` helper (`:41`) with the full `differ from <label>` needle, which
  checks the message; its `rc != 0` half is weak here (3e also refuses), so the
  message is the claim that matters.
- AC-6: `run_boundaries` hard-codes `main` (`:33`). Add a variant that takes the
  base ref. The unwalkable base can be an orphan branch (`git checkout
  --orphan`) holding the story at PLANNED v1, or a `git clone --depth 1
  --no-single-branch "file://$FIX"` with `GITHUB_HEAD_REF` set to the story
  branch and base `origin/main`. Both make `git merge-base` fail; the orphan is
  faster on Windows. RED chooses and says which.
- AC-7: read the real file with `$(< "$REPO_ROOT/.claude/commands/advance-story.md")`,
  cut the text after the first `Create and switch to the story's branch` and
  before the first `Set the phase;` after it with parameter expansion, and
  assert it contains ``while it still says `phase: PLANNED` ``. Pure bash, no
  fork. This assertion lives here rather than in `procedure.test.sh` because
  that suite builds every fixture by construction (`write_advance`, `:256`) and
  a new rule there would need the sentence in every fixture; here it is one
  assertion over the real file.
- Each AC's assertions name the AC in their description (`AC-1: ...`).
- Leave `assert_not_contains ... "touches"` at the end of the file alone.

### C-4 The procedure: `.claude/commands/advance-story.md`

In the paragraph that begins `Create and switch to the story's branch` (today
line 77), insert this sentence immediately before `Set the phase;`:

> Before setting the phase, commit the story file on that branch while it still
> says `phase: PLANNED`: `check-boundaries.sh` freezes the criteria at the last
> state committed at PLANNED, so a refinement first committed together with RED
> is compared with the base branch instead and needs an `## Amendments` entry.

Line 18-20's sentence ("the last phase in which they may change without an
`## Amendments` entry") is left as it is; with C-4 it becomes true.
`policy.test.sh`, `reporting.test.sh` and `procedure.test.sh` read this file and
must stay green.

### C-5 Line pins in `sigpipe.test.sh`

`.claude/tests/sigpipe.test.sh:561-563` pins three status-discarded lines of
`scripts/check-boundaries.sh`, all below 3d, so all three move:

- `scripts/check-boundaries.sh:326:res=$(printf`
- `scripts/check-boundaries.sh:365:rec=$(printf`
- `scripts/check-boundaries.sh:540:ph_at="$(git show`

GREEN updates the three numbers to wherever those statements land. Nothing else
in that suite changes; its comments citing `check-boundaries.sh:323` and `:382`
(`:1114`, `:1161`) are prose and are left. The C-5 freshness assertion ("all
twelve status-discarded lines are still where this suite says they are") is the
check. If `criteria_baseline` adds a status-discarding `$(...)` of its own,
the guard decides whether it needs a pin; do not add one by hand.

### C-6 Wording elsewhere

Three places state the old rule as "a PR whose criteria differ from the base
branch". Each becomes "differ from their last committed PLANNED state (else the
base branch)", or equivalent wording:

- `.claude/harness/rules.md:287-288`
- `scripts/new-story.sh:134-135` (the `## Amendments` template comment)
- `.claude/skills/story-authoring/reference/sections.md:72-73`

### C-7 Floors

`boundaries` executes 82 assertions at `c7c902f` (`bash scripts/selftest.sh
boundaries` at PLANNED: `boundaries: 82 passed, 0 failed`), against a floor of
79. RED raises the floor to the count it measures after its tests are written,
in both `.claude/tests/floors.conf:39` and the `COUNTS` row
`selftest.test.sh:520`, and pastes the summary line.

### C-8 Oracle partition

- **Settled** (read out, do not re-derive): the baseline rule itself, from the
  audit's `## Decided` 6 B and its constraint; and the `first` decision in C-1,
  made here. RED does not reopen either.
- **Mechanical** (pin exactly): every message in C-2, the kinds in C-1, the AC-7
  sentence. Everything in this story is mechanical; there is no metric.
- **Oracle-free:** none.

### C-9 Callers

No existing function changes its signature. `section`, `frontmatter_value` and
`story_field` gain new callers only. The 3d messages are read by
`boundaries.test.sh:221` (`## Acceptance criteria differ from main`, still
printed for kind `base`) and by nothing else: `rg "nothing to freeze|differ
from"` over `.claude/tests` and `scripts` at PLANNED found only that line and
the script itself.

## Deferred verifications

<!-- REQUIRED when a verification this story depends on provably cannot run in
     the phase that wants it; omit the section otherwise. Written by the Lead PO
     at PLANNED, and the phase that owns it pastes the result in.
     The case this exists for: a negative control for a round trip, a threshold
     or a codec has to break the real implementation to mean anything, and in
     RED there is no implementation to break. RED naming the control and saying
     it could not run it is the honest answer; RED claiming a verification it
     did not do is the failure. One block per entry:
       * what it verifies, as a falsifiable condition - "with one field dropped
         from the encoder, AC-1's property test MUST fail"
       * why the phase that wants it cannot run it
       * THE PHASE THAT OWNS IT, declared as `Owner: GATES` (or RED, GREEN,
         REVIEW). check-boundaries.sh refuses a PR
         whose block names no phase
       * the RESULT, pasted, once that phase runs it: what was mutated, what
         failed, and that the file was restored - or the word WAIVED with the
         reason. check-boundaries.sh refuses a PR that has neither
     Schedule it into GATES rather than RED where you can: source is writable
     there, and a story that bounced back to RED mid-cycle gets its corrected
     assertions earned by the same mutation, for free. How many entries is the
     budget in rules.md, `Mutation work per story`: by default ONE
     "defect put back" entry for the story's central claim, run against the one
     suite that holds its assertion. A format or codec story may add one wrong VALUE
     mutation - a codec that is uniformly wrong round-trips through itself
     perfectly. Exhaustive earning of assertions that passed on arrival is not
     an entry here; it goes to `/audit-mutations`. -->

**DV-1 (defect put back).** Use `scripts/mutate.sh` to make 3d compare with the
base branch again, unconditionally, which is the field defect itself. C-2 pins
the line this expression matches, and C-2's `none` clause makes the mutated 3d
behave exactly like today's. Run the one suite that holds the assertions:

```
bash scripts/mutate.sh scripts/check-boundaries.sh 's|^crit_base="$(criteria_baseline "$sfile")"$|crit_base="base $BASE"|' -- bash scripts/selftest.sh boundaries
```

**Must** fail: AC-1's acceptance (the field history is refused with
`differ from main`), AC-2's first case, AC-4 (a) to (d), both AC-5 cases (a new
story gets the "nothing to freeze" note instead of the amendments `ok`), and
AC-6's note. **Must** still pass: AC-2's second case, AC-3 (including
`:205-221`), AC-7, and every assertion that existed before this story. RED
records in the handoff the exact count it predicts; GATES compares the measured
`boundaries: N passed, M failed` with it. `mutate.sh` must report that it
restored the file and verified the restore, and the suite must be green again
afterwards.

RED cannot run this: in RED the line does not exist, so there is nothing to put
the defect back into. The expression was checked at PLANNED against C-2's line
in a scratch file: it replaces that line and nothing else. Run it detached
(`nohup`, or the Bash tool's `run_in_background`); the suite took 256 s here at
PLANNED. **Owner: GATES.**

**DV-2 (probe against a real line of the tree).** 3d is a rule over the real
repository's story histories, so it is probed on one, not only on fixtures.
HARNESS-032's branch is a real new-in-PR story whose file first appears in its
RED commit: `a947567` (RED), `1e13357` (GREEN), `95e22c7` (REVIEW), branched
from `f9ab433`. Its criteria are identical across the three commits (checked at
PLANNED). In a scratch worktree, never this one:

```
git worktree add --detach <scratch>/h032 95e22c7
cp scripts/check-boundaries.sh <scratch>/h032/scripts/check-boundaries.sh
cd <scratch>/h032
GITHUB_HEAD_REF=story/HARNESS-032-the-full-self-test-runs-before-a-story-r PR_HEAD_SHA= bash scripts/check-boundaries.sh f9ab433
bash scripts/mutate.sh docs/backlog/stories/HARNESS-032.md 's/^- \*\*AC-4\*\* /- **AC-4** (probe) /' -- env GITHUB_HEAD_REF=story/HARNESS-032-the-full-self-test-runs-before-a-story-r PR_HEAD_SHA= bash scripts/check-boundaries.sh f9ab433
```

The first run **must** print
`ok    acceptance criteria unchanged since the first commit that left PLANNED (a947567)`,
where today's script prints the "nothing to freeze" note. The mutated run
**must** print
`FAIL  story HARNESS-032: ## Acceptance criteria differ from the first commit that left PLANNED (a947567) with no ## Amendments entry.`
followed by the rest of C-2's text. HARNESS-032's `## Amendments` holds only the
template comment, so it does not excuse the change. Judge by those lines, not by
exit status: the copied script makes the scratch tree differ from its gate record, so other checks may refuse it for reasons that have nothing to do with 3d. Paste both
lines and `mutate.sh`'s restore report, then `git worktree remove --force` the
scratch tree. **Owner: GATES.**

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. check-boundaries.sh fails a PR whose criteria differ
     from the base branch without an entry here. Omit the section if unused.
     Where the change came from a subagent's claim that the criterion was
     wrong, record the ORCHESTRATOR'S OWN reproduction of it - different
     inputs, not the subagent's code. That claim is also what an agent says
     when it wants to stop failing. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-033` from `.claude/harness/models.conf`.
A PLAN, not a record: a session setting or an explicit override can beat both
this and the agent's own `model:` field, and nothing here can see which won.
The orchestrator still writes down the model each dispatch **resolved** to, by
name, below the table.

| Phase | Agent | Planned | Why |
|---|---|---|---|
| PLANNED | `lead-po` | `opus` | planning is the judgement phase: decomposition, the oracle partition, and what goes in the contract |
| RED | `test-developer` | `opus` | the lock freezes none of the paths this story names, so the contract is not an aid to the model here - it is the only enforcement there is. A weaker model against a safety net and a weaker model against nothing are different propositions |
| GREEN | `feature-developer` | `opus` | the failure mode of a weaker model here is reaching green by weakening a test, which is the one thing this harness exists to prevent |
| GATES | `feature-developer` | `opus` | same risk as GREEN, and a gate failure is where "make it stop complaining" is most tempting |
| REVIEW | `lead-po` | `opus` | reading review feedback against the contract is judgement, and a wrong call here ships |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation, with no failing test in front of any of it |

**Resolved:**

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->

- PLANNED, `lead-po`, resolved to Opus 5.5 (`claude-opus-5-5`), dispatched without a model override.
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- **The other checks in `check-boundaries.sh`.** Only 3d changes. 3b, 3e-3h and
  the RED manifest walk at `:536-566` are untouched, apart from moving down the
  file.
- **Changing the workflow.** `.github/workflows/boundaries.yml` already checks
  out with `fetch-depth: 0`. AC-6 makes a shallow checkout degrade to today's
  behaviour; it does not change any workflow.
- **Other loose descriptions of 3d.** `CLAUDE.md:178`,
  `.claude/skills/quality-gates/SKILL.md:25` and `scripts/gates.sh:997` say
  "the acceptance criteria against the base branch" as a summary of what CI
  checks. They stay. `gates.sh` especially: `sigpipe.test.sh` pins its line
  numbers and nothing here needs to move them.
- **`complete-story.md`.** It defers the per-phase procedure to
  `advance-story.md`, so C-4's sentence lives in one place.
- **Re-baselining historical stories, or making a PLANNED commit mandatory.**
  Nothing refuses a branch that never committed the story at PLANNED: it falls
  back to the base (AC-3), which is the conservative direction. C-4 tells the
  orchestrator how to get the benefit; it is not enforced.
- **Groups 6 C and 6 D of the audit** (the run lock and `SELFTEST_JOBS`, the
  3g/3h messages). Separate stories.
- **Stale prose line references** in `sigpipe.test.sh` comments
  (`check-boundaries.sh:323`, `:382`). Only the C-5 freshness pins are updated.

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
     and the next person needs to know why. One block per return:
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
         or Gate probes section describes a failure without showing one
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
     it guards, run the gate, paste the failure, revert. One block per gate:
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


**PLANNED (2026-10-05, lead-po).**

- Planned in a worktree detached at `origin/main` `c7c902f` (release 75). The
  story file is left uncommitted at PLANNED; the user creates the branch.
- **This story is judged by its own rule.** CI runs the PR's own
  `check-boundaries.sh`, so this story's 3d result comes from `criteria_baseline`.
  Following C-4 here costs one commit and is the first real use of it: commit
  this file on `story/HARNESS-033-criteria-freeze-at-the-last-committed-pl`
  while it says `phase: PLANNED`, then `phase.sh set HARNESS-033 RED`. Without
  that commit the baseline is the RED commit (`first`), which is also correct.
- Measured at PLANNED: `bash scripts/selftest.sh boundaries` ->
  `boundaries: 82 passed, 0 failed`, 256 s on this Windows host. Floor 79.
- Verified at PLANNED in a scratch repository (not the fixture): `git rev-list
  --reverse --topo-order main..HEAD` lists a PLANNED/RED/PLANNED/REVIEW history
  oldest first; in a `git clone --depth 1 --no-single-branch file://...`,
  `git merge-base origin/main HEAD` exits 1 and `git rev-parse
  --is-shallow-repository` says `true`. That is AC-6's condition.
- DV-1's sed expression was run against C-2's line in a scratch file: it changed
  that one line to `crit_base="base $BASE"` and nothing else.
- The GATES -> REVIEW procedure now runs the full self-test first (HARNESS-032).
  `sigpipe.test.sh` pins `check-boundaries.sh` line numbers as well as
  `gates.sh`'s; C-5 lists the three that move.
