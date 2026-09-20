#!/usr/bin/env bash
# Tests for scripts/refresh-harness.sh - copying a newer harness into a project
# that is already using one.
#
# This exists because the procedure was prose, and prose was followed wrongly on
# its first real outing by the agent that wrote it. Three ways:
#
#   * it recommended `rsync`, which is not present in Git Bash - the shell this
#     harness runs in on Windows;
#   * a wholesale replace of `.claude/skills` deletes a project's OWN stack
#     profile, and the one in the way was 17 KB and cited by four documents;
#   * it omitted `.claude/settings.json` and `.claude/state/README.md`, which
#     are upstream-owned and read as evidence by `settings.test.sh`.
#
# Every one of those is a step somebody has to get right by reading carefully,
# which is the kind of requirement this repository does not otherwise accept
# anywhere. So the steps became a script, and the script reports what it did.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t harness.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# A stand-in upstream: the real script and hooks, plus marker files we can
# follow through the copy.
UP="$WORK/upstream"; PROJ="$WORK/project"
mkdir -p "$UP/.claude/harness" "$UP/.claude/skills/stack-profiles/reference" "$UP/.claude/hooks" \
         "$UP/.claude/agents" "$UP/.claude/tests" "$UP/.claude/state" "$UP/scripts" \
         "$UP/.claude/commands" "$UP/.github/workflows"
printf 'upstream hook\n'       > "$UP/.claude/hooks/phase-guard.sh"
cp "$REPO_ROOT/scripts/refresh-harness.sh" "$UP/scripts/" 2>/dev/null
printf 'upstream agent\n'      > "$UP/.claude/agents/lead-po.md"
printf 'upstream command\n'    > "$UP/.claude/commands/advance-story.md"
printf 'upstream profile\n'    > "$UP/.claude/skills/stack-profiles/reference/python-uv.md"
printf 'upstream suite\n'      > "$UP/.claude/tests/lib.test.sh"
printf '2026-09-17\n'          > "$UP/.claude/harness/VERSION"
printf 'upstream phases\n'     > "$UP/.claude/harness/phases.conf"
printf 'upstream rules\n'      > "$UP/.claude/harness/rules.md"
printf 'upstream settings\n'   > "$UP/.claude/settings.json"
printf 'upstream state doc\n'  > "$UP/.claude/state/README.md"
printf 'upstream paths\n'      > "$UP/.claude/harness/paths.conf"
printf 'upstream claude md\n'  > "$UP/CLAUDE.md"
printf 'echo new\n'            > "$UP/scripts/brand-new.sh"

# The upstream fixture is a REPOSITORY, not a directory of files, because the
# question "has upstream ever had this content?" is answered out of its object
# store. Two commits, so an older version of a file genuinely exists there.
( cd "$UP" && git init -q 2>/dev/null \
    && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm "upstream, one release ago" >/dev/null 2>&1 )
printf 'upstream agent, a release later\n' > "$UP/.claude/agents/lead-po.md"
( cd "$UP" && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm "upstream moves on" >/dev/null 2>&1 )

