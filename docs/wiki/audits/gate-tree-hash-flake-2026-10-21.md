# gate_tree_hash flake in manga-translator: already fixed by HARNESS-042, plus a WSL-only residual

## Scope

Field report from manga-translator. Its vendored harness is **release 82
(2026-10-06)**, at manga-translator `484df9c`. This repository was at release 95
(`8ac522d`) when the report was written.

The report is about CI run 39544593119 on manga-translator PR #101, attempt 1, at
commit `f4bb1fc`. The `boundaries` job ran the `lib` suite on Linux and logged:

```
FAIL an untracked hook does not move the hash
     expected: b4b12873aca63eb38aeada58a955534aef924464
     actual:   29ce0ee3f2cc6ce8c5b0f6bbb85b6e6b16b6175d
lib: 245 passed, 1 failed
```

Attempt 2 on the same commit passed, and the PR touched no harness file. The
investigation was read-only. Nothing was patched in either repository. The
experiments ran in a throwaway clone under WSL2 (`~/gth`).

## Decided

1. **The CI flake is the defect HARNESS-042 fixed in release 86.** The vendored
   `gate_tree_hash` in release 82 seeds its temporary index with a plain
   `cp "$real" "$idx"`. Upstream now uses `cp -p`. No new upstream change is
   needed for the CI failure. **manga-translator should refresh to release 86 or
   later.** Following its standing rule, it reports its LOCAL harness changes
   upstream first.
2. **A residual failure remains with `cp -p` (about 1 run in 500), and it comes
   from WSL2's clock, not from the harness.** The WSL2 wall clock steps backwards
   by about 0.6 s every ~31.6 s. Git's racy-entry check assumes timestamps never
   go backwards, so after a step even plain `git add -A` misses a same-size edit.
   `gate_tree_hash` then still agrees with what `git commit -a` would produce,
   which is its stated contract, so the gate stamp stays consistent with CI's
   recompute from the commit. **This is not a production defect.**
3. **Optional: a low-priority story to make the self-test immune to the
   residual.** It would affect developers who run the self-test under WSL2. The
   block `gate_tree_hash: covers what the gates judge, and only that` exists to
   check *which kinds of file* move the hash, but its rewrites keep the file
   size the same (`x() { :; }` → `y() { :; }`, `= 1` → `= 2`). That makes the
   block depend on git's racy-entry handling. HARNESS-042's own block pins that
   handling deliberately, with the timing forced. Rewrites that change the size
   (for example `y() { : ; }` and `= 22`) would take git's stat shortcut out of
   this block. Only file content would then decide it, and HARNESS-042's
   assertion would still guard the `cp -p`. That is not filed as a story here
   (see "Stories filed").

## Evidence

**E-1. Repro rate, release 82 (plain `cp`), Linux.** WSL2 Ubuntu 24.04,
kernel 6.18.54.1-microsoft-standard-WSL2, git 2.43.0, ext4 `/tmp`. The suite
`bash .claude/tests/lib.test.sh` takes about 2.2 s per run, so the whole
fixture's life fits in one or two clock seconds. Result: **13 of 200 runs
failed (6.5%)**. Two assertions fail, in two ways:

- `an untracked hook does not move the hash`, 9 times. The actual hash was
  `29ce0ee…` 8 times, **the same value as the CI log**, and `1c22a59…` once.
- `a hook moves the hash`, 4 times (`unchanged: 29ce0ee…`).

**E-2. What the hashes mean.** Each hash depends only on file content, so the
values can be printed from a copy of the suite (`hashes.sh`):

| Hash | `.claude/hooks/lib.sh` | `src/main.ts` |
|---|---|---|
| `29ce0ee…` = h0 | `x() { :; }` (old) | `= 1` (old) |
| `00d0adbd…` = h1 | `y() { :; }` | `= 1` (old) |
| `b4b128…` = h2 | `y() { :; }` | `= 2` |

So the failing third call on CI read **both** rewritten files as their old
contents, with no file touched between `h2` and that call.

**E-3. The mechanism, forced deterministically** (`probe.sh`). The probe aligns
to the start of a second. In that second it writes and commits the fixture,
then rewrites `src/main.ts` with the same size. It hashes once in the same
second, waits for the clock to tick, and hashes again:

```
real index entry:  mtime 1792560951:13957165  size 19  ino 50499
file after rewrite: mtime=1792560951.056407750 size=19 ino=50499
hash A=a08eb50…  temp index main.ts: b78491c… (x = 2, correct)
--- second S+1 (no file touched since)
hash B=b24dd21…  temp index main.ts: 09b76aa… (x = 1, STALE)
git status --porcelain:  M src/main.ts      <- real git sees the edit
```

