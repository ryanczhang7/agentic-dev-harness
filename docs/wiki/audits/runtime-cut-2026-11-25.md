# Runtime and CI-cost cut, 2026-11-25

## Scope

The whole development loop as it actually ran, at main `d495ae7` (release
142), across the harness and every repository that consumes it:

- GitHub Actions spend and wall time, 2026-09-25 to 2026-11-25: 1,895 runs,
  every job and step, in ten repositories.
- The harness self-test (35 suites), `gates.sh`, `check-boundaries.sh`,
  `selftest-needed.sh` and `ci-local.sh`.
- The story cycle as executed: 1,256 subagent transcripts, every main session
  of the five harness projects, 958 attest records, and 82 stories that went
  RED to REVIEW since 2026-11-12.
- Per-call overhead: the four hooks and the static per-turn context
  (`CLAUDE.md` and `rules.md`).

The goal was at least 25% off development wall time and off Actions cost,
with no test, gate, check or security property weakened. Every candidate had
to be "same verdict, less work": a skipped run is skipped only where another
run proves the same tree, and a faster script must give byte-identical output.

Not audited: the product code of the consuming projects, apart from their CI
steps and `project.conf`.

Four `fable` analyses (resolved `claude-fable-5-2`) measured the four
slices. The orchestrator then re-checked the claims every decision depends
on (see the last list under Evidence).

## Decided

Proposed. None of these is settled until the user approves it, and each
lands as its own story, tests first, with the measured saving as an
acceptance criterion. The ids refer to the Evidence section.

**Harness CI**
1. Run the CI self-test four suites at a time (ST-1/CI-3), and start the
   longest suites first (ST-2).
2. Cancel a PR run that a newer push to the same PR has replaced (CI-6).

**Consumer CI (template, then a refresh)**
3. Skip the CI self-test when `selftest-needed.sh` says no harness path
   changed (CI-2). Scheduled and manual runs still run it in full.
4. Fantasy-world-builder: skip a push-to-main run only when the merge commit's
   tree is one a passing PR run has already recorded (CI-1). The upstream
   `gates.yml` header documents this pattern for projects that cannot require
   checks.
5. Fantasy-world-builder: cache the Playwright browser on Windows (CI-4).

**Local scripts**
6. Give the phase guard a fork-free fast path, plus lazy steps (HK-1 to
   HK-4). It must give the same verdict as today on every case in
   `phase-guard.test.sh`, plus a corpus of real commands.
7. Rewrite the story-file loop in `check-boundaries.sh` as one `awk` (ST-5);
   per-section reads follow as a later story (ST-6).
8. Move the floor table out of the `selftest` suite into its own small suite
   (ST-3). Declare `fixture-only` on the nine suites that mention `CLAUDE.md`
   only in comments or fixtures (ST-4).
9. In the run-queue suite: a 0.2 s poll, a builtin wait, and one `rm`/`mkdir`
   per case reset (ST-7).

**Story procedure**
10. Give `lead-po` and `lead-designer` an explicit `tools:` line (CY-5).
11. GREEN ends with one attested full `gates.sh`. It replaces both the
    standalone test command and `--fast`, which the full run already contains
    on the same tree. GATES re-runs it only when the record is not fresh
    (CY-2/CY-3).
12. The orchestrator runs single-command gate and self-test runs itself,
    attested and in the background, instead of dispatching an agent to do it
    (CY-6).
13. Start the `--changed` self-test first, and run the diff review while it
    runs (CY-7).
14. `/advance-story` injects only the current phase's procedure (CY-4).

**Needs the user's decision**
15. CY-1: `plan.sh` sends almost every story to `/advance-story`, one phase
    per go-ahead. The reason it gives, that the story carries a deferred
    verification, is true of nearly every story, and no check depends on
    stopping. Recommending `/complete-story` would remove about three go-ahead
    waits per story. The stop conditions in `complete-story.md` stay as they
    are.
16. CI-5: on fantasy-world-builder and manga-translator CI, the `unit` and
    `coverage` gates run the same tests, the second time with coverage on.
    Dropping `unit` there is the single biggest cut left in their CI. But a
    test that fails only without instrumentation, and only on CI, would go
    unseen. Not counted in the totals below.

