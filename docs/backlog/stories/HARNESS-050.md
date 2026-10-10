---
id: HARNESS-050
title: Only Edit(path) deny rules protect the state files
slug: only-edit-path-deny-rules-protect-the-st
epic: 
type: fix
status: in-progress
phase: RED
branch: story/HARNESS-050-only-edit-path-deny-rules-protect-the-st
depends_on: [HARNESS-047]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/settings.json, .claude/tests/settings.test.sh, .claude/state/README.md, .claude/harness/rules.md, docs/wiki/audits/state-deny-2026-09-10.md]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Observed 2026-10-10, Claude Code CLI v2.1.293, started interactively in
`D:\agentic-dev-harness`. At startup the CLI printed, about
`.claude/settings.json`'s `permissions.deny`:

    Permission deny rule "MultiEdit(./.claude/state/current-story.env)" matches no known tool — check for typos.
    Permission deny rule "MultiEdit(./.claude/state/last-gate-run)" matches no known tool — check for typos.
    Permission deny rule (.claude\settings.json): Write(./.claude/state/current-story.env) is not matched by file permission checks — only Edit(path) rules are. Use Edit(./.claude/state/current-story.env) instead (Edit rules cover all file-editing tools).
    Permission deny rule (.claude\settings.json): MultiEdit(./.claude/state/current-story.env) is not matched by file permission checks — only Edit(path) rules are. Use Edit(./.claude/state/current-story.env) instead (Edit rules cover all file-editing tools).
    Permission deny rule (.claude\settings.json): Write(./.claude/state/last-gate-run) is not matched by file permission checks — only Edit(path) rules are. Use Edit(./.claude/state/last-gate-run) instead (Edit rules cover all file-editing tools).
    Permission deny rule (.claude\settings.json): MultiEdit(./.claude/state/last-gate-run) is not matched by file permission checks — only Edit(path) rules are. Use Edit(./.claude/state/last-gate-run) instead (Edit rules cover all file-editing tools).

So, per the runtime, of the six state-file deny rules only the two `Edit(...)`
rules do anything. The `Write(...)` and `MultiEdit(...)` rules are discarded,
and an `Edit(path)` rule is matched against every file-editing tool. The
harness believes the opposite in four places, each confirmed by reading at
PLANNED:

- `.claude/settings.json` lists `Write`, `Edit` and `MultiEdit` deny rules for
  `./.claude/state/current-story.env` and `./.claude/state/last-gate-run`.
- `.claude/state/README.md`, "The `Hand-editable` column is enforced", says
  settings.json denies `Write`, `Edit` and `MultiEdit` on the `no` rows and
  that the suite's `TOOLS` list drives both directions of the check.
