# Audit: narrowing the `.claude/state/` deny rules

**Date:** 2026-09-10
**Scope:** the `deny` block of `.claude/settings.json` at `7591188` (after
PR #10), and what it stops an agent doing to `.claude/state/`. Prompted by two
things the previous round could not finish: `.claude/state/README.md` could not
be updated to document `mutations/`, and a stray `.bak` left by an aborted probe
could not be deleted.
**Left out:** every other rule in the block. The three `Read(...)` denies on
`.env` and `secrets/**` were not touched and were not examined.

## Decided

- **The deny is per file, not a glob over the directory.** `current-story.env`
  and `last-gate-run` are denied for `Write` and `Edit`; nothing else under
  `.claude/state/` is. Those two are the only files in there whose *contents* are
  read as evidence, and they are the whole reason the rule existed.
- **The glob was wrong in two directions, not one.** It covered the two tracked
  documents (`README.md`, `.gitkeep`), which nothing reads at runtime - so the
  page describing the directory could not be edited by the tools it describes.
  And it covered tool exhaust, so a leftover `mutations/*.bak` could not be
  removed after being acted on, which is the one thing the harness explicitly
  tells you to do about one.
- **Per-file rules are less durable, so the durability is a test.** A state file
  added later would get no protection until somebody remembered a line, and that
  is a worse failure than the one being fixed. `.claude/state/README.md` now
  carries a `Hand-editable` column and `.claude/tests/settings.test.sh` checks it
  against `settings.json` in both directions. A `no` row without its rules fails,
  a `yes` row with rules fails, a rule for a path the table does not list fails,
  and a table with an unanswered cell fails.
- **The suite's checks are a function over a supplied (settings, README) pair**,
  not statements about the live files. That is not tidiness: a suite that asserts
  only against the real pair has every assertion pass on its first run and
  forever, whether or not it checks anything, and the usual way to earn those -
  mutate the thing under test - is unavailable here, because the runtime reads
  permissions and hooks live and a suite that edits them is changing the rules it
  runs under. So the real pair must produce no complaints, and each way of
  getting it wrong is a fixture that must produce a specific one.
- **The two protected files keep a second, independent assertion** naming them
  directly, so that widening the column and the rules together still fails.

## Evidence

- **A file-specific deny covers Bash, not just the Write and Edit tools.** This
  was the open question when the change was proposed, and the answer decides
  whether the narrowing gave anything up. Measured by probe against the live
  rules after they were applied: `printf '' >> .claude/state/last-gate-run` and
  `rm -f .claude/state/last-gate-run`, both by absolute path, were both refused.
  A `Write(<path>)` deny is therefore a deny on writing that path, however the
  write is spelled.
- **The enforcement is path-based and comes from these rules.** There is no
  `.claude/settings.local.json` and no user-level `~/.claude/settings.json` on
  this machine, so the project's block is the only source. Measured before the
  change: a Bash write and a Bash `rm` at the repository root both succeeded,
  while the same two under `.claude/state/` were refused - so the boundary was
  the path, and `settings.json` was the lever.
- **The narrowing did what it was for.** The two stray probe files from the
  previous round were deleted with a plain `rm` immediately after the change, and
  `.claude/state/README.md` was rewritten with the `Hand-editable` column and the
  `mutations/` rows. Both were refused before it.
- **Each of the suite's three checks was probed through `scripts/mutate.sh`**,
  one mutation per check, one run each, every restore `cmp`-verified:
  - neutering the unanswered-column check → `an unanswered column` fails, alone;
  - neutering the forwards check → `a no row with no rule`, `a dropped rule` and
    `and it says which files wanted it` fail, and nothing else;
  - neutering the backwards check → `a re-widened glob` fails, alone. That is the
    check that catches the glob returning, and no other check would notice it,
    because `**` satisfies no row rather than contradicting one.
  - The independent floor was earned by pointing `SETTINGS` at a file with no
    deny rules: all four of its assertions fail, plus `no disagreements`.
- **Full selftest:** 10 suites, 436 assertions, 0 failures. New this round:
  `settings` (14).

## What would have to be true for this to be wrong

- A deny rule's path glob is matched against the path a Bash command writes, and
  a rule naming a literal file therefore also covers `rm` of it. Probed above on
  this runtime; not guaranteed by anything in this repository, which is why the
  README says the supported writer is still `phase.sh` and `gates.sh`.
- `current-story.env` and `last-gate-run` are the only files under
  `.claude/state/` whose contents anything reads as evidence. If a hook later
  reads a third, the test catches the missing rule only once the README lists the
  file - the table is the source of truth, so a file nobody documents is a file
  nobody protects.
- The README's table stays a markdown table with the path first and
  `Hand-editable` last. The parser is positional (`$2` and `$(NF - 1)`); a column
  inserted after `Hand-editable` would silently read the wrong cell. The
  `yes|no` check limits the damage to a loud failure rather than a quiet pass.

## What was not checked

- **Whether `MultiEdit` and `NotebookEdit` are covered.** The rules name `Write`
  and `Edit` only, as the glob did before. Neither was probed, and a
  `MultiEdit(...)` deny was not added, so if `MultiEdit` is not implied by
  `Write` there is a gap - present before this change too, and unmeasured either
  way.
- **`.gitkeep`.** It is tracked, empty, and now editable. Nothing reads it; no
  row was added for it, so the table does not mention it and no rule names it.
  Consistent, but it means the table is not an inventory of the directory - only
  of the files a tool writes.
- **The three `Read(...)` denies.** Out of scope and untouched.
- **Any platform but this one.** The probes were run on Windows under Git Bash.

## Stories filed

None; the harness records its own rounds in this directory rather than in
`docs/backlog/`, which ships to consumers.