The copy made with plain `cp` is stamped with the current time. One second
later the index entry is older than the copy's own mtime, so `add -u` stops
treating it as racy. It then trusts the stat data, which matches to the second
(this git compares whole seconds only), and keeps the stale blob. With `cp -p`
(`probe-p.sh`), hash B equals hash A and the temporary index holds `b78491c…`.
This is the analysis in HARNESS-042, and E-3 confirms it independently on Linux.

**E-4. Repro rate with `cp -p` (release 86's fix applied to the scratch clone
only).** Total: **1 of 500 runs failed** across three loops. The rate is
measured, but it depends on the machine (see "What was not checked").

- First loop, uninstrumented: 1 of 200 failed. Both failing assertions were
  new: `source moves the hash` (`unchanged: 00d0adbd…`) and
  `AC-1: an untracked gated file does not move the stamp off HEAD's` (expected
  `00d0adbd…`).
- Second loop, with every hash call logged: 0 of 300 failed. The logging slows
  each call, so this count says little.
- Third loop (`loop3.sh`), dumping state only when the residual assertion
  failed: 1 of 500.

**The run caught by the third loop:**

```
DUMP at 1792562844.004446365                      <- wall clock when the dump ran
src/main.ts mtime=1792562843.973374837 size=19 ino=46424   (rewritten, x = 2)
.git/index  mtime=1792562844.431342605            <- written by the PRECEDING commit
index entry src/main.ts: mtime 1792562843:839949704 size 19 ino 46424
HEAD:main.ts = x = 1   work = x = 2
```

The index was written *before* the rewrite, yet its mtime is 0.43 s *later*
than a wall-clock reading taken *after* the rewrite. The fs timestamps
therefore went backwards between the commit and the rewrite. As a result, the
rewrite landed in second 843, the same second as the original write. That
matches the index entry, which is older than the index (844), so it is not
racy. Git took the stat shortcut. In the first loop's failure, `fix_commit`
(`git add -A` + commit) also committed the *old* `main.ts`, which is why the
`AC-1` expected value is `00d0adbd…`: real git missed the edit too.

**E-5. The WSL2 clock steps backwards** (`step.sh`, reading `date +%s%N` in a
loop for 540 s): **17 backward steps of 563 to 624 ms, one every ~31.6 s.** A
control showed no anomaly while the clock was not stepping: 2000 writes, each
file and index mtime inside its wall-clock window (`clock.sh`). Plain git under
the same sequence, without a step in the window, missed nothing in 400 trials
(`gitrace.sh`).

**E-6. Windows.** One run of the suite under Git Bash (git 2.55.0.windows.5)
passed, and took 9 min 37 s. Looping it 50 times was not practical. At that
speed the fixture's writes and rewrites are seconds apart, so the same-second
window is unlikely to arise there.

All scripts and the raw output of the third loop are in the manga-translator
session-notes folder `gate-tree-hash-flake/`. They are throwaway, not reviewed.

## What would have to be true for this to be wrong

- CI's failure has the same cause as the WSL failures in E-1. The supporting
  evidence: the identical `actual` hash (`29ce0ee…`) and the same
  release-82 code. It was not reproduced on a GitHub runner.
- The git on the runner compares mtimes in whole seconds, as the WSL git 2.43
  does: the stat of the stale entry differs in nanoseconds yet matched. A git
  built with `USE_NSEC` would narrow the window but not close it.
- The residual in E-4 needs a backward clock step. GitHub's Azure runners use
  chrony, which normally slews rather than steps. So the residual is expected
  to be rare or absent on CI, but that was not measured.

## What was not checked

- No loop ran on a GitHub-hosted runner. The CI rate is inferred from one
  failure in 16 recorded runs of that job.
- The plain-`cp` loop did not run on macOS or BSD.
- Windows ran once, not 50 times.
- Whether any *other* suite uses same-size rewrites close to a commit and so is
  exposed to the WSL residual. Only `lib` was looped.
- Release 95's suite was not looped. The `cp -p` runs used release 82's suite
  with only the one-line `cp -p` change applied.

## Stories filed

None. Recommendation 1 is a refresh in manga-translator, not a change here.
Recommendation 3 is optional and is left for the Lead PO to cut. A suggested
title: *The class-discrimination block in lib.test.sh changes file sizes, so
git's stat shortcut cannot decide it.*