new_project() {
  rm -rf "$PROJ"; mkdir -p "$PROJ/.claude/harness" "$PROJ/.claude/skills/stack-profiles/reference" \
                           "$PROJ/.claude/agents" "$PROJ/.claude/state" "$PROJ/scripts/vitest" "$PROJ/docs/wiki" \
                           "$PROJ/.claude/commands" "$PROJ/.claude/hooks" "$PROJ/.claude/tests" "$PROJ/.github/workflows"
  printf 'OLD agent\n'          > "$PROJ/.claude/agents/lead-po.md"
  # One stale marker per replaced directory. Without these, the staleness grep
  # below has nothing to find in hooks/tests/commands and passes for the reason
  # that the directory was empty - which is what a vacuous assertion looks like.
  printf 'OLD command\n'        > "$PROJ/.claude/commands/advance-story.md"
  printf 'OLD HOOK\n'           > "$PROJ/.claude/hooks/phase-guard.sh"
  printf 'OLD suite\n'          > "$PROJ/.claude/tests/lib.test.sh"
  printf 'OLD profile\n'        > "$PROJ/.claude/skills/stack-profiles/reference/python-uv.md"
  # The project's OWN profile: upstream does not ship it and must not remove it.
  printf 'PROJECT profile\n'    > "$PROJ/.claude/skills/stack-profiles/reference/tauri-react-webgl.md"
  printf 'OLD settings\n'       > "$PROJ/.claude/settings.json"
  printf 'OLD state doc\n'      > "$PROJ/.claude/state/README.md"
  printf 'OLD paths\n'          > "$PROJ/.claude/harness/paths.conf"
  printf 'OLD claude md\n'      > "$PROJ/CLAUDE.md"
  # Project-owned, must survive untouched.
  printf 'BOOTSTRAPPED=yes\n'   > "$PROJ/.claude/harness/project.conf"
  printf 'project notes\n'      > "$PROJ/docs/wiki/stack.md"
  printf 'node_modules/\n'      > "$PROJ/.gitignore"
  printf 'project workflow\n'   > "$PROJ/.github/workflows/gates.yml"
  printf 'project bench\n'      > "$PROJ/scripts/bench.mjs"
  printf 'project helper\n'     > "$PROJ/scripts/vitest/setup.ts"
  ( cd "$PROJ" && git init -q 2>/dev/null && git add -A >/dev/null 2>&1 \
      && git -c user.email=t@t -c user.name=t commit -qm base >/dev/null 2>&1 )
}

refresh() { ( cd "$PROJ" && bash "$REPO_ROOT/scripts/refresh-harness.sh" "$@" 2>&1 ); }

# ---------------------------------------------------------------------------
describe "it refuses to run when running would be unsafe"

new_project
printf 'uncommitted\n' >> "$PROJ/docs/wiki/stack.md"
out="$(refresh "$UP")"; rc=$?
assert_eq "a dirty tree stops it" 2 "$rc"
assert_contains "and says why" "uncommitted" "$out"
( cd "$PROJ" && git checkout -q -- . )

# The procedure's own rule, enforced rather than requested: never mid-cycle,
# because the hooks being replaced are the ones enforcing the phase the story is
# standing in.
new_project
printf 'STORY_ID=W-1\nPHASE=GATES\n' > "$PROJ/.claude/state/current-story.env"
out="$(refresh "$UP")"; rc=$?
assert_eq "an active story stops it" 2 "$rc"
assert_contains "and names the phase" "GATES" "$out"
rm -f "$PROJ/.claude/state/current-story.env"

out="$(refresh /nowhere/at/all)"; rc=$?
assert_eq "a bad upstream path stops it" 2 "$rc"

# Both halves are required of an upstream checkout, and each was unasserted: a
# directory with `scripts` but no `.claude/hooks` is not a harness, and neither
# is the reverse. Copying from one would produce a project missing its lock.
mkdir -p "$WORK/half-a/scripts" "$WORK/half-b/.claude/hooks"
out="$(refresh "$WORK/half-a")"; rc=$?
assert_eq "an upstream with no .claude/hooks is refused" 2 "$rc"
out="$(refresh "$WORK/half-b")"; rc=$?
assert_eq "an upstream with no scripts is refused" 2 "$rc"

# THE false-positive case, and the one that matters most: a DONE story must NOT
# block a refresh. `phase.sh set <id> DONE` leaves PHASE=DONE in the state file
# and only `phase.sh clear` removes it, so DONE is the ordinary between-stories
# state - exactly the window the procedure tells you to refresh in. A refusal
# here would refuse the correct moment and teach people to delete the lock file.
new_project
printf 'STORY_ID=W-1\nPHASE=DONE\n' > "$PROJ/.claude/state/current-story.env"
out="$(refresh "$UP")"; rc=$?
assert_eq "a DONE story does not block a refresh" 0 "$rc"
rm -f "$PROJ/.claude/state/current-story.env"

# ---------------------------------------------------------------------------
describe "what it replaces, and what it refuses to touch"

new_project
out="$(refresh "$UP")"; rc=$?
assert_eq "it succeeds on a clean tree between stories" 0 "$rc"