**A defect, not a speed-up.** The weekly colour-forced self-test has failed
on every scheduled run since 2026-11-02 (runs 41462331904, 42639068050,
43886158056 and 45223333374). The failures are in the boundaries suite's
suppression cases. The same cases pass on the plain PR path. The cause is not
known. It gets its own story before anything touches the weekly run or
`ci-local.sh`'s second self-test (ST-9).

## Evidence

These numbers are measured, not settled. A story that depends on one
re-measures it first. Local timings were all taken on a host shared with
other projects' runs, where a spawn cost 22 ms idle and 160-250 ms loaded.
Process counts are deterministic, so read the local times as ratios.

**Actions spend, private repositories, per 30 days.** Billed minutes are each
job's time rounded up to the whole minute. "Weighted" counts Windows minutes
twice, the multiplier stated in fantasy-world-builder's own `gates.yml`. The
billing API was not readable with this token.

| Repo | Billed min | Weighted | Of which |
|---|---|---|---|
| fantasy-world-builder | 5,043 | ~9,765 | push-to-main runs 2,195 (44%) |
| trump-crime-family | ~600 | ~600 | self-test 62% of the gates job |
| total | ~5,640 | ~10,360 | |

**CI-1, push runs that re-test a proven tree.**
- Of 88 push runs, 84 were merge commits. In 79 of those, the first parent
  was already main's tip when the PR's last passing run started.
- That match is inferred from timestamps, not from tree hashes. The story
  compares tree hashes.
- 9 of those 79 push runs failed where the PR run had passed, on the same tree
  and with nobody re-running them. That is flakiness, cause not known. A
  weekly scheduled run keeps that sampling at about 2% of the cost.
- Re-checked: fantasy-world-builder's `gates.yml` has `push: branches: [main]`.

**CI-2, the consumer self-test.** PRs that changed no `harness` path:
fantasy-world-builder 67 of 84, trump-crime-family 23 of 30, clean_calendar
82 of 96. Cost of the step:

| Repo | Self-test step | Share of its job |
|---|---|---|
| fantasy-world-builder | 344 s | 92% of boundaries |
| trump-crime-family | 277 s | 62% of gates |
| clean_calendar | 250 s | 38% |

The caveat: CI then trusts the same `selftest-needed.sh` that the local run
trusts, so a wrong skip is caught only by the weekly full run.

**ST-1/ST-2, the harness CI self-test.**
- The step takes 438 s run serially, which is 98% of the job.
- run-queue is the longest suite at 96 s, then boundaries at 79 s and
  selftest at 51 s.
- A scheduling simulation gives 145 s at four suites at a time in glob order,
  and 110 s longest-first.
- Re-checked: no workflow sets `SELFTEST_JOBS`.
- The step's weekly mean has grown from 71 s (late September) to 382 s (the
  week of 2026-11-22).

**HK-1 to HK-4, the phase guard.**
- About 162 Bash calls and 27 Write/Edit calls per story; 72% of the Bash
  calls come from subagents.
- With a story active, every Bash call costs 16 process creations, even
  `git status`. A write-shaped call costs 54-88, and a Write costs 22.
- That is about 5,150 per story today. The prototypes bring it to about 1,200.
- The prototypes gave byte-identical verdicts and decline-log lines to
  today's guard on 31 payloads (20 denials, 11 allows).
- Of 120 real commands sampled from those the fast path would skip, the
  unmodified parser found no write candidate in any.
- Not yet run: the real `phase-guard`, `lib` and `spawns` suites against the
  prototypes. That is the story's acceptance test.
- Several write-shaped calls went past the hook's 15 s timeout under load.
  Whether Claude Code then lets the write through was not checked.

**ST-5, `check-boundaries.sh`.**
- `bash scripts/check-boundaries.sh HEAD~3` took 198.5 s here.
- Block 1 runs about 14 processes for each of the 123 story files.
- Re-checked: the loop at `check-boundaries.sh:146-160`.

**ST-3/ST-4, suite selection.**
- 28 of the last 30 merged PRs edited `selftest.test.sh`, because it holds
  the third copy of every floor, so they all selected the whole 51 s suite.