- `.claude/tests/settings.test.sh` has `TOOLS="Write Edit MultiEdit"`, which
  makes every `no` row **demand** a rule per tool. The suite therefore
  requires the dead rules and goes red if they are removed. It was green
  while requiring rules the runtime discards: a rule probed only against
  fixtures its author wrote, which `rules.md` ("A rule is probed against the
  tree it judges") names as the failure.
- `.claude/harness/rules.md`, Non-negotiables, the `.claude/state/**` bullet,
  says the two files are "denied to `Write`, `Edit` and `MultiEdit` in
  `settings.json`".

`docs/wiki/audits/state-deny-2026-09-10.md` records why the `MultiEdit` rules
went in ("a missing rule on a build that has the tool is a hole") and says
twice that whether a `MultiEdit(...)` deny is enforced was never probed. The
warning answers that: it is not, because the runtime never matches it. The
audit stays as the dated record it is; this story adds one dated update to it.

**What this is not.** It is not a known protection gap. The two `Edit` rules
are in place and, per the warning text, cover `Write` and `MultiEdit` too.
Nobody has confirmed that by observation, and the claim comes from the CLI's
own message rather than from anything this repository has run, so the story
does not assert it: DV-2 (Owner: REVIEW) observes it in a throwaway session
and records what happened. The harm the story removes is that the suite
enforces rules the runtime discards, and the docs teach a wrong model of how
permissions work, which a consumer copying the pattern would carry into its
own `settings.json`.

**Why after HARNESS-047.** HARNESS-047 edits the same `deny` array (appending
`Bash(git log *--output*)` and `Bash(git diff *--output*)`) and the same suite
(`git_output_rules`), and its Contract C-1 places its two lines "after the
last `MultiEdit(...)` entry, as the last two elements". That position **is**
asserted: besides `git_output_rules`, which matches each line anchored
wherever it is, 047's RED added `C-1: settings.json is the live file with
exactly the two lines appended to deny`, which `cmp`s the live file against
a copy built from it with the two lines removed and re-appended after the
last deny element. Deleting earlier deny rules leaves it green, since both
sides derive from the live file; appending any deny entry after the two git
lines, or moving them off the end, turns it red. Two stories editing one
array in two worktrees would also collide on every line.
`depends_on: [HARNESS-047]`; this story starts once 047 is DONE and keeps
047's two lines as the last two elements, or changes that assertion in its
own RED and says why.

Required gate that fails if this story's artifact broke: `selftest`, through
`.claude/tests/settings.test.sh` (`bash scripts/selftest.sh settings`).

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC. -->

- **AC-1 (settings.json carries Edit rules only)** - Given the live
  `.claude/settings.json`, when its `deny` array is read, then for each of
  `current-story.env` and `last-gate-run` it holds exactly one rule naming
  that path, `Edit(./.claude/state/<file>)`; no `Write(...)`, `MultiEdit(...)`
  or `NotebookEdit(...)` rule names any path under `./.claude/state/`; the
  three `Read(...)` denies and HARNESS-047's two `Bash(git … *--output*)`
  denies are unchanged, the Bash pair still the last two elements; and the
  file is valid JSON.
- **AC-2 (a `no` row demands its Edit rule, and only that)** - Given a
  settings/README pair in which the README lists `last-gate-run` as
  hand-editable `no` and the settings file has no
  `Edit(./.claude/state/last-gate-run)` rule, when `problems` runs, then it
  prints exactly one line,
  `last-gate-run: not hand-editable, but settings.json has no "Edit(./.claude/state/last-gate-run)"`,
  and nothing else; and given the baseline pair with both `Edit` rules and no
  other state rule, it prints nothing.
- **AC-3 (a dead rule is a complaint)** - Given the baseline pair plus one
  rule `Write(./.claude/state/last-gate-run)`, when `problems` runs, then it
  prints exactly one line,
  `"Write(./.claude/state/last-gate-run)" is dead: only Edit(path) rules are matched by file permission checks`,
  and nothing else. The same holds for `MultiEdit(./.claude/state/current-story.env)`
  and for `NotebookEdit(./.claude/state/current-story.env)`, each with its own
  rule text in the line. A dead rule complains whether or not the README lists
  its path (a dead rule on `gate-logs/*.log`, a `yes` row, prints the dead-rule
  line and nothing about the row), so removing a dead rule is never reported
  as dropping protection.
- **AC-4 (the backwards check reads Edit rules)** - Given the baseline pair
  plus `Edit(./.claude/state/**)`, when `problems` runs, then it prints
  `denied path '**' is not in the README table`; plus
  `Edit(./.claude/state/gate-logs/*.log)` it prints
  `gate-logs/*.log: hand-editable, but settings.json denies it with "Edit(./.claude/state/gate-logs/*.log)"`;
  plus `Edit(./.claude/state/mystery)` it prints
  `denied path 'mystery' is not in the README table`; and a settings file
  with no `Edit(./.claude/state/…)` rule at all prints
  `settings.json denies nothing under .claude/state/` and one
  `not hand-editable, but settings.json has no "Edit(…)"` line per `no` row.
- **AC-5 (the documents say Edit, and name no tool list)** - Given
  `.claude/state/README.md` and `.claude/harness/rules.md`, when the suite
  reads them, then the README's section headed
  `## The \`Hand-editable\` column is enforced` contains the sentence
  `An \`Edit(path)\` rule is the only file deny rule the runtime matches, and it covers every file-editing tool.`
  on one line, and neither that section nor the `.claude/state/**` bullet of
  `rules.md` (the Non-negotiables bullet beginning `Do not commit
  \`.claude/state/**\``) contains the string `TOOLS`, `Write(`, `MultiEdit(`,
  `Write, Edit` or `` `Write`, `Edit` ``; and that `rules.md` bullet says the
  two files are "denied to `Edit` in `settings.json` - the one file deny rule
  the runtime matches, and it covers `Write` and `MultiEdit` too" (C-3's
  wording, lines joined and whitespace collapsed). *(Amended at RED: see
  `## Amendments`, A-2.)*
- **AC-6 (the suite has no tool list)** - Given `.claude/tests/settings.test.sh`,
  when it is read, then it defines no variable named `TOOLS`, and
  `bash scripts/selftest.sh settings` passes on the live pair with at least
  70 assertions executed (the declared floor; never lowered). *(Number
  amended at RED: see `## Amendments`.)*

Oracle partition: every criterion is **mechanical** (Contract C-6).

## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. -->

**Writes:** `.claude/settings.json`, `.claude/tests/settings.test.sh`, `.claude/state/README.md`, `.claude/harness/rules.md`, `docs/wiki/audits/state-deny-2026-09-10.md`

All five classify as `harness` or `docs` (`bash scripts/classify.sh` at
PLANNED), so the phase lock freezes none of them; the role boundary is
honoured by the agents. RED writes `settings.test.sh` only. GREEN writes
`settings.json`, `.claude/state/README.md` and `.claude/harness/rules.md`.
The audit update is the orchestrator's, written at GATES. No existing export
changes signature; `problems <settings> <readme>` keeps its name, arguments
and "one line per disagreement, silence means agreement" shape, so there is
no caller list.

**RED may amend any block below in place, with a reason; GREEN builds what
the amended block says.**

- **C-1 The deny array (settled - read out, never re-derived).** After GREEN,
  `.claude/settings.json`'s `deny` array is, in order and byte for byte:

      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./**/secrets/**)",
      "Edit(./.claude/state/current-story.env)",
      "Edit(./.claude/state/last-gate-run)",
      "Bash(git log *--output*)",
      "Bash(git diff *--output*)"

  The four removed lines are `Write(./.claude/state/current-story.env)`,
  `MultiEdit(./.claude/state/current-story.env)`,
  `Write(./.claude/state/last-gate-run)` and
  `MultiEdit(./.claude/state/last-gate-run)`. Nothing else in the file
  changes. HARNESS-047's `git_output_rules` keeps passing because it matches
  each of its lines anchored, not by position; its position assertion
  (`C-1: settings.json is the live file with exactly the two lines appended
  to deny`) keeps passing because the two git lines stay last and the
  removed lines all precede them.
- **C-2 `problems` in `settings.test.sh`.** Same signature. Three checks
  survive and one is new; `TOOLS` is deleted, together with the comment
  block that justified each tool and the `settings_for <tool>...` fixture
  generator's tool parameter (`settings_for` becomes `good_settings`, which
  writes exactly the two `Edit` rules).
  1. *Row answers yes/no* - unchanged, same complaint text.
  2. *Forwards* - for each row, `rule="\"Edit(./.claude/state/$path)\""`;
     a `no` row without it prints
     `<path>: not hand-editable, but settings.json has no "Edit(./.claude/state/<path>)"`,
     a `yes` row with it prints
     `<path>: hand-editable, but settings.json denies it with "Edit(./.claude/state/<path>)"`.
     The texts are the existing ones with the tool fixed to `Edit`; the
     fixtures assert whole output with `assert_eq`, not `assert_contains`,
     where AC-2 and AC-3 say "exactly one line".
  3. *Dead rules* (new) - every line of the settings file matching
     `"(Write|MultiEdit|NotebookEdit)\(\./\.claude/state/[^)]*\)"` prints
     `<rule> is dead: only Edit(path) rules are matched by file permission checks`,
     where `<rule>` is the matched text in its double quotes, e.g.
     `"Write(./.claude/state/last-gate-run)" is dead: …`. Exactly these three
     tool names: `Read(...)` and `Bash(...)` rules are matched by the runtime
     and are not the suite's business. This check runs before the backwards
     one and does not consult the README.
  4. *Backwards* - alternation is `Edit` only; complaint texts unchanged
     (`denied path '<p>' is not in the README table`,
     `denied path '<p>' is listed as hand-editable`,
     `settings.json denies nothing under .claude/state/`).
  The `describe "the two files that carry evidence stay denied"` block keeps
  its independence from the README and asserts the two `Edit` rules only.
  The three `TOOLS`-override cases and `an undocumented path under a later
  tool` are deleted; AC-3's cases replace them. The suite's header comment
  (the two paragraphs about `MultiEdit` and the "Verified separately by probe"
  paragraph) is rewritten to say what the runtime does: `Edit(path)` is the
  only file deny rule matched, it covers every file-editing tool, and the
  observation that backs that is DV-2 of this story.
- **C-3 The documents.** `.claude/state/README.md`, section "The
  `Hand-editable` column is enforced": the first paragraph says settings.json
  denies `Edit` on exactly the `no` rows and that the suite checks the two
  directions; the `TOOLS` paragraph is replaced by one that contains, on one
  line, the sentence AC-5 pins, followed by: the runtime prints a startup
  warning for a `Write(path)` or `MultiEdit(path)` rule and discards it, so
  the suite reports such a rule as dead rather than demanding it; and
  `NotebookEdit` needs no mention beyond "covered by the Edit rule". The
  "Verified by probe" paragraph (Bash append and `rm` refused) stands; it was
  observed, and this story does not contradict it. `rules.md`'s
  `.claude/state/**` bullet: "denied to `Write`, `Edit` and `MultiEdit`"
  becomes "denied to `Edit` in `settings.json` - the one file deny rule the
  runtime matches, and it covers `Write` and `MultiEdit` too"; the rest of
  the bullet is unchanged. `docs/wiki/audits/state-deny-2026-09-10.md` gains
  a dated section `## Update, 2026-10-10: the MultiEdit and Write rules were never matched`
  of a few lines: the warning text, that HARNESS-050 removed them, and that
  the probe the audit said it could not run is answered by DV-2 of this
  story. Nothing above it is edited.
- **C-4 The floor.** `.claude/tests/floors.conf` declares `settings | 39`
  (recorded again in `.claude/tests/selftest.test.sh`). *(Amended at RED:
  this said 27, the value before HARNESS-047 raised it to 39 at
  `floors.conf:59`; the rule - never lowered - is unchanged.)* This story removes
  assertions (`stay denied` 6 to 2, the three `TOOLS` cases, the later-tool
  case) and adds AC-3's, AC-4's and AC-5's. RED keeps the executed count at
  39 or above - each AC-3 case gets a control that the same fixture with the
  rule written as `Edit(...)` prints nothing - so the floor is **not
  lowered**. If the count rises, raising the floor is optional and goes in
  both files in the same commit, or in neither. *(RED raised it: 39 -> 70,
  in both files; the executed count measured at RED is 70.)*
- **C-5 Why no mutation touches the live `settings.json`.** The runtime reads
  `settings.json` live (`state-deny-2026-09-10.md`; HARNESS-047 C-3), so a
  mutation of the real file mid-session changes the rules the session runs
  under. DV-1 therefore runs `problems` over a **copy** of the live file with
  one line put back, taken with `cp` into the gitignored `.claude/state/`
  directory, and reaches it by mutating the suite's `SETTINGS=` line through
  `scripts/mutate.sh`. The copy is the real tree plus one line, not a
  hand-written fixture, which is what `rules.md` asks of a rule's probe.
- **C-6 Oracle partition.** Every criterion is **mechanical**: exact rule
  text, exact complaint lines, exact sentences. Nothing is invented or
  calibrated. The deny array (C-1), the complaint texts (C-2) and the README
  sentence (AC-5) are **settled**; RED reads them out.
- **C-7 Test-only dependencies.** None. Bash, awk, grep, sed only
  (`rules.md`, "Portability"); no JSON parser.

## Deferred verifications

- **DV-1 - defect put back (the story's central claim). Owner: GATES.**
  Condition: with `"Write(./.claude/state/last-gate-run)",` re-added to a
  copy of the committed `.claude/settings.json`, the suite **must** fail
  `the shipped pair agrees with itself` with the dead-rule line for that rule
  and nothing else; and with `"Edit(./.claude/state/last-gate-run)",`
  removed from a second copy, it **must** fail the same assertion with
  `last-gate-run: not hand-editable, but settings.json has no "Edit(./.claude/state/last-gate-run)"`
  and fail `Edit(./.claude/state/last-gate-run) is denied`. RED cannot run
  this: the dead-rule check does not exist yet, and the live file still holds
  the rule. Run each as
  `bash scripts/mutate.sh .claude/tests/settings.test.sh 's|^SETTINGS=.*|SETTINGS="$REPO_ROOT/.claude/state/dv1-<a|b>.json"|' -- bash scripts/selftest.sh settings`
  after writing the two copies, confirm the suite is green again on the
  restored file, and paste the output here.
- **DV-2 - the runtime claim behind the fix. Owner: REVIEW.** Condition: in
  a throwaway, logged-in, interactive Claude Code session started in a
  checkout of this story's branch at the PR head (so `.claude/settings.json`
  holds the two `Edit` rules only), (a) the startup output contains no line
  beginning `Permission deny rule`; (b) asked to use the `Write` tool to
  write one line to `.claude/state/last-gate-run`, the agent's attempt is
  refused by the permission system; (c) if the build offers `MultiEdit`,
  the same for it; if it does not, say so. Record the exact refusal text, or
  that the write went through, and `git status` afterwards. If (b) is NOT
  refused, the warning text was wrong, the `Write` rule was doing work, and
  the story stops at REVIEW rather than merging: put it to the user with the
  observation. Nothing in this repository can run this, which is why it is
  REVIEW's.

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. Omit the
     section if unused. -->

- **A-1. AC-6, the floor number (2026-10-10, RED). Approved by the user,
  2026-10-11, in conversation ("amend both").** Said: "at least 27
  assertions executed (the declared floor; never lowered)". Says: "at least
  70 assertions executed (the declared floor; never lowered)". Why: 27 was
  stale when the story was cut - HARNESS-047 had already raised the floor to
  39 (`.claude/tests/floors.conf:59`) - and this story's RED raised it again
  to 70, the count its rewritten suite executes. The criterion's substance,
  "at least the declared floor, never lowered", is unchanged; only the
  quoted number follows the floor. Directed by the orchestrator in the RED
  dispatch; the Test Developer made the edit; the user approved it.
- **A-2. AC-5, the forbidden spelling and the bullet's wording (2026-10-11,
  RED). Approved by the user, 2026-10-11, in conversation ("amend both").**
  - *Said:* neither the README section nor the `rules.md` bullet "contains
    the string `TOOLS`, `Write(`, `MultiEdit(` or `Write, Edit`".
  - *Says now:* the same four strings plus `` `Write`, `Edit` `` (the
    backticked spelling), and the `rules.md` bullet carries C-3's
    replacement wording.
  - *Why:* both documents write the wrong text with backticks
    (`` `Write`, `Edit` ``), so the needle `Write, Edit` matches neither of
    them, and on the `rules.md` bullet none of the four original needles
    matches today's wrong wording. As written, AC-5 could not fail against
    the defect it exists to catch (`rules.md`, "an assertion's needle is part
    of the assertion"). The intent - the documents stop naming a three-tool
    list - is unchanged, and GREEN builds the same thing C-3 already
    specified.
  - *How it was found:* the Test Developer, writing RED, saw that the
    literal needles left the bullet unchecked; it added the two assertions
    and escalated rather than amending.
  - *Orchestrator's own reproduction:* `grep -c "Write, Edit"` on
    `.claude/state/README.md` and `.claude/harness/rules.md` gives 0 and 0;
    `` grep -c '`Write`, `Edit`' `` gives 1 and 1. The two added assertions
    are red on today's tree (`settings: 59 passed, 11 failed`, rows "the
    README section does not say `Write`, `Edit`", "the rules.md state bullet
    does not say `Write`, `Edit`" and "… says the two are denied to Edit").

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-050` from `.claude/harness/models.conf`.
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

- RED: `test-developer` resolved **Opus 5.5** (`claude-opus-5-5`), as declared; no override in the dispatch. Escalated AC-5 rather than amending it; amendments A-1 and A-2 approved by the user. 2026-10-11.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

- Any change to what is protected: the two state files stay the only `no`
  rows, and no new row, rule or glob is added. The three `Read(...)` denies
  and HARNESS-047's two `Bash(...)` denies are untouched.
- Probing whether an `Edit` rule blocks a Bash append or `rm` of the path.
  The audit observed that it does; this story neither repeats nor rewrites
  that observation.
- Rewriting the audit's body. It is a dated record of what was believed on
  2026-09-10 and stays as written; the story adds one dated update below it.
- `NotebookEdit` beyond the dead-rule check: no rule for it is added, as
  before, and no probe of it is run.
- The `PreToolUse` hook matcher `Write|Edit|MultiEdit|NotebookEdit|Bash` in
  `settings.json`. Hook matchers are a different mechanism from permission
  rules; the warning says nothing about them, and the phase guard must keep
  seeing every editing tool.
- Consumers' own `settings.json` files. A consumer that copied the six-rule
  pattern gets the fix with its next refresh of `.claude/settings.json`; this
  story does not go looking.
- The `selftest`/`floors.conf` mechanism itself. C-4 says the floor is not
  lowered; nothing about how floors work changes.

## Design notes

<!-- Omitted: headless work. -->

## Test plan

All in `.claude/tests/settings.test.sh`, one suite, run by
`bash scripts/selftest.sh settings`. Every criterion is mechanical (C-6), so
every assertion is an exact string, an exact count or an exact line set; the
settled values (C-1's array, C-2's complaint texts, AC-5's sentence, C-3's
bullet wording) are read out of the story, never re-derived.

- **AC-1** - on the live `settings.json`'s deny elements (`array_lines deny`,
  trimmed, whole lines): each `Edit(./.claude/state/<f>)` present exactly once;
  exactly one deny element names each of the two paths; zero
  `Write(`/`MultiEdit(`/`NotebookEdit(` elements under `./.claude/state/`; the
  first three elements are the three `Read` denies; the last two are 047's
  `Bash` pair; the whole array equals C-1's seven lines in order; and the file
  passes `json_shape` (brackets balance, no string left open, no trailing
  comma before a close, no two values without a comma), with two controls on
  copies of the live file - a comma added to the last deny element, a comma
  removed from the first - each of which the reader must report.
- **AC-2** - fixture pair: baseline (`good_settings`, exactly the two `Edit`
  rules) prints nothing; `Edit(last-gate-run)` dropped prints exactly the C-2
  line and nothing else (`assert_eq`). A `no` row added with no rule prints
  exactly its `Edit` demand.
- **AC-3** - fixture pair plus one rule, whole output with `assert_eq`:
  `Write(last-gate-run)`, `MultiEdit(current-story.env)`,
  `NotebookEdit(current-story.env)` each print exactly their dead line; a
  `Write` on the `yes` row `gate-logs/*.log` prints only the dead line; a
  `Write(./.claude/state/**)` prints only the dead line (not the
  undocumented-path line); `Read(./.claude/state/last-gate-run)` prints nothing
  (exactly three tool names); the old six-rule shape prints four dead lines in
  file order. Controls, one beside each dead case: the same fixture with the
  rule spelled `Edit(...)` prints nothing on the `no` rows, and on the `yes`
  row prints the row complaint and no `is dead` (asserted with
  `assert_not_contains "is dead"`, because the yes-row Edit output is AC-4's
  two-line complaint, pinned there).
- **AC-4** - fixture pair plus `Edit(./.claude/state/**)`,
  `Edit(./.claude/state/gate-logs/*.log)` (both directions' lines, in order),
  `Edit(./.claude/state/mystery)`, and a settings file with no state rule (the
  two `no`-row demand lines then `settings.json denies nothing ...`), all
  whole-output `assert_eq`.
- **AC-5** - `readme_section` (heading to next `## `) and `state_bullet` (the
  bullet, joined, whitespace collapsed). Two reader controls ("Verified by
  probe" in the section, which C-3 keeps; `phase-guard-declined.log` in the
  bullet, past its first line). The AC sentence on one line of the section;
  the four AC needles plus one more, absent from both; and C-3's bullet
  wording present. The fifth needle, `` `Write`, `Edit` `` (backticked), is an
  addition: see the Handoff's "discovered" note.
- **AC-6** - the suite greps ITSELF for a definition and for a read of the
  tool-list variable, needle built from two halves so the file never holds
  it; a control fixture holding the old definition and read must give `1 1`.
  The selftest floor half of AC-6 is the `floors.conf` mechanism itself.
- **Kept** - HARNESS-027 AC-7 (2), HARNESS-029 AC-6 (5), HARNESS-047 (12),
  unchanged apart from one comment in 047's C-1 block ("after the MultiEdit
  entries" now reads "after the state-file Edit entries"). 047's C-1 placement
  assertion was run against a simulated post-GREEN file and stays green.
- **Out of scope pinned cheaply** - the `Read` rule under state is not dead
  (the PreToolUse matcher and the Bash denies are not touched by any
  assertion other than AC-1's tail check).

## Handoff: RED -> GREEN

**Command:** `bash scripts/selftest.sh settings` (or, for the assertion
output alone, `bash .claude/tests/settings.test.sh`).

**Files touched in RED:** `.claude/tests/settings.test.sh` (rewritten per
C-2), `.claude/tests/floors.conf` (`settings` 39 -> 70, with a dated history
paragraph), `.claude/tests/selftest.test.sh` (its hand-copied table,
`settings 70`), and this story (`## Test plan`, this handoff, the C-4 and AC-6
number amendments and the `## Amendments` entry). Nothing else.

**Baseline before RED:** `settings: 39 passed, 0 failed`; floor met (39/39).

**Failure output at RED** (2026-10-10, local, `bash .claude/tests/settings.test.sh`):

```
  the shipped pair agrees with itself
    FAIL no disagreements
         expected: 
         actual:   "Write(./.claude/state/current-story.env)" is dead: only Edit(path) rules are matched by file permission checks
         "MultiEdit(./.claude/state/current-story.env)" is dead: only Edit(path) rules are matched by file permission checks
         "Write(./.claude/state/last-gate-run)" is dead: only Edit(path) rules are matched by file permission checks
         "MultiEdit(./.claude/state/last-gate-run)" is dead: only Edit(path) rules are matched by file permission checks

  HARNESS-027 AC-7: the kept failing log has its own row

  the two files that carry evidence stay denied
    FAIL AC-1: exactly one deny rule names ./.claude/state/current-story.env
         expected: 1
         actual:   3
    FAIL AC-1: exactly one deny rule names ./.claude/state/last-gate-run
         expected: 1
         actual:   3
    FAIL AC-1: no Write(...) deny rule names a path under ./.claude/state/
         expected: 0
         actual:   2
    FAIL AC-1: no MultiEdit(...) deny rule names a path under ./.claude/state/
         expected: 0
         actual:   2
    FAIL AC-1/C-1: the deny array is exactly the seven C-1 rules, in order
         expected: (C-1's seven lines)
         actual:   (today's eleven: the seven plus the four Write/MultiEdit lines)

  each way of getting it wrong produces its own complaint

  HARNESS-050 AC-5: the documents say Edit, and name no tool list
    FAIL AC-5: the README section says, on one line, that Edit(path) is the only file deny rule matched
         no line of the section holds the sentence
    FAIL AC-5: the README section does not say TOOLS
         holds "TOOLS" at: ...The tool list lives in that suite as `TOOLS`, and it drives both directions of the...
    FAIL AC-5: the README section does not say `Write`, `Edit`
         holds "`Write`, `Edit`" at: ...`.claude/settings.json` denies `Write`, `Edit` and `MultiEdit` on exactly the `no`...
    FAIL AC-5: the rules.md state bullet does not say `Write`, `Edit`
         holds "`Write`, `Edit`" at: ...clined.log`. Two of those are denied to `Write`, `Edit` and `MultiEdit` in `settings.json` beca...
    FAIL AC-5/C-3: the rules.md state bullet says the two are denied to Edit, which covers Write and MultiEdit
         expected: denied to `Edit` in `settings.json` - the one file deny rule the runtime matches, and it covers `Write` and `MultiEdit` too
         actual:   ...e-guard-declined.log`. Two of those are denied to `Write`, `Edit` and `MultiEdit` in `set...

  HARNESS-050 AC-6: the suite has no tool list

  HARNESS-029 AC-6: a surviving mutations/*.new has a row, and the paragraph says what it means

  HARNESS-047: git log and git diff stay allowed, and their --output is denied

settings: 59 passed, 11 failed
```

(The C-1 whole-array diff is abbreviated above; the suite prints both lists
in full.) Under `selftest.sh` the floor line additionally reads
`FAIL settings  did 59 units of work, below the floor of 70` - the floor
counts PASSED assertions, so like HARNESS-047's RED the suite sits below its
floor until GREEN turns the 11 red ones green (70 passed = 70).

**Every red one is the right failure**: the assertion about the live
settings.json or the two documents, against today's text. None is an error,
a timeout or a reader miss (both AC-5 readers' controls pass).

**What GREEN must make true** (C-1, C-3, read out - not re-derived):
1. `.claude/settings.json`: delete exactly the four lines
   `"Write(./.claude/state/current-story.env)",`,
   `"MultiEdit(./.claude/state/current-story.env)",`,
   `"Write(./.claude/state/last-gate-run)",`,
   `"MultiEdit(./.claude/state/last-gate-run)",`. Nothing else moves. Fixes
   `no disagreements` and the five AC-1 reds.
2. `.claude/state/README.md`, section `## The \`Hand-editable\` column is enforced`:
   no `TOOLS`, no `Write(`, no `MultiEdit(`, no `Write, Edit`, and no
   `` `Write`, `Edit` `` anywhere in the section (heading to next `## `); one
   line holding exactly
   ``An `Edit(path)` rule is the only file deny rule the runtime matches, and it covers every file-editing tool.``
   Keep the "Verified by probe" paragraph (it is the reader's control). The
   current probe paragraph says "not just the `Write` and `Edit` tools" - that
   is not `` `Write`, `Edit` `` and passes, but read it against C-3 anyway.
3. `.claude/harness/rules.md`, the `- Do not commit \`.claude/state/**\``
   bullet: replace "denied to `Write`, `Edit` and `MultiEdit` in
   `settings.json`" with "denied to `Edit` in `settings.json` - the one file
   deny rule the runtime matches, and it covers `Write` and `MultiEdit` too".
   The suite joins the bullet's lines and collapses whitespace, so wrapping is
   free; the hyphen must be a plain ` - `, and the bullet must keep
   `phase-guard-declined.log` (the reader's control).

Measured: a copy of the live file with only step 1 applied, run through the
suite via `scripts/mutate.sh` on the `SETTINGS=` line, gave
`settings: 65 passed, 5 failed` - the five failures being exactly the AC-5
document assertions. So steps 2 and 3 account for the rest.

**One line per test** (AC in brackets):

| Test | Asserts | AC |
|---|---|---|
| `no disagreements` | `problems` on the live pair prints nothing | AC-1, AC-6, DV-1 |
| HARNESS-027 AC-7 (2) | unchanged | - |
| `Edit(./.claude/state/<f>) is denied` x2 | the Edit rule is a deny element exactly once | AC-1 |
| `AC-1: exactly one deny rule names ./.claude/state/<f>` x2 | one element names each path | AC-1 |
| `AC-1: no <T>(...) deny rule names a path under ./.claude/state/` x3 | T = Write, MultiEdit, NotebookEdit | AC-1 |
| `AC-1: the first three deny elements are the three Read denies` | unchanged Read denies | AC-1 |
| `AC-1: HARNESS-047's two Bash denies are still the last two` | Bash pair last | AC-1 |
| `AC-1/C-1: the deny array is exactly the seven C-1 rules, in order` | whole array | AC-1, C-1 |
| `AC-1: settings.json is well-formed JSON by bracket and comma shape` + 2 controls | JSON validity | AC-1 |
| `AC-2: the baseline pair ... agrees` | baseline prints nothing | AC-2 |
| `an unanswered column` | unchanged check 1 | - |
| `a no row with no rule demands its Edit rule, and only that` | exact line | AC-2 |
| `AC-2: a dropped Edit rule is named exactly, and nothing else` | exact line | AC-2 |
| `AC-4: a yes row denied by an Edit rule ...`, `re-widened Edit glob`, `undocumented path`, `no Edit rule at all ...` | exact output | AC-4 |
| `an unparseable README` | unchanged | - |
| `AC-3: a Write/MultiEdit/NotebookEdit rule on a no row is dead, and that is all` + 3 controls | exact dead line; Edit spelling prints nothing | AC-3 |
| `AC-3: a Write rule on a yes row is dead ...` + control | dead line only; Edit spelling not dead | AC-3 |
| `AC-3: a dead Write glob is dead, and not an undocumented path` | README not consulted | AC-3 |
| `AC-3: a Read rule under the state directory is not dead` | exactly three tool names | AC-3, C-2.3 |
| `AC-3: the old three-tools-per-file shape is four dead rules, in order` | many | AC-3 |
| `AC-5 control` x2 | readers found their text | AC-5 |
| `AC-5: the README section says, on one line, ...` | the sentence | AC-5 |
| `AC-5: the README section / rules.md state bullet does not say <n>` x10 | five needles x two docs | AC-5 |
| `AC-5/C-3: the rules.md state bullet says ...` | C-3's wording | AC-5, C-3 |
| `AC-6: settings.test.sh defines/reads no variable named the tool list` x2 + control | no tool list | AC-6 |
| HARNESS-029 AC-6 (5), HARNESS-047 (12) | unchanged | - |

**Export shape pinned.** None: this story has no production module. The
checker (`problems`, `good_settings`, `json_shape`, readers) lives in the test
file. What GREEN is pinned to is the exact text of three files, listed above.
Not constrained: the rest of the README section's wording (beyond the
sentence and the five absent needles; C-3 describes it), where in the
section the sentence sits, how the rules.md bullet wraps.

**Passed on arrival, and what earns each.** All of these are test-side code
written in this RED, so "on arrival" means against the checker just written,
not against production:
- the AC-2/AC-3/AC-4 fixture cases and their controls - earned by two
  mutations of the checker through `scripts/mutate.sh` (2026-10-10, local):
  dropping `NotebookEdit` from the dead-rule alternation turned exactly
  `AC-3: a NotebookEdit rule on a no row is dead, and that is all` red
  (`settings: 58 passed, 12 failed`, the other 11 being the RED set); making
  the backwards check read `MultiEdit` instead of `Edit` turned every AC-2,
  AC-3 and AC-4 fixture red (`43 passed, 27 failed`) - including the three
  `spelled Edit prints nothing` controls and `a Read rule ... is not dead`.
- `AC-1: no NotebookEdit(...) ...` - same counter as its two red siblings,
  parametrised by tool name; their red is its evidence.
- `AC-1: the first three ... Read`, `... Bash denies are still the last two`
  - probed with a copy of the live file in `.claude/state/` (Read(./.env.*)
  altered, the git log lines removed) via `mutate.sh` on `SETTINGS=`: both
  went red.
- `AC-1: ... well-formed JSON` - its two controls, which pass now, are the
  evidence the reader fires.
- `AC-6` - a control on the suite itself: it passes because RED deleted the
  tool list; the fixture control (`1 1`) shows both readers find the old
  shape.

**Negative controls - expected values** (measured inside the suite, which
does execute in RED - nothing here fails at import; confirm unchanged in
GREEN):

| Control | Expected | Measured at RED |
|---|---|---|
| AC-1 trailing comma on last deny element | output contains `trailing comma before line` | yes (pass) |
| AC-1 comma missing after first deny element | output contains `missing comma before line` | yes (pass) |
| AC-3 Write(last-gate-run) spelled Edit | `""` | `""` |
| AC-3 MultiEdit(current-story.env) spelled Edit | `""` | `""` |
| AC-3 NotebookEdit(current-story.env) spelled Edit | `""` | `""` |
| AC-3 yes-row Write spelled Edit | no `is dead`; AC-4's two lines | as expected |
| AC-5 README reader | section contains `Verified by probe` | yes |
| AC-5 bullet reader | bullet contains `phase-guard-declined.log` | yes |
| AC-6 readers on the old shape | `1 1` | `1 1` |
| HARNESS-047 controls | unchanged | pass |

**DV-1 prediction (GATES owns it; RED cannot run it against the shipped
file).** Simulated now on a copy of today's file with GREEN's step 1 applied
(not the committed post-GREEN file), via the exact DV-1 `mutate.sh` command
shape:
- (a) `"Write(./.claude/state/last-gate-run)",` re-added before the Edit
  line: `no disagreements` red with exactly
  `"Write(./.claude/state/last-gate-run)" is dead: only Edit(path) rules are matched by file permission checks`
  and nothing else; also red, by design of AC-1: `exactly one deny rule names
  ./.claude/state/last-gate-run` (actual 2), `no Write(...)` (actual 1), and the
  C-1 whole-array check. `settings: 61 passed, 9 failed` on the simulated file
  (the other 5 being AC-5's, which GREEN's docs will remove - so after GREEN
  expect `66 passed, 4 failed`).
- (b) `"Edit(./.claude/state/last-gate-run)",` removed: `no disagreements` red
  with exactly
  `last-gate-run: not hand-editable, but settings.json has no "Edit(./.claude/state/last-gate-run)"`;
  `Edit(./.claude/state/last-gate-run) is denied` red; also `exactly one ...
  last-gate-run` (actual 0) and the C-1 whole-array check. After GREEN expect
  `66 passed, 4 failed`.
- 047's `C-1: settings.json is the live file with exactly the two lines
  appended to deny` stays green in both (both copies derive from the file).
GATES must still run DV-1 against the committed post-GREEN file and paste the
output; this is a prediction, not the verification.

**Timings.** Local only (Windows 11, Git Bash): the suite runs in a few
seconds; no timeout is involved - harness suites carry none.

**Discovered - should change nothing in GREEN, but the orchestrator should
know:**
1. **AC-5's `Write, Edit` needle cannot fail on today's text.** Both
   documents write the phrase with backticks, `` `Write`, `Edit` ``, so the
   AC's literal needle is absent from them now and would stay absent if GREEN
   changed nothing. On the rules.md bullet, none of AC-5's four needles
   matches today's wrong text at all. The suite therefore adds a fifth
   needle, the backticked spelling, and pins C-3's replacement wording; those
   are the bullet's two red assertions. The AC is not amended (adding a
   needle tightens the test, it does not change what the AC asks); the
   orchestrator may want to correct the AC's needle in an amendment.
2. The selftest floor counts PASSED assertions, so a RED that raises the
   floor to its executed count shows a floor failure until GREEN (as 047's
   did). AC-6's "at least N executed" is in practice "at least N passed".

**Other checks at the end of RED** (local, 2026-10-10):

    bash scripts/selftest.sh            -> assertion floors: 25 of 26 suite(s) met their declared floor.
                                           1 of 26 harness suite(s) FAILED.   (settings only; `selftest` suite green with the 70 in its table)
    bash scripts/check-sigpipe.sh       -> check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
    bash scripts/check-grep-count.sh    -> check-grep-count: scanned 49 shell file(s), 0 finding(s)
    bash scripts/gates.sh --fast        -> All required gates passed (0 ran, 5 unconfigured, 0 known).  exit 0
    bash scripts/mutate.sh --check      -> mutate: no stranded mutation; nothing of a previous run is in the tree.

`gates.sh --fast` judges nothing here: this repository's `project.conf` is
not bootstrapped, all five gates are UNCONFIGURED, and the suite is judged by
`selftest` (CI's job) instead.

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. -->

## Gate results

<!-- Written by scripts/gates.sh itself on every full run. -->

## Gate probes

<!-- Omitted: this story adds or changes no gate. -->

## Notes

- Filed 2026-10-10 from the user's startup-warning report. `docs/backlog/epics/`
  is empty and HARNESS-047 has no epic, so `epic:` is blank.
- `bash scripts/plan.sh conflicts` at PLANNED: output recorded in the PR body.
  HARNESS-047 shares `.claude/settings.json` and
  `.claude/tests/settings.test.sh`; resolved by `depends_on`, not by running
  the two side by side.