assert_eq "an upstream-owned file is replaced" "upstream agent, a release later" "$(cat "$PROJ/.claude/agents/lead-po.md")"
assert_eq "so is a shipped profile"            "upstream profile" "$(cat "$PROJ/.claude/skills/stack-profiles/reference/python-uv.md")"
assert_eq "settings.json is copied"            "upstream settings" "$(cat "$PROJ/.claude/settings.json")"
assert_eq "and the state README"               "upstream state doc" "$(cat "$PROJ/.claude/state/README.md")"
assert_eq "a new upstream script arrives"      "echo new" "$(cat "$PROJ/scripts/brand-new.sh")"
assert_eq "a new suite arrives"                "upstream suite" "$(cat "$PROJ/.claude/tests/lib.test.sh")"

# THE case the prose got wrong. Upstream does not ship this file; a wholesale
# directory replace deletes it and says nothing.
assert_eq "the project's own profile survives" "PROJECT profile" \
  "$(cat "$PROJ/.claude/skills/stack-profiles/reference/tauri-react-webgl.md" 2>/dev/null)"
assert_contains "and the report says it was kept" "tauri-react-webgl.md" "$out"

# Project-owned, every one of them.
assert_eq "project.conf untouched"  "BOOTSTRAPPED=yes" "$(cat "$PROJ/.claude/harness/project.conf")"
assert_eq "docs untouched"          "project notes"    "$(cat "$PROJ/docs/wiki/stack.md")"
assert_eq ".gitignore untouched"    "node_modules/"    "$(cat "$PROJ/.gitignore")"
assert_eq "workflows untouched"     "project workflow" "$(cat "$PROJ/.github/workflows/gates.yml")"
assert_eq "a project script survives" "project bench"  "$(cat "$PROJ/scripts/bench.mjs")"
assert_eq "and a project script directory" "project helper" "$(cat "$PROJ/scripts/vitest/setup.ts")"

# EVERY directory the report calls REPLACED has actually been replaced, checked
# by content rather than by the report's own text. The report and the copy used
# to come from two separate loops over two separate lists, and nothing compared
# them: shortening the copy loop left all 28 assertions green while the report
# still printed `REPLACED .claude/hooks/` over a hook that still held OLD HOOK.
# A refresh that silently skips the phase lock and says it updated it is the
# worst thing this script can do, and the assertions above only happened to
# cover `agents`.
for d in agents commands skills hooks tests; do
  case "$out" in
    *"REPLACED  .claude/$d/"*) ;;
    *) _bad "report names .claude/$d" "not in the report"; continue ;;
  esac
  stale="$(grep -rl 'OLD ' "$PROJ/.claude/$d" 2>/dev/null | head -1)"
  if [ -n "$stale" ]; then
    _bad "REPLACED .claude/$d is true" "reported replaced, but $stale still holds the project's old content"
  else
    _ok "REPLACED .claude/$d is true"
  fi
done

# The two that need a human. Copying them blind loses project rules; the script
# leaves them alone and says so rather than pretending it merged them.
assert_eq "paths.conf is NOT overwritten" "OLD paths" "$(cat "$PROJ/.claude/harness/paths.conf")"
assert_eq "CLAUDE.md is NOT overwritten"  "OLD claude md" "$(cat "$PROJ/CLAUDE.md")"
assert_contains "and both are named for review" "paths.conf" "$out"
assert_contains "CLAUDE.md too"                 "CLAUDE.md"  "$out"

# ---------------------------------------------------------------------------
describe "it reports before it acts"