- 14 suites mention `CLAUDE.md`. Nine of them only in comments or fixture
  writes, which is 93 s of CI time.

**ST-7, the run-queue suite.** A profile of one local run (2,205 s):
- the poll loops took 1,441 s;
- `new_case` took 317 s, at about 20 `rm`/`mkdir` processes per call;
- the suite's poll interval is `POLL=1` (re-checked at
  `run-queue.test.sh:89`).

**CY-2/CY-3, duplicate local runs.**
- 86 trees had both a passing attested `--fast` and a full run on the same
  hash. The `--fast` minutes on them: manga-translator 554,
  fantasy-world-builder 147, clean_calendar 64.
- The attested test commands are byte-identical to each project's `unit`
  gate command.

**CY-5, tool lists.**
- Re-checked: `lead-po.md` and `lead-designer.md` have no `tools:` line.
- So each dispatch carries 43 tools, 31 of them MCP. Its first turn is 66.7 k
  tokens against 32 k for the developer agents.
- That is about 117 M excess tokens since 2026-11-12.

**CY-1, go-ahead waits.**
- 505 `/advance-story` invocations against 22 `/complete-story` since
  2026-11-01; about 4.2 go-aheads per story.
- The median wait before a go-ahead is 16 minutes, about 51 minutes per story
  counting only waits under an hour.
- Re-checked: `plan.sh:293-296` recommends `advance-story` whenever
  `## Deferred verifications` has content.

**Estimated totals.** Each is the sum of the finding estimates above, not yet
a measurement.

| Measure | Now | Cut |
|---|---|---|
| Private Actions spend, weighted | ~10,360 min / 30 days | ~43% (CI-1 3,650; CI-2 440; CI-4 252; rest ~85) |
| Harness PR CI wall | 7.5 min | ~65%, to ~2.5 min |
| trump-crime-family PR CI wall | 7.5 min | ~60% |
| clean_calendar PR CI wall | 11 min | ~38% |
| fantasy-world-builder PR CI wall | ~31 min | ~10% |
| Agent wall per harness story | ~150 min | ~30%: guard 3-14 min, boundaries ~6, self-test selection ~18, procedure ~12 |
| Agent wall per manga-translator story | ~300 min | ~24% from CY-2/CY-3 alone |
| Agent wall per story, other consumers | | 6-9% from procedure, plus the guard and boundaries cuts |
| Local wall per story, with CY-1 | ~192 min | ~29% from procedure alone |
| Tokens per story | ~26 M | ~11%, or 18-22% if each story starts in a fresh session |

## What would have to be true

- **CI-1.** A merge commit's tree equals the tree a passing PR run judged. It
  holds whenever the base had not moved, which the story checks by tree hash.
  The push run is also what seeds main's Rust cache, so a lockfile,
  toolchain or workflow change always gets the full run.
- **CI-2.** Without a harness path in the diff, the self-test cannot change
  its verdict. That holds if no suite reads project files outside `harness`
  paths, and only the two tree guards do, which stay on every PR.
- **ST-1.** The timing-sensitive suites tolerate four at a time on a 4-vCPU
  runner. They already pass that way locally under heavier load. The story
  makes a manual trial run first.
- **HK-1.** The fast path is a superset test: a write candidate can only come
  from text the raw JSON already contains. If that is wrong, the guard lets a
  write through. So the story runs every allow case both with and without the
  fast path, and puts back a removed keyword to watch a blocked case go red.
- **CY-2/CY-3.** A passing full `gates.sh` on a tree contains every verdict
  `--fast` and the test command would give on that tree, and `gates.sh`
  records normally while the phase is GREEN. The second point is unverified.

## What was not checked

- Billing at the real Windows multiplier; the API needs a scope this token
  lacks.
- The real hook test suites against the hook prototypes.
- Whether a hook timeout lets a write through.
- The CI speed-up of four suites at a time: simulated, not run.
- Whether a local self-test failure was ever one CI would have missed. 8 of
  44 attested local self-test runs failed, so the local run is kept.
- Session length as a cost lever. One session carried 19 stories, at about
  165 k tokens per main-session turn. This is a usage habit, and the harness
  can only prompt for it.
