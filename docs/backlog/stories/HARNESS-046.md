---
id: HARNESS-046
title: A story id is one path component
slug: a-story-id-is-one-path-component
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-046-a-story-id-is-one-path-component
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/hooks/lib.sh, scripts/new-story.sh, scripts/gates.sh, scripts/phase.sh, .claude/tests/lib.test.sh, .claude/tests/new-story.test.sh, .claude/tests/phase.test.sh, .claude/tests/gates.test.sh]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Lead 3 of the first `/security-audit` run, `docs/wiki/audits/security-2026-10-08.md`
(fingerprint `story-id/path-traversal/allowlisted-scripts`; full record at
`C:\Users\ryanc\security-audit-skill\agentic-dev-harness\run-1\findings.json`
and `NEEDS-VALIDATION.md`). Three scripts join a caller-supplied story id
into `docs/backlog/stories/$id.md` with no check on the id:
`scripts/new-story.sh:11` (creates the file; refuses only an existing path;
also expands `title` unquoted into the frontmatter, so a title with a newline
writes arbitrary lines), `scripts/gates.sh:87,332` (`--story`; rewrites the
target's `## Gate results` via tmp+mv), and `scripts/phase.sh:158`
(`set`; rewrites the target's frontmatter and persists the id as `STORY_ID`
in `.claude/state/current-story.env`, which every hook then reads). An id of
`../../X` reaches any `.md` the parent directories hold.

**Why this is fixed now rather than validated first.** The audit left the
lead `needs_validation` on whether Claude Code's allow rules for the three
scripts auto-approve such an argument. The scripts' own contract does not
depend on it: `CLAUDE.md` says stories live in `docs/backlog/stories/`,
`story-authoring` gives the id as the first argument of `new-story.sh` in
the shape `WORLD-014`, and `rules.md` treats `STORY_ID` in the state file as
evidence every hook trusts. An id that names a file outside the stories
directory is a defect in the harness's stated behaviour whichever way the
platform question falls. **No criterion below depends on Claude Code's
permission behaviour**; every one runs in the harness's own suites over
`make_project_fixture` fixtures.

**The accepted grammar, decided from the ids in use.** Every id this
repository, its tests and its two downstream projects use is one run of
letters, digits and hyphens: `HARNESS-001`..`HARNESS-046` here; `T-1`,
`T-A`, `T-B`, `T-M`, `T-9`, `T-10`, `T-11`, `T-12`, `T-40`, `K-1`, `K-2`,
`WORLD-014`, `WORLD-3` in `.claude/tests/*.sh`; `WORLD-NNN` (129 stories) in
fantasy-world-builder and `MT-NNN` in manga-translator; epics `EPIC-03`.
The grammar is wider than that so it never refuses a reasonable id, and
exactly as narrow as "one path component": **the first character is a letter
or digit; every character is a letter, digit, `.`, `_` or `-`.** That admits
every id above and refuses `/`, `\`, every whitespace character (newline,
tab, space, carriage return), the empty string, and a leading `.` or `-` (so
`.`, `..`, `.hidden` and `-flag` are out). Case is not restricted. This is
settled here, not re-derived in RED.

**Decided, from the audit:** one shared check used by all three scripts
(audit `## Decided` 2, third bullet, and the user's instruction). The
*evidence* is not settled - the audit ran nothing - so AC-1 to AC-3
reproduce the defect first and are the permanent regression tests.

**Type `fix`; not split.** One function, three one-line call sites, one
title check, tests in the four suites that already cover those scripts.
**The gate that fails if this breaks** is the harness's own `selftest`:
the `lib`, `new-story`, `phase` and `gates` suites. No `required_gates`
entry is needed.

One of three stories cut from the audit's three cheap leads; the others are
HARNESS-044 (`task.sh` arguments) and HARNESS-045 (the lock sees `git
--output`). HARNESS-045 also writes `.claude/hooks/lib.sh` and
`.claude/tests/lib.test.sh`, so the two **conflict** and run one after the
other, never in parallel worktrees; HARNESS-044 shares nothing with this.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC. -->

"The fixture" is `make_project_fixture` (it has `scripts/`,
`.claude/hooks/lib.sh` and `docs/backlog/stories/`); "the grammar message"
is Contract C-1's exact text. "Unchanged" is `cmp` against a copy taken
before the run.

- **AC-1 (`new-story.sh` refuses an id that is not one path component)** —
  Given the fixture, when `bash scripts/new-story.sh <id> "x"` runs for each
  of `../OUTSIDE`, `a/b`, `a\b`, `..`, `.x`, `-x`, `a b` and `$'A\nB'`, then
  each exits 2, prints the grammar message naming that id on stderr, and
  creates no file: `docs/backlog/OUTSIDE.md` does not exist afterwards and
  `docs/backlog/stories/` holds exactly the entries it held before.
  *Reproduction today:* `../OUTSIDE` creates `docs/backlog/OUTSIDE.md` and
  exits 0.
- **AC-2 (`phase.sh set` refuses it)** — Given the fixture with a story-shaped
  file at `docs/backlog/EXIST.md` (frontmatter `id: EXIST`, `phase: PLANNED`)
  and no `.claude/state/current-story.env`, when
  `bash scripts/phase.sh set ../EXIST PLANNED` runs, then it exits 1, prints
  the grammar message naming `../EXIST`, `docs/backlog/EXIST.md` is
  unchanged, and `current-story.env` still does not exist.
  *Reproduction today:* exit 0, `EXIST.md` rewritten, `STORY_ID=../EXIST`
  persisted.
- **AC-3 (`gates.sh --story` refuses it before any gate runs)** — Given the
  fixture with the same `docs/backlog/EXIST.md` and a `project.conf` whose
  one required gate is `printf 'ran\n'` with evidence `ran`, when
  `bash scripts/gates.sh --story ../EXIST` runs, then it exits 2, prints the
  grammar message naming `../EXIST`, prints no `ran` (the gate did not run),
  and `docs/backlog/EXIST.md` is unchanged. *Reproduction today:* the gate
  runs and `## Gate results` is appended to `EXIST.md`.
- **AC-4 (every id shape in use still works)** — Given the fixture, when
  `bash scripts/new-story.sh <id> "x"` then `bash scripts/phase.sh set <id>
  PLANNED` run for each of `HARNESS-046`, `WORLD-014`, `T-1`, `T-A`, `K-2`,
  `MT-071`, `a.b_c-1` and `x`, then each creates
  `docs/backlog/stories/<id>.md` and exits 0 both times; and the existing
  `new-story`, `phase`, `gates`, `plan`, `boundaries` and `worktree` suites,
  whose fixtures use the `T-*`/`K-*`/`WORLD-*` ids above, stay green.
- **AC-5 (`valid_story_id` is the one check, and it is a table)** — Given
  `.claude/hooks/lib.sh` sourced, when `valid_story_id <id>` runs, then it
  returns 0 and prints nothing for every id in AC-4's list, and returns 1 and
  prints nothing for every id in AC-1's list plus the empty string,
  `$'a\tb'`, `$'a\rb'`, `a;b` and `a$b`; and the three scripts each call it
  (one `grep -c 'valid_story_id' <script>` of at least 1 per script - a pin
  on *shared*, since AC-1..3 would pass with three private regexes).
- **AC-6 (`new-story.sh` refuses a title with a line break)** — Given the
  fixture, when `bash scripts/new-story.sh T-50 $'probe\n\n# injected'` and
  `bash scripts/new-story.sh T-51 $'a\rb'` run, then each exits 2 with a
  message on stderr saying the title must be one line, and neither
  `docs/backlog/stories/T-50.md` nor `T-51.md` exists. *Reproduction today:*
  `T-50.md` is written with `# injected` as a heading in its frontmatter.

Every criterion is **mechanical** (oracle partition, Contract C-7).

## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. -->

**Writes:** `.claude/hooks/lib.sh`, `scripts/new-story.sh`, `scripts/gates.sh`, `scripts/phase.sh`, `.claude/tests/lib.test.sh`, `.claude/tests/new-story.test.sh`, `.claude/tests/phase.test.sh`, `.claude/tests/gates.test.sh`

Every path classifies as `harness` (`bash scripts/classify.sh` at PLANNED),
so the phase lock freezes none of them; the role boundary is honoured by the
agents: RED writes the four test files only, GREEN writes the four scripts
only. No existing export changes signature; `valid_story_id` is new. Its
three call sites are listed in C-3..C-5 so GREEN adds all of them.

**RED may amend any block below in place, with a reason; GREEN builds what
the amended block says.**

- **C-1 `valid_story_id <id>`, in `.claude/hooks/lib.sh`**, beside the
  frontmatter readers (`frontmatter_value`, `:1363`). Returns 0 when `<id>`
  matches the grammar in Context, 1 otherwise; prints nothing; spawns no
  process (lib.sh is the hook's hot path, HARNESS-025) and uses nothing
  bash 3.2 lacks (`rules.md`: macOS ships 3.2 - no `[[ =~ ]]` with an
  inline pattern; parameter expansion and `case` are enough:
  `[ -n "$1" ] && [ -z "${1//[A-Za-z0-9._-]/}" ]` plus a
  `case "$1" in [A-Za-z0-9]*) ;; *) return 1 ;; esac`). The grammar as one
  sentence, which is also the refusal text every script prints to stderr,
  byte for byte with the offending id substituted:

      error: story id '<id>' is not one path component: an id is letters, digits, '.', '_' or '-', and starts with a letter or digit

  Newlines inside `<id>` are printed as-is (the message is for a human; the
  tests match the fixed prefix and the suffix, not the id).
- **C-2 Exit statuses.** `new-story.sh` exits **2** (its usage status);
  `gates.sh` exits **2** (its unknown-option status, `:89`); `phase.sh`
  exits **1** through `die` (`:25`, the status every other refusal there
  uses). Pinned so the tests pin them.
- **C-3 `scripts/new-story.sh`.** Gains `. "$ROOT/.claude/hooks/lib.sh"`
  after `ROOT` is set (`phase.sh:23` and `gates.sh:69` do the same), the id
  check right after the usage check at `:7`, and the title check beside it:
  `case "$title" in *$'\n'*|*$'\r'*) … exit 2 ;; esac` with the message
  `error: the title must be one line`. **Consequence for RED:**
  `new-story.test.sh:26-27` copies only the script into its fixture, so a
  script that sources `lib.sh` fails there with "No such file"; RED changes
  that fixture to copy `.claude/hooks/lib.sh` too (or to use
  `make_project_fixture`), which keeps every existing assertion in that
  suite meaningful. Sourcing lib.sh is side-effect free beyond
  `set_harness_root "${CLAUDE_PROJECT_DIR:-$PWD}"` (`lib.sh:30`), which
  reads nothing.
- **C-4 `scripts/gates.sh` - line-count neutral above line 580.**
  `.claude/tests/sigpipe.test.sh:567-568` pin `scripts/gates.sh:74` and
  `scripts/gates.sh:580` **by line number** (C-5 freshness: "all twelve
  status-discarded lines are still where this suite says they are"), and
  test files are frozen in GREEN. So both checks are written **on existing
  lines**, adding no line before 580: `:87` becomes
  `--story) shift; STORY="${1:-}"; valid_story_id "$STORY" || { printf … >&2; exit 2; } ;;`
  and `:331` (`if [ -z "$STORY" ]; then load_state; STORY="$STORY_ID"; fi`)
  gains, on the same line, `; [ -z "$STORY" ] || valid_story_id "$STORY" || { printf … >&2; exit 2; }`
  so an id arriving from a hand-edited `current-story.env` is refused too
  (`phase.sh` is the only writer and will now validate, but the state file is
  evidence and is checked where it is read). GATES runs
  `bash scripts/selftest.sh sigpipe` to confirm the pins still hold; a
  refactor that moves line 580 is a return to RED to move the pin, not a
  reason to touch the test in GREEN.
- **C-5 `scripts/phase.sh`.** In `cmd_set`, after the usage check at `:154`
  and before `local file="$STORIES/$id.md"` at `:158`:
  `valid_story_id "$id" || die "story id '$id' is not one path component: …"`
  (`die` prefixes `error: `, so the printed line equals C-1's text). No
  suite pins phase.sh line numbers.
- **C-6 Where the tests go.** AC-5 in `lib.test.sh` (a table loop over the
  two lists, one `assert_eq` per id on the return status, plus the three
  `grep -c` pins). AC-1 and AC-6 in `new-story.test.sh`; AC-2 and AC-4 in
  `phase.test.sh` (it already drives `new_story` and `phase set`); AC-3 in
  `gates.test.sh` beside the existing `--story T-1` case (`:1458-1467`).
  No new suite, so `floors.conf` is untouched. The `..`-shaped ids in AC-1
  to AC-3 resolve **inside** the fixture (`docs/backlog/`), never above
  `mktemp`'s directory, so a red run on today's code writes nothing outside
  the fixture the trap removes.
- **C-7 Oracle partition.** Every criterion is **mechanical**: exact exit
  status, exact message, exact file existence. The grammar is **settled**
  (Context): RED reads it out and does not widen or narrow it; an id it
  believes should be admitted is an amendment to this block with a reason.
- **C-8 Tree-wide guards.** `check-grep-count.sh` refuses a printing
  `grep -c` fallback; AC-5's `grep -c` pins are assignments compared with
  `assert_eq`, the shape the guard accepts. GATES runs
  `bash scripts/ci-local.sh`.
- **C-9 Test-only dependencies.** None.

## Deferred verifications

<!-- One block per entry; the owning phase pastes the result in. -->

- **DV-1 (defect put back - the story's central claim). Owner: GATES.**
  With `valid_story_id` made to accept everything through
  `bash scripts/mutate.sh .claude/hooks/lib.sh '<sed expression inserting
  "return 0" as its first statement>' -- bash scripts/selftest.sh lib`,
  AC-5's refusal rows **must** go red (RED predicts the count: one per id in
  the refused list) and its accepted rows stay green; then, with the same
  mutation and `-- bash scripts/selftest.sh new-story`, AC-1's eight cases go
  red while AC-6 stays green (the title check is independent of the id
  check). Restore verified after each. RED cannot run this: there is no
  function to neuter. Paste both mutate.sh outputs and the red assertion
  names here, as fenced blocks.

## Out of scope

- Validating `epic` or `type` arguments to `new-story.sh`, or the id inside
  an existing story's frontmatter (`check-boundaries.sh` owns frontmatter).
- `phase.sh set`'s other behaviours the audit noted: `guard_transition`
  skipping PLANNED/DONE, `gates.sh` failing open when `branch:` is absent.
  Both are documented design; neither is a path question.
- Restricting ids to the `PREFIX-NUMBER` shape. `T-A`, `T-M` and `K-2` are
  in the tests today, and the audit's defect is the path, not the style.
- Where the stories directory is (`docs/backlog/stories/` stays fixed).
- `.claude/settings.json` allow rules for the three scripts, and any
  observation of Claude Code's permission matcher.
- The other two leads: HARNESS-044, HARNESS-045.

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
         or Gate probes section describes a failure without showing one.
         A result counts only as a block: a line beginning with three
         backticks or three tildes (a fence), or a line indented by exactly
         four spaces. Prose does not count, nor inline code in backticks, nor
         a tab, nor anything inside an HTML comment
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
     it guards, run the gate, paste the failure, revert. A result counts
     only as a block: a line beginning with three backticks or three tildes
     (a fence), or a line indented by exactly four spaces. Prose does not
     count, nor inline code in backticks, nor a tab, nor anything inside an
     HTML comment. One block per gate:
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


## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-046` from `.claude/harness/models.conf`.
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

- PLANNED: `lead-po` ran on **Fable 5.1** (`claude-fable-5-1`), the model its definition declares; the dispatching prompt stated no override and none was observed. 2026-10-08.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