new_project
# Every file the script can write, fingerprinted before and after. The old
# assertion checked one file - `.claude/agents/lead-po.md` - which is protected
# by a DIFFERENT guard (`if [ "$DRY" = 0 ]` around the copy block), so making
# `act()` eval unconditionally left every assertion green while a dry run
# overwrote settings.json, state/README.md, three harness files and every
# scripts/*.sh.
before="$(find "$PROJ/.claude" "$PROJ/scripts" "$PROJ/CLAUDE.md" -type f -exec cksum {} \; 2>/dev/null | sort)"
out="$(refresh --dry-run "$UP")"; rc=$?
after="$(find "$PROJ/.claude" "$PROJ/scripts" "$PROJ/CLAUDE.md" -type f -exec cksum {} \; 2>/dev/null | sort)"
assert_eq "--dry-run succeeds" 0 "$rc"
assert_eq "and writes nothing at all" "$before" "$after"
assert_eq "and changes nothing" "OLD agent" "$(cat "$PROJ/.claude/agents/lead-po.md")"

# A dry run is a report, so it must work on the trees a report is most wanted
# on - including a dirty one, where the real run correctly refuses.
printf 'uncommitted\n' >> "$PROJ/docs/wiki/stack.md"
out="$(refresh --dry-run "$UP")"; rc=$?
assert_eq "--dry-run works on a dirty tree" 0 "$rc"
( cd "$PROJ" && git checkout -q -- . 2>/dev/null )
assert_contains "while still naming what it would keep" "tauri-react-webgl.md" "$out"
assert_contains "and the version it would move to" "2026-09-17" "$out"

# ---------------------------------------------------------------------------
describe "it names the files of yours it is about to overwrite"

# H26, from the field. A project vendors the harness, fixes a harness defect
# locally WITH TESTS, and the next refresh removes the fix and the assertions
# that pin it in one operation - because both live inside the replaced set. The
# selftest is green afterwards, since the tests that would have failed went with
# the code. Nothing reports anything.
#
# The report asks for one `cmp` per replaced file. That does not survive contact
# with a real refresh: going 13 -> 28 here, nearly every harness file differs
# because UPSTREAM moved on, and a list of dozens means nothing. The useful
# question is not "does this differ" but "did YOU change it", and those need a
# third reference point.
#
# Upstream is a git checkout, so there is one: hash the downstream copy and ask
# whether that blob has ever existed in upstream's object store. Present means
# the project is simply BEHIND - the ordinary case, and silent. Absent means the
# content was never upstream's, so somebody here wrote it.
new_project
# Behind: the project holds the previous release's version of an upstream file.
printf 'upstream agent\n'    > "$PROJ/.claude/agents/lead-po.md"
# Changed: content upstream has never shipped, in a file upstream owns.
printf 'upstream hook\n# a local fix this project made\n' > "$PROJ/.claude/hooks/phase-guard.sh"
( cd "$PROJ" && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm "a local harness fix" >/dev/null 2>&1 )

out="$(refresh --dry-run "$UP")"
locals="$(printf '%s\n' "$out" | grep 'LOCAL' || true)"
assert_contains "a file you changed is named before it is replaced" "phase-guard.sh" "$locals"
# THE OTHER HALF, and the one that makes it a signal rather than a wall of text.
# A warning that always prints is not a warning.
case "$locals" in
  *lead-po.md*) _bad "while merely being behind is silent" "being behind was reported: $locals" ;;
  *) _ok "while merely being behind is silent" ;;
esac

# Said in the DRY RUN, because the whole value is seeing it before the files go.
case "$out" in
  *"Dry run: nothing was written"*) _ok "and said before anything is written" ;;
  *) _bad "and said before anything is written" "not a dry run: $out" ;;
esac

# Nothing local at all: completely quiet. Without this a check that prints the
# same line for every replaced file passes the assertions above.
new_project
for f in .claude/agents/lead-po.md .claude/commands/advance-story.md \
         .claude/hooks/phase-guard.sh .claude/tests/lib.test.sh \
         .claude/skills/stack-profiles/reference/python-uv.md \
         .claude/settings.json .claude/state/README.md \
         .claude/harness/phases.conf .claude/harness/rules.md; do
  mkdir -p "$PROJ/$(dirname "$f")"; cp "$UP/$f" "$PROJ/$f"
done
( cd "$PROJ" && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm "exactly what upstream ships" >/dev/null 2>&1 )
out="$(refresh --dry-run "$UP")"
assert_eq "a project holding upstream's own files is told nothing" "" \
  "$(printf '%s\n' "$out" | grep 'LOCAL' || true)"

