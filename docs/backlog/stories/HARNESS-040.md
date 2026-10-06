---
id: HARNESS-040
title: The refresh adds missing harness-shipped docs files and never overwrites one
slug: the-refresh-adds-missing-harness-shipped
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-040-the-refresh-adds-missing-harness-shipped
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/refresh-harness.sh, .claude/harness/docs-shipped.conf, .claude/tests/refresh.test.sh, .claude/tests/shipped-docs.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, README.md]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

GitHub issue #104 (ryanczhang7/agentic-dev-harness), section 1, **Symptom A**,
measured on fantasy-world-builder at harness release 64 and re-checked here
against release 83 (`7bc2d59`): `scripts/refresh-harness.sh` leaves all of
`docs/**` untouched - the header says so at `:28-30` (`LEFT  project-owned,
or needs a human: project.conf, docs, ...`) and the summary at `:427-428`
(`LEFT untouched (project-owned): .claude/harness/project.conf, docs/**, ...`).
That is right for everything an agent writes for the project. But the harness
also ships a file under `docs/` that its own commands depend on:
`docs/wiki/audits/TEMPLATE.md` (added upstream in `2dc905d`, 2026-09-09) is
named by `.claude/commands/audit-mutations.md:32` ("Write the audit to the
structure in `docs/wiki/audits/TEMPLATE.md`") and by
`.claude/agents/mutation-tester.md:37` ("following
`docs/wiki/audits/TEMPLATE.md`"). A project vendored before that commit never
receives it - two re-vendors of fantasy-world-builder (releases 45 and 64)
delivered the command and the agent that name the template and not the
template - and nothing reports that it is missing. The project's first
`/audit-mutations` follows a file that is not there. (fantasy-world-builder
added it locally in WORLD-111; every consumer on this machine now has a copy,
which is why DV-4 below removes it from a scratch copy to reproduce.)

Two fixes, from the issue's first and third suggestions, and the second is
what stops the first from repeating:

1. **The refresh ADDS a harness-shipped file under `docs/` that the project
   lacks, and never overwrites one it has.** The set is an explicit allow-list
   in a conf file upstream ships, `.claude/harness/docs-shipped.conf`, read
   from the upstream checkout being installed (the procedure belongs to the
   release being installed, `refresh-harness.sh:85-118`). Each listed file is
   reported `ADDED` or `KEPT`, in the vocabulary the summary already uses.
2. **A self-test rule over the tree:** every literal `docs/` path a command,
   agent or skill names is either on the `ship` list (and the file exists) or
   declared `written` - a file the project's own agents produce, which the
   refresh must never create. The line between the two is drawn in the conf
   file, not inferred: `docs/wiki/product-brief.md` is `written`,
   `docs/wiki/audits/TEMPLATE.md` is `ship`, and a reference that is neither
   fails `bash scripts/selftest.sh shipped-docs` with a line naming the file
   and the path. The next template cannot be named by a command without being
   delivered.

The gate that fails if this story's artifact breaks is the `selftest` gate
(`.claude/harness/project.conf`; CI's `bash scripts/selftest.sh` at
`.github/workflows/gates.yml:72`), which runs every suite under
`.claude/tests/` - `refresh` for fix 1 and the new `shipped-docs` for fix 2.
No optional gate is involved, so `required_gates` stays empty.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

- **AC-1 (the bug: a missing shipped file is added)** — Given an upstream
  checkout whose `.claude/harness/docs-shipped.conf` has the line
  `ship | docs/wiki/audits/TEMPLATE.md` and whose tree holds that file, and a
  clean project between stories that has `docs/wiki/` but no
  `docs/wiki/audits/TEMPLATE.md`, when `bash scripts/refresh-harness.sh <up>`
  runs from the project, then it exits 0, the project's
  `docs/wiki/audits/TEMPLATE.md` exists and is byte-identical to upstream's
  (`cmp`), and the output contains exactly one line
  `  ADDED     docs/wiki/audits/TEMPLATE.md  (upstream ships it and you had no copy)`
  (whole-line match, C-3). Today the file is not created and no such line is
  printed - that is the defect reproduced.
- **AC-2 (control: an existing copy is never overwritten)** — Given the same
  upstream and a project whose `docs/wiki/audits/TEMPLATE.md` holds content
  that differs from upstream's (a project-edited template), when the refresh
  runs, then the project's file is byte-identical to what it held before
  (`cmp` against a copy taken before the run), the output contains exactly one
  line `  KEPT      docs/wiki/audits/TEMPLATE.md  (yours; upstream never overwrites docs/)`
  and zero `ADDED` lines naming that path. The same holds when the project's
  copy is byte-identical to upstream's: KEPT, never ADDED.
- **AC-3 (control: only the list is delivered)** — Given an upstream whose tree
  holds `docs/wiki/product-brief.md` and `docs/wiki/README.md` and whose
  `docs-shipped.conf` does not list either as `ship` (it lists
  `docs/wiki/product-brief.md` as `written`), and a project that has neither,
  when the refresh runs, then neither file exists in the project afterwards,
  no `ADDED` or `KEPT` line names either path, and the project's other docs
  (`docs/wiki/stack.md`, as the suite already asserts) are untouched. And given
  an upstream that ships **no** `docs-shipped.conf` at all, when the refresh
  runs, then it exits 0, prints no `ADDED` or `KEPT` line naming a `docs/`
  path, and creates nothing under the project's `docs/`.
- **AC-4 (dry run reports, writes nothing)** — Given the AC-1 project and
  upstream, when `bash scripts/refresh-harness.sh --dry-run <up>` runs, then
  the output contains the AC-1 `ADDED` line exactly once and the line
  `Dry run: nothing was written.`, `docs/wiki/audits/TEMPLATE.md` still does
  not exist in the project, and the `cksum` fingerprint of every file under
  `$PROJ/docs` is unchanged - the existing dry-run guard
  (`refresh.test.sh:201-205`) extended to cover `docs/`. Given the AC-2
  project, the dry run prints the `KEPT` line once.
- **AC-5 (the reference rule, over this tree and over a regressed one)** —
  (a) Given this repository, when `bash scripts/selftest.sh shipped-docs`
  runs, then `shipped_docs_problems "$REPO_ROOT"` prints nothing and the suite
  passes: every literal `docs/` reference in `.claude/commands/*.md`,
  `.claude/agents/*.md` and `.claude/skills/**/*.md` (the 24 listed in C-6)
  is covered by `.claude/harness/docs-shipped.conf`, and every `ship` path
  exists. (b) Given a fixture tree built compliant by construction, with one
  command file changed to name `docs/wiki/audits/CHECKLIST.md` - a path on
  neither list - when `shipped_docs_problems <fixture>` runs, then it prints
  exactly one line, naming that command file and that path, and nothing else.
  (c) Given the compliant fixture with its `ship` entry's file deleted, it
  prints exactly one line naming the conf and the missing path. (d) Given the
  compliant fixture with the regressed command file and ALSO a `written`
  directory entry covering the new path's directory, it prints nothing - a
  file under a `written` directory is the rule's written limit (C-5), and
  this assertion records it.
- **AC-6 (this repository's own refresh and the summary say so)** — Given this
  repository's `scripts/refresh-harness.sh`, when it runs with `--dry-run`
  against itself (`bash scripts/refresh-harness.sh --dry-run .`, which the
  suite's "identical copies hand over to nobody" control already exercises),
  then the summary's `LEFT untouched` paragraph names `docs/**` as
  project-owned AND says the files `docs-shipped.conf` lists are added when
  missing and never overwritten (C-4 wording), and
  `.claude/harness/docs-shipped.conf` is reported `REPLACED` as a single
  upstream-owned file - so a consumer's selftest can read the same list its
  refresh used.

Negative controls, named: AC-2 (an edited copy survives byte-identical), AC-3
(a project-owned file the upstream happens to hold is NOT created; an upstream
without the conf adds nothing), AC-4 (dry run creates nothing), AC-5(b)-(c)
(the rule fires on one regressed site and on a ghost `ship` entry), AC-5(d)
(the limit, recorded rather than hidden).

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

**Writes:** `scripts/refresh-harness.sh`, `.claude/harness/docs-shipped.conf`, `.claude/tests/refresh.test.sh`, `.claude/tests/shipped-docs.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `README.md`

Every path but `README.md` classifies as `harness` and `README.md` as `docs`
(`bash scripts/classify.sh` on each, at PLANNED), so the phase lock freezes
none of them in any phase. The role boundary is honoured by the agents: RED
writes only `refresh.test.sh`, `shipped-docs.test.sh`, `floors.conf` and
`selftest.test.sh`; GREEN writes only `refresh-harness.sh`,
`docs-shipped.conf` and `README.md`. **The conf file is GREEN's**, not RED's:
it is production surface (the refresh reads it), so RED's suites build their
own conf fixtures and the AC-5(a) real-tree assertion is red until GREEN
writes the file. No signature of any existing export changes; there is no
caller list.

- **C-1 The conf file, `.claude/harness/docs-shipped.conf`** (new; GREEN).
  Grammar is `floors.conf`'s / `project.conf`'s, so it is one vocabulary:
  `#` comments and blank lines ignored, fields `|`-separated, leading and
  trailing space trimmed. Two kinds, one path per line, repository-relative:

      ship    | docs/wiki/audits/TEMPLATE.md
      written | docs/wiki/product-brief.md
      written | docs/wiki/stack.md
      written | docs/wiki/architecture.md
      written | docs/wiki/environment.md
      written | docs/wiki/design/tokens.md
      written | docs/wiki/design/components.md
      written | docs/wiki/design/layout.md
      written | docs/wiki/design/accessibility.md
      written | docs/wiki/design/voice.md
      written | docs/backlog/epics/
      written | docs/backlog/stories/

  **The line, in one sentence each:** `ship` is a file the harness ships
  verbatim under `docs/` that a command, agent or skill tells an agent to
  read or copy - a template, never a page an agent fills in; `written` is a
  path the project's own agents produce (`/create-product`, `/plan-product`,
  `/setup-environment`, the Lead Designer, `new-story.sh`), which the refresh
  must never create and the rule must never demand. A `written` entry ending
  in `/` is a directory and covers everything beneath it; the only two are
  the backlog directories, because `new-story.sh` writes there and the skill
  example `docs/backlog/epics/EPIC-03.md` is a file no tree holds. The design
  pages are listed as files, not as `docs/wiki/design/`, precisely so that a
  future template dropped into that directory is NOT covered by a directory
  entry and the rule fires (AC-5(d) is the limit for the two directories that
  remain). **Considered and left off:** `docs/wiki/README.md` and
  `docs/backlog/README.md` are shipped verbatim too, but nothing instructs an
  agent to read them, every consumer on this machine has both from its first
  vendoring, and a later story may add them as `ship` with one line each.
  `docs/wiki/audits/<scope>-<date>.md` is a pattern (C-6) and needs no entry.
  The header comment says all of this in prose, with the grammar, as
  `floors.conf:1-9` does.
- **C-2 Where in `scripts/refresh-harness.sh`** (verified at PLANNED against
  release 83). Three edits, and the line discipline matters because
  `sigpipe.test.sh:569-572` pins `scripts/refresh-harness.sh:134`, `:135`,
  `:147` and `:148` as status-discarded lines - **nothing above line 148 may
  gain or lose a line**. (a) The header vocabulary at `:25-30` gains `ADDED`
  by rewriting those six lines in place, same line count - e.g. fold the
  `LEFT` entry's third line into the second and use the freed line for
  `ADDED     upstream ships it under docs/ and you had no copy (never overwrites)`.
  (b) `.claude/harness/docs-shipped.conf` joins the single-file REPLACED list
  at `:399-401` (so consumers' `shipped-docs` suite reads the list their
  refresh used, AC-6) and the LOCAL candidate list at `:307-308` (so a
  consumer that edits it is warned before a refresh replaces it). (c) The new
  block goes **after** `say "  REPLACED  scripts/*.sh ..."` / `say ""` at
  `:414-415` and **before** the `LEFT for you to merge` block at `:417-418`: a
  function `ship_missing_docs` defined there and called once, on a line of its
  own, spelled exactly `ship_missing_docs` (DV-2 mutates that line;
  `grep -cx 'ship_missing_docs' scripts/refresh-harness.sh` prints `1` after
  GREEN). Its body: read `ship` paths from `$UP/.claude/harness/docs-shipped.conf`
  (absent file: return silently - an upstream without the conf predates this
  story's script and has nothing to add, AC-3); for each path `p`: skip
  silently if `$UP/$p` is not a file (the `shipped-docs` suite, not the
  refresh, is where a ghost entry is reported); then exactly

      if [ -e "$PROJ/$p" ]; then
        say "  KEPT      $p  (yours; upstream never overwrites docs/)"
      else
        act "mkdir -p \"$PROJ/$(dirname "$p")\" && cp \"$UP/$p\" \"$PROJ/$p\""
        say "  ADDED     $p  (upstream ships it and you had no copy)"
      fi

  The guard `[ -e "$PROJ/$p" ]` is spelled once in the file in exactly that
  form (DV-1 mutates it; `grep -c '\[ -e "\$PROJ/\$p" \]' scripts/refresh-harness.sh`
  prints `1`). `act` is the existing dry-run wrapper (`:145`), so AC-4 costs
  nothing extra; `say` is `:144`. Then `say ""` once after the loop only if at
  least one line was printed, so an upstream with nothing to add leaves the
  output shape unchanged. The block is a `ship` consumer only: `written` lines
  are ignored by the refresh.
- **C-3 The two report lines**, pinned byte for byte so RED's whole-line
  needles and GREEN's `say` cannot drift. Two leading spaces, the word padded
  to 8 and two more spaces (the existing `  REPLACED  ` and `  KEPT      `
  shape at `:347`, `:396`, `:404`), the path, two spaces, the parenthesis:

      ADDED     docs/wiki/audits/TEMPLATE.md  (upstream ships it and you had no copy)
      KEPT      docs/wiki/audits/TEMPLATE.md  (yours; upstream never overwrites docs/)

  (each preceded by two spaces). RED asserts them with `exact_count`
  (`refresh.test.sh:896`) as `:901-903` do for the KEPT project-floors line - whole-line
  `grep -cxF`, count 1 - and asserts count 0 for the line that must not
  appear. `KEPT` is reused rather than a new word because its existing meaning
  ("yours, survives") is the meaning here; the parenthesis says which case.
- **C-4 The summary and the README** (GREEN). `:427-428` becomes (line count
  free below `:148`):

      LEFT untouched (project-owned): .claude/harness/project.conf, docs/**,
        .gitignore, .github/workflows/**, and everything outside .claude and scripts.
        Under docs/, the files .claude/harness/docs-shipped.conf lists are ADDED
        when you have no copy and KEPT when you do - never overwritten.

  RED asserts the third line whole (`exact_count`, count 1, AC-6). `README.md:479`,
  the row `` | `.claude/hooks/`, `.claude/tests/` | `docs/**` — wiki, backlog, stories, audits | ``,
  gains after `audits`: `; files `docs-shipped.conf` lists are added when
  missing, never overwritten`. `README.md` is `docs`, writable in GREEN; no
  assertion reads it.
- **C-5 The rule, `.claude/tests/shipped-docs.test.sh`** (new suite; RED).
  Modelled on `policy.test.sh:1-80`: a function `shipped_docs_problems <root>`
  printing one line `<relative-path>: <reason>` per violation, always
  returning 0, silent on a compliant tree; run over `$REPO_ROOT` (must print
  nothing, AC-5(a)) and over a fixture built compliant by construction with
  one site regressed (must print exactly one line naming it, AC-5(b)). The
  second makes the first mean something. Rules, each one sentence:
  **R1** every `ship` path must be a regular file under `<root>` (AC-5(c):
  `.claude/harness/docs-shipped.conf: ship path docs/... does not exist`);
  **R2** every literal reference (C-6) in `<root>/.claude/commands/*.md`,
  `<root>/.claude/agents/*.md` and `<root>/.claude/skills/**/*.md` must equal
  a `ship` path, equal a `written` file, or lie under a `written` directory
  (`.claude/commands/audit-mutations.md: names docs/wiki/audits/CHECKLIST.md, which docs-shipped.conf neither ships nor declares written`);
  **R3** no `ship` path may lie under a `written` directory (the conf
  contradicting itself); **R4** a kind other than `ship` or `written` is a
  problem naming the line. The suite also asserts R2's needle on the real tree
  is live by counting the literal references it extracts from `$REPO_ROOT`:
  **at least 24** (C-6's count today; a floor, because a later command may add
  one), so an extraction that matches nothing cannot pass vacuously. Written
  limit, recorded as AC-5(d): a path under a `written` directory is covered
  whatever its basename, so a template placed under `docs/backlog/epics/` or
  `docs/backlog/stories/` is invisible to R2. Platform-independent `awk`
  (CI's `mawk`): no `gensub`, no `--re-interval`, no `\<`; `grep -oE` is
  available on both.
- **C-6 What a literal reference is** (the extraction, pinned so RED and the
  rule agree). From each scanned file, every token matching the ERE
  `docs/[A-Za-z0-9_./-]*`, with one trailing `.` stripped; a token that ends
  in `/` is a **pattern** - the ERE stops at `<`, `*`, `{` and a trailing `/`
  is what `docs/wiki/audits/<scope>-<date>.md`, `docs/backlog/stories/*.md`,
  `docs/wiki/design/**` and `docs/wiki/` leave behind - and is skipped. The
  remaining tokens are literal references. Measured on this tree at PLANNED
  (release 83) with exactly that pipeline: **24 literal references, 14
  distinct paths**, all covered by C-1 -
  `docs/wiki/architecture.md` (lead-po.md, plan-product.md, plan-story.md),
  `docs/wiki/product-brief.md` (lead-po.md, create-product.md, plan-product.md),
  `docs/wiki/stack.md` (lead-po.md, plan-product.md, setup-environment.md,
  stack-profiles/SKILL.md, godot.md x2, bootstrap-story.md x2),
  `docs/wiki/environment.md` (setup-environment.md, quality-gates/SKILL.md,
  stack-profiles/SKILL.md), `docs/wiki/audits/TEMPLATE.md`
  (audit-mutations.md:32, mutation-tester.md:37), the five
  `docs/wiki/design/*.md` (design-system/SKILL.md:16-20, plus tokens.md again
  at reference/tokens.md:29), and `docs/backlog/epics/EPIC-03.md`
  (story-authoring/reference/epics.md:13). No non-`.md` file exists under
  `.claude/skills`. `README.md` and `CLAUDE.md` are not scanned: they describe
  the harness rather than instruct an agent.
- **C-7 Oracle partition.** Every criterion is **mechanical**: pin exactly.
  AC-1..AC-4 are whole-line counts of C-3's lines plus `cmp`/`[ -e ]`/`cksum`
  on files; AC-5 is a problem-line count (0, 1, 1, 0) with the path and file
  in the needle; AC-6 is a whole-line count. Nothing is settled-by-measurement
  (the 24 of C-6 is a measured floor RED reads out, not a threshold to tune)
  and nothing is oracle-free. RED should not invent a metric.
- **C-8 Fixtures (RED).** In `refresh.test.sh`: the upstream fixture (`:26-43`)
  gains `docs/wiki/audits/TEMPLATE.md` (`upstream audit template`),
  `docs/wiki/product-brief.md` (`upstream brief, NOT shipped`),
  `docs/wiki/README.md` and `.claude/harness/docs-shipped.conf` with C-1's
  `ship` line and `written | docs/wiki/product-brief.md` - committed into the
  fixture repository's history (`:54-59`) so the LOCAL walk still sees every
  blob as shipped. `new_project` (`:61-88`) stays without a template (AC-1's
  state); AC-2 writes a project copy before the run. The AC-3 no-conf case
  uses a second upstream directory (a copy of `$UP` with the conf removed, as
  the `half-a`/`half-b` trees at `:118` are built) - not a mutation of `$UP`,
  which later blocks reuse. The dry-run fingerprint at `:201-203` adds
  `"$PROJ/docs"` to its `find`. The AC-6 whole-line check runs on the
  identical-copies control already at the "procedure belongs to the release"
  block (`describe` at `:754`). In `shipped-docs.test.sh`: a fixture tree with
  one command, one agent, one skill file, and a conf - compliant by
  construction - then one regression per assertion, each in a fresh copy.
- **C-9 Counts (RED).** `refresh` is floored at 122 (`floors.conf:55`) and
  recorded at 122 in `selftest.test.sh` COUNTS (`:546`); measured at PLANNED,
  `bash scripts/selftest.sh refresh` executes **132** (`132 assertions
  executed, 122 declared`, 80 s wall on this machine with `SELFTEST_JOBS=1` -
  the suite is slow, so RED runs it alone, not in a loop). RED raises both to
  the number its red run measures (new assertions execute and fail, so they
  count) and adds `floor | shipped-docs | <n>` plus a `shipped-docs <n>`
  COUNTS row for the new suite, with the before/after paragraph in
  `floors.conf` the way `:228-235` records earlier raises. Every suite in
  `.claude/tests` must have a floor or the full run fails (`selftest.sh:249-260`).
  Note from HARNESS-039 C-7 still holds: `executed_count` compares PASSED, so
  both suites sit at their floors and failing until GREEN lands.
- **C-10 Not touched.** `sigpipe.test.sh` (C-2's line discipline keeps its
  pins true; if GREEN cannot hold line 148, it says so in `## Notes` and the
  pins move in a RED return, never by GREEN). `check-sigpipe.sh` and
  `check-grep-count.sh` run in CI (`gates.yml:120,129`) over every harness
  shell file, so the new block uses no `grep -c ... || printf 0` fallback and
  no `| head -1` pipeline under `pipefail` that a SIGPIPE could fail. No
  `.claude/state/README.md` row: the refresh writes no new state file.
- **C-11 Test-only dependencies.** None; bash, awk, grep, coreutils, git.

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
         reason. check-boundaries.sh refuses a PR that has neither. A result
         counts only as a block: a line beginning with three backticks or
         three tildes (a fence), or a line indented by exactly four spaces.
         Prose does not count, nor inline code in backticks, nor a tab, nor
         anything inside an HTML comment
     Schedule it into GATES rather than RED where you can: source is writable
     there, and a story that bounced back to RED mid-cycle gets its corrected
     assertions earned by the same mutation, for free. How many entries is the
     budget in rules.md, `Mutation work per story`: by default ONE
     "defect put back" entry for the story's central claim, run against the one
     suite that holds its assertion. A format or codec story may add one wrong VALUE
     mutation - a codec that is uniformly wrong round-trips through itself
     perfectly. Exhaustive earning of assertions that passed on arrival is not
     an entry here; it goes to `/audit-mutations`. -->

Budget per `rules.md`, "Mutation work per story": one "defect put back" for
the central claim - and this claim has two halves with opposite failure modes,
so it gets two (DV-1 the destructive half, DV-2 the half the issue reported);
one probe against a REAL line of the tree for the rule the story adds (DV-3);
and one read-only real-consumer reproduction (DV-4), which is not a mutation
and costs one dry run. No test here is written against code that already
exists, so nothing is owed for earned corrections. `## Gate probes` is omitted:
no gate, command or `evidence` line changes; the real-tree probe lives in
DV-3 and nowhere else. Each mutation runs through `scripts/mutate.sh` with ONE
`sed` expression, against the one suite holding its assertions, one at a time,
and the restore is verified by the script.

- **DV-1 (defect put back: the refresh overwrites).** Owner: GATES. With the
  existence guard of C-2 replaced by `false`, AC-2's assertions **must** go
  red (the project's edited `TEMPLATE.md` is replaced by upstream's, `cmp`
  fails; its `KEPT` line count drops to 0 and an `ADDED` line appears for it)
  while AC-1, AC-3 and AC-4's dry-run assertions stay green. RED cannot run
  it: the guard does not exist in RED.

      bash scripts/mutate.sh scripts/refresh-harness.sh 's|\[ -e "\$PROJ/\$p" \]|false|' -- bash scripts/selftest.sh refresh

  RED predicts the exact number of assertions that go red (at least the AC-2
  `cmp`, its KEPT count and its ADDED count, for both the differing and the
  identical copy) in `## Handoff`; GATES pastes the run and the matching
  count. Result:

  _(pasted by GATES)_

- **DV-2 (defect put back: the refresh adds nothing - the issue's symptom).**
  Owner: GATES. With the call to `ship_missing_docs` turned into a no-op,
  AC-1's assertions **must** go red (no file, no `ADDED` line), AC-2's `KEPT`
  count goes to 0, AC-4's dry-run `ADDED` count goes to 0, and AC-3's
  negative controls stay green - which is the point: a refresh that adds
  nothing passes every "never creates" assertion, and only the positives
  catch it.

      bash scripts/mutate.sh scripts/refresh-harness.sh 's/^ship_missing_docs$/: ship_missing_docs/' -- bash scripts/selftest.sh refresh

  RED predicts the count in `## Handoff`; GATES pastes the run. Result:

  _(pasted by GATES)_

- **DV-3 (the rule, against a REAL line of this tree).** Owner: GATES. With
  `.claude/commands/audit-mutations.md:32`'s reference changed from
  `docs/wiki/audits/TEMPLATE.md` to `docs/wiki/audits/CHECKLIST.md` - a
  template no list names, which is exactly the next-template failure this
  rule exists for - `bash scripts/selftest.sh shipped-docs` **must** fail with
  the AC-5(a) real-tree assertion red and its problem line naming
  `.claude/commands/audit-mutations.md` and `docs/wiki/audits/CHECKLIST.md`;
  every fixture assertion stays green. RED cannot run it: in RED the suite's
  real-tree assertion is already red for want of the conf, so a second red
  would prove nothing.

      bash scripts/mutate.sh .claude/commands/audit-mutations.md 's|docs/wiki/audits/TEMPLATE.md|docs/wiki/audits/CHECKLIST.md|' -- bash scripts/selftest.sh shipped-docs

  Result:

  _(pasted by GATES)_

- **DV-4 (the fix, against a real consumer, read-only).** Owner: GATES. Copy
  `D:\manga-translator` (release 82, has its own `docs/wiki/audits/TEMPLATE.md`
  today) to a scratch directory, delete the copy's
  `docs/wiki/audits/TEMPLATE.md`, and run
  `bash <this-tree>/scripts/refresh-harness.sh --dry-run <this-tree>` from the
  scratch copy: the output **must** contain the AC-1 `ADDED` line for
  `docs/wiki/audits/TEMPLATE.md` exactly once and `Dry run: nothing was
  written.`, and the scratch copy must still lack the file afterwards. Then
  the same dry run on an untouched scratch copy prints the `KEPT` line once.
  Nothing in `D:\manga-translator` itself is written or read beyond the copy.
  Not a mutation; it is the probe the fixtures cannot give, because the
  fixture upstream is a stand-in and the fixture project is twelve files. RED
  cannot run it: there is no block to run. Result:

  _(pasted by GATES)_

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

Planned by `bash scripts/plan.sh write HARNESS-040` from `.claude/harness/models.conf`.
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

- PLANNED: `lead-po` dispatched as `/plan-story`, resolved to Fable 5.1
  (`claude-fable-5-1`), as planned; no override visible to the agent.
- Oracle partition for the RED brief: every criterion is mechanical (C-7);
  nothing is settled-by-measurement, nothing is oracle-free. Brief RED to pin
  C-3's two report lines and C-4's summary line byte for byte with whole-line
  `exact_count` needles, to build its own conf fixtures (the real
  `docs-shipped.conf` is GREEN's), to read the 24 of C-6 out as a floor rather
  than tune it, and to invent no metric. The `refresh` suite is 80 s: run it
  once per red run, not in a loop.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

Everything else in issue #104, each a later story of its own, plus the edges
this story draws and does not cross:

- **Section 2** - the `node-typescript` profile's mutation gate on TS 7 /
  Vitest 5: the `tsconfigFile` caveat, the command-runner setup, and an
  `evidence` line that requires a non-zero killed count.
  `.claude/skills/stack-profiles/reference/node-typescript.md` is not in
  `touches:`.
- **Combining two profiles' mutation gates** (`mutation` + `rust-mutation`, or
  whatever that story decides); a note in the profiles.
- **Printing profile lines added since the vendored release** (the issue's
  other "declarations" suggestion) - a refresh report for a human to merge,
  the way `paths.conf` and `CLAUDE.md` are treated. Symptom B itself is done
  (HARNESS-039, release 83).
- **Overwriting, updating or diffing an existing `docs/` file.** `KEPT` means
  byte-untouched, even when the project's copy is older than upstream's; a
  template that changes upstream is for a human to merge, and this story does
  not report that it differs. A later story may add a `differs from upstream`
  note beside `KEPT` if the field asks for it.
- **Reading the project's history to tell "deleted" from "never delivered".**
  A listed file the project deleted or renamed is ADDED again on the next
  refresh, once, and the project may delete it again or keep it; the refresh
  reports the ADDED line and reads no git history for `docs/`. Said here so
  the behaviour is a decision rather than a surprise.
- **A project-side extension of the list** (`project-docs-shipped.conf`, on
  the `project-floors.conf` pattern). A consumer's own command naming its own
  `docs/` path would trip the `shipped-docs` suite; no consumer on this
  machine (manga-translator, fantasy-world-builder) has a command or agent
  file upstream does not ship, so it is a later story if it happens.
- **Scanning `README.md`, `CLAUDE.md`, `docs/**` or `scripts/` for `docs/`
  references.** The rule reads what instructs an agent: commands, agents,
  skills.
- **Shipping `docs/wiki/README.md` and `docs/backlog/README.md`.** Not named
  by any command (C-1); one `ship` line each if a later story wants them.
- **`doctor.sh` reporting a missing shipped file.** The refresh adds it and
  the selftest guards the list; a doctor row is a separate decision.
- **Fixing any consumer's tree.** DV-4 reads a scratch copy of
  manga-translator and writes nothing there.
- **The sigpipe pins** (`sigpipe.test.sh:569-572`) - held, not moved (C-2, C-10).

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

## Notes

- PLANNED (2026-10-06, release 83 at `7bc2d59`): every line number in
  `## Context` and `## Contract` was re-read on this tree, not taken from the
  issue (which cited release 70): `refresh-harness.sh` header `:25-30`,
  summary `:427-428`, single-file list `:399-401`, LOCAL list `:307-308`,
  `say`/`act` at `:144-145`, the `scripts/*.sh` report at `:414`;
  `audit-mutations.md:32`; `mutation-tester.md:37`; `sigpipe.test.sh:569-572`;
  `refresh.test.sh` fixture `:26-59`, `new_project` `:61-88`, dry-run guard
  `:201-205`, `exact_count` `:896`, the identical-copies control `:754`;
  `floors.conf:55`;
  `selftest.test.sh:546`; `README.md:479`.
- Measured at PLANNED: `bash scripts/selftest.sh refresh` - 132 executed
  against a floor of 122, 80 s wall (`SELFTEST_JOBS=1`); `policy` - 12 s. The
  new `shipped-docs` suite is prose and fixtures and should sit near `policy`.
- Every consumer on this machine (manga-translator 82, fantasy-world-builder
  64, first-roblox 30, manhwa-cropper unstamped) already holds
  `docs/wiki/audits/TEMPLATE.md` - each added it by hand or was vendored after
  `2dc905d` - so no live tree reproduces Symptom A today; DV-4 deletes it from
  a scratch copy instead.
- The `touches:` list and the Contract's `**Writes:**` line are the same seven
  paths; `bash scripts/plan.sh conflicts` should print no DRIFT for this story.