# An upstream that is not a repository cannot answer the question, and a check
# that cannot run must not read as a clean result.
out="$(refresh --dry-run "$WORK/half-b-full")" 2>/dev/null
mkdir -p "$WORK/half-b-full/.claude/hooks" "$WORK/half-b-full/scripts"
printf 'x\n' > "$WORK/half-b-full/.claude/hooks/phase-guard.sh"
out="$(refresh --dry-run "$WORK/half-b-full")"
assert_contains "an upstream with no history says it could not check" "could not check" "$out"


# ---------------------------------------------------------------------------
describe "LOCAL covers scripts/, where the production code lives"

# The blind spot, reported by a consuming project mid-refresh. The LOCAL loop
# walked .claude/{agents,commands,skills,hooks,tests} and five named
# .claude/harness files. `scripts/*.sh` was blanket REPLACED with no check at
# all - so a project that fixed a harness DEFECT in scripts/ had the fix
# overwritten without ever being named, while the alarm cheerfully named the
# test file beside it.
#
# That is the H26 case with the halves swapped: the test was reported and the
# CODE was not. WORLD-090's production fix to check-sigpipe.sh was in exactly
# that position when they noticed.
new_project
printf 'upstream sigpipe\n# a local fix to the GUARD, not to its test\n' \
  > "$PROJ/scripts/check-sigpipe.sh"
printf 'upstream sigpipe\n' > "$UP/scripts/check-sigpipe.sh"
( cd "$UP" && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm "upstream ships the guard" >/dev/null 2>&1 )
( cd "$PROJ" && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm "a local fix in scripts" >/dev/null 2>&1 )

out="$(refresh --dry-run "$UP")"
assert_contains "a local fix under scripts/ is named before it is replaced" \
  "scripts/check-sigpipe.sh" "$(printf '%s\n' "$out" | grep 'LOCAL' || true)"

# The quiet half, same rule as above: a scripts/ file that merely matches
# upstream must stay silent, or the check is a wall of text rather than a
# warning.
printf 'upstream sigpipe\n' > "$PROJ/scripts/check-sigpipe.sh"
( cd "$PROJ" && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm "match upstream" >/dev/null 2>&1 )
out="$(refresh --dry-run "$UP")"
case "$(printf '%s\n' "$out" | grep 'LOCAL' || true)" in
  *check-sigpipe*) _bad "while a scripts/ file matching upstream is silent" \
                        "reported anyway: $out" ;;
  *) _ok "while a scripts/ file matching upstream is silent" ;;
esac

# ---------------------------------------------------------------------------
describe "LOCAL refuses to answer from a source with no usable history"

# The check asks whether upstream's OBJECT STORE holds a blob matching ours. It
# therefore needs upstream's HISTORY, not merely its current tree. Against a
# source built by `git archive` + `git init` - one commit, no past - every file
# of ours that upstream shipped in an EARLIER release matches nothing, and the
# report becomes confident nonsense.
#
# Measured upstream: five files reported LOCAL where the truth was one.
#
# The existing `else` branch already refuses to read "not a git checkout at all"
# as a clean result. A one-commit checkout passes `rev-parse --git-dir` and so
# sails past it, which is the worse failure of the two: it answers.
SHALLOW="$WORK/shallow-upstream"
rm -rf "$SHALLOW"; mkdir -p "$SHALLOW"
( cd "$UP" && git archive HEAD ) | ( cd "$SHALLOW" && tar -x )
( cd "$SHALLOW" && git init -q . && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm "one commit, no past" >/dev/null 2>&1 )

new_project
out="$(refresh --dry-run "$SHALLOW")"
assert_contains "a source with a single commit says it could not check" \
  "could not check" "$out"

# And the control: the ordinary two-commit fixture still answers, so the guard
# above cannot be satisfied by refusing to check everywhere.
out="$(refresh --dry-run "$UP")"
case "$out" in
  *"could not check"*) _bad "while a source with real history still answers" \
                            "refused to check against a normal upstream: $out" ;;
  *) _ok "while a source with real history still answers" ;;
esac

# ---------------------------------------------------------------------------
describe "the source ref is named when it is not a release"

# The error this prevents, and it happened: this repository's clone was left
# checked out on a FEATURE BRANCH whose VERSION said 38. A consuming project
# read that, concluded release 38 had shipped, refreshed to it, and stamped a
# version no upstream release carries - which is precisely the confusion the
# VERSION file exists to end.
#
# It had examined the ref thoroughly - diffed it, confirmed comment-only, re-ran
# its apply checks - and never asked its STATUS. A ref can be fully examined and
# still not be a release, so the refresh says so rather than leaving it to the
# reader to think of the question.
( cd "$UP" && git checkout -q -b some-feature 2>/dev/null
  printf '99\n' > "$UP/.claude/harness/VERSION"
  git add -A >/dev/null 2>&1
  git -c user.email=t@t -c user.name=t commit -qm "unreleased work" >/dev/null 2>&1 )

new_project
out="$(refresh --dry-run "$UP")"
assert_contains "an unmerged source branch is named as unreleased" "not a release" "$out"
assert_contains "and the branch is named, so it can be checked" "some-feature" "$out"

# The control that stops this becoming a permanent banner: back on the default
# branch it says nothing of the kind.
( cd "$UP" && git checkout -q - 2>/dev/null )
out="$(refresh --dry-run "$UP")"
case "$out" in
  *"not a release"*) _bad "while a source on its default branch is silent" \
                          "warned anyway: $out" ;;
  *) _ok "while a source on its default branch is silent" ;;
esac
# ---------------------------------------------------------------------------
describe "the procedure belongs to the release being installed"

# A refresh is normally driven by the project's OWN copy of this script, and
# that copy is one release behind BY CONSTRUCTION: a change to *what* gets
# copied only takes effect on the refresh AFTER the one that delivers it.
#
# Not hypothetical. `models.conf` joined the single-file list in release 23, so
# a project on 22 running its own script received `scripts/plan.sh` without the
# policy file plan.sh reads - a script delivered without the thing it depends
# on, and nothing said a word. Every future addition to that list has the same
# one-release delay, and "remember to run upstream's copy" is not a mechanism.
new_project
# A project copy that differs from upstream's, which is what being a release
# behind looks like from here.
{ printf '#!/usr/bin/env bash\n# An older release of this script.\n'
  tail -n +2 "$REPO_ROOT/scripts/refresh-harness.sh"; } > "$PROJ/scripts/refresh-harness.sh"
( cd "$PROJ" && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm "the harness it already has" >/dev/null 2>&1 )
out="$( cd "$PROJ" && bash scripts/refresh-harness.sh "$UP" 2>&1 )"; rc=$?
assert_eq "an older project copy hands over to upstream's" 0 "$rc"
assert_contains "and says that it did" "upstream ships a different" "$out"
# It has to actually finish the work, not merely announce the handover - and
# exactly once, because a handover that re-entered the script would double it.
assert_eq "and does the refresh once" 1 \
  "$(printf '%s\n' "$out" | grep -c 'REPLACED  .claude/settings.json')"
assert_eq "having replaced the scripts" "echo new" "$(cat "$PROJ/scripts/brand-new.sh" 2>/dev/null)"

# THE CONTROL, and the thing that stops this becoming an infinite hand-over:
# when the two copies agree there is nothing to hand over to, and upstream's own
# script - which is what runs after a hand-over - must take this branch.
new_project
cp "$REPO_ROOT/scripts/refresh-harness.sh" "$PROJ/scripts/refresh-harness.sh"
( cd "$PROJ" && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm same >/dev/null 2>&1 )
out="$( cd "$PROJ" && bash scripts/refresh-harness.sh "$UP" 2>&1 )"; rc=$?
assert_eq "an identical copy just runs" 0 "$rc"
case "$out" in
  *"upstream ships a different"*) _bad "and hands over to nobody" "it handed over anyway: $out" ;;
  *) _ok "and hands over to nobody" ;;
esac

# The hand-over happens BEFORE the dirty-tree and mid-cycle refusals, so the
# process that refuses is the one handed TO rather than the one invoked. Same
# answer, different process - and worth its own case, because "it refuses" and
# "it still refuses after handing over" are different claims and every existing
# refusal test runs on a project whose script matches upstream's, so none of
# them reaches this path.
new_project
{ printf '#!/usr/bin/env bash\n# An older release of this script.\n'
  tail -n +2 "$REPO_ROOT/scripts/refresh-harness.sh"; } > "$PROJ/scripts/refresh-harness.sh"
( cd "$PROJ" && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm "an older harness" >/dev/null 2>&1 )
printf 'STORY_ID=W-1\nPHASE=GATES\n' > "$PROJ/.claude/state/current-story.env"
out="$( cd "$PROJ" && bash scripts/refresh-harness.sh "$UP" 2>&1 )"; rc=$?
assert_eq "a mid-cycle tree is refused THROUGH the hand-over" 2 "$rc"
assert_contains "and the refusal still names the phase" "GATES" "$out"
rm -f "$PROJ/.claude/state/current-story.env"

# ---------------------------------------------------------------------------
describe "it survives replacing the file it is being read from"

# Every case above runs $REPO_ROOT's copy of the script against a project that
# happens to hold another copy - two different files - so the suite never once
# exercised the arrangement EVERY real refresh uses. The header says to run it
# as `bash scripts/refresh-harness.sh` from inside the project, and
# `scripts/*.sh` is one of the things it replaces. The file being read is the
# file being written.
#
# Bash reads a script by byte offset as it executes. Overwrite it underneath and
# execution resumes at the old offset in the NEW bytes - mid-line, mid-block,
# with whatever that parses as. The first real refresh to hit this printed
#   refresh-harness.sh: line 151: ------------: command not found
# and ran its single-file block twice. The tree came out correct ONLY because
# the re-entered block was idempotent `cp` calls; a few hundred bytes either way
# is the `rm -rf` loop re-entered with different state, in the one script whose
# whole job is not silently destroying a project's files.
#
# The project's copy is padded so its byte offsets differ from upstream's, which
# is the real situation - an older release is always a different length - and
# without which overwriting a file with its own bytes changes nothing and the
# bug does not reproduce.
new_project
{ printf '#!/usr/bin/env bash\n'
  printf '# An older release of this script. The padding is the point: it puts\n'
  printf '# every byte offset in this file somewhere else than the new one has\n'
  printf '# them, which is what an older release does for free.\n'
  printf '#\n%s' "$(for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
      printf '# offset padding line %s, carrying no meaning whatsoever\n' "$i"; done)"
  tail -n +2 "$REPO_ROOT/scripts/refresh-harness.sh"
} > "$PROJ/scripts/refresh-harness.sh"
( cd "$PROJ" && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@t -c user.name=t commit -qm "the harness it already has" >/dev/null 2>&1 )

out="$( cd "$PROJ" && bash scripts/refresh-harness.sh "$UP" 2>&1 )"; rc=$?
assert_eq "run the documented way, it still exits 0" 0 "$rc"
case "$out" in
  *"command not found"*|*"syntax error"*|*"unexpected"*)
    _bad "and bash never resumes inside the new bytes" "it did: $out" ;;
  *) _ok "and bash never resumes inside the new bytes" ;;
esac
# Once each. Re-entering the file mid-block printed the single-file section a
# second time, which is the only reason anybody noticed.
assert_eq "and reports each replacement once" 1 \
  "$(printf '%s\n' "$out" | grep -c 'REPLACED  .claude/settings.json')"
# And it still did the work: the point of the fix is that the copy loop runs to
# completion, not that the script exits quietly before reaching it.
assert_eq "having actually replaced the scripts" "echo new" \
  "$(cat "$PROJ/scripts/brand-new.sh" 2>/dev/null)"
assert_eq "and itself, with the new release" \
  "$(cat "$REPO_ROOT/scripts/refresh-harness.sh")" \
  "$(cat "$PROJ/scripts/refresh-harness.sh" 2>/dev/null)"

summary "refresh"
