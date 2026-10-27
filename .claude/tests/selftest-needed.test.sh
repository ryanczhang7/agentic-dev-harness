#!/usr/bin/env bash
# Tests for scripts/selftest-needed.sh (HARNESS-075): does this story's diff
# touch a path `classify.sh` calls `harness`? `run` (exit 0) when it does, or
# when the diff cannot be computed; `skip` (exit 1) when it does not.
#
# THE LINES ARE READ OUT, NOT DERIVED (story, Contract, "Output"). Every
# expected line below is written out whole, with the em dash, and compared
# WHOLE with assert_eq: `selftest-needed: run` is a prefix of the fail-toward-
# run lines too, so a floating `run` needle would be satisfied by the script
# failing to compute anything. The only value read from the fixture is the
# merge-base's short SHA, via `git rev-parse --short` on the ref the fixture
# itself arranged - never via the script's own enumeration.
#
# EVERY CASE IS RUN TWICE: from the fixture root and from its `src/`
# subdirectory, because the script must `cd` to the top level first (Contract,
# "Changed set"). A script that ran `git diff` relative to the cwd would list
# the same paths but `ls-files --others` would not, and a subdirectory run is
# what tells them apart.
#
# THE CONTROLS. The AC-2 skip and the AC-1 mixed diff differ by exactly one
# committed path, `scripts/z.sh`, so a run/skip decided by count (or by "any
# change at all") cannot pass both. The explicit-base and origin/main cases each
# carry a second reading against the other ref, which must give the OTHER
# answer - that is what makes "the ref was used" observable.
#
# THE RED SHAPE. scripts/selftest-needed.sh does not exist in RED, so every
# `bash <script>` exits 127 with empty stdout. One named assertion says so
# first; every case runs regardless, and every assertion is unconditional, so
# the executed count is the same in RED and GREEN.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t harness.XXXXXX)"
FIXES=()
cleanup() { local f; rm -rf "$WORK"; for f in "${FIXES[@]}"; do rm -rf "$f"; done; }
trap cleanup EXIT

# --- fixture helpers ----------------------------------------------------------

gitc() { git -C "$d" -c user.email=t@t -c user.name=t "$@"; }

# new_fixture   d := a fresh make_project_fixture, its one commit on `main`.
new_fixture() {
  d="$(make_project_fixture)"; FIXES+=("$d")
  gitc branch -M main >/dev/null 2>&1
}

# story_branch   Check out a story branch at the current HEAD.
story_branch() { gitc checkout -q -b story/T-1-fixture >/dev/null 2>&1; }

# put <rel> [content]   Write a file in the fixture, making its directory.
put() {
  mkdir -p "$(dirname "$d/$1")"
  printf '%s\n' "${2:-x}" > "$d/$1"
}

# commit_all <msg>
commit_all() { gitc add -A >/dev/null 2>&1; gitc commit -qm "$1" >/dev/null 2>&1; }

# short <ref>   The ref's short SHA, as `git rev-parse --short` prints it.
short() { gitc rev-parse --short "$1" 2>/dev/null; }

CEIL=""   # GIT_CEILING_DIRECTORIES for the run; empty = none

# run_sn <cwd> [args...]   Runs the fixture's copy of the script from <cwd>.
# RC := exit status, OL := stdout lines (CR stripped), FIRST := OL[0],
# NOUT := stdout line count, ERR := stderr.
run_sn() {
  local cwd="$1" i; shift
  ( cd "$cwd" && GIT_CEILING_DIRECTORIES="$CEIL" bash "$SN" "$@" ) >"$WORK/o" 2>"$WORK/e"
  RC=$?
  OL=(); mapfile -t OL < "$WORK/o"
  for i in "${!OL[@]}"; do OL[$i]="${OL[$i]%$'\r'}"; done
  NOUT="${#OL[@]}"; FIRST="${OL[0]-}"
  ERR=""; [ -s "$WORK/e" ] && ERR="$(cat "$WORK/e")"
}

# expect <label> <rc> <line> <quiet:yes|no> [args...]   Run from the fixture
# root and from src/, and assert each time: the exit status, the whole first
# line, exactly one stdout line, and - when <quiet> is yes, the run/skip paths -
# nothing on stderr (Contract, "Output").
expect() {
  local label="$1" rc="$2" line="$3" quiet="$4" where cwd
  shift 4
  for where in root subdir; do
    cwd="$d"; [ "$where" = subdir ] && cwd="$d/$SUBDIR"
    run_sn "$cwd" "$@"
    assert_eq "$label [from $where]: exits $rc" "$rc" "$RC"
    assert_eq "$label [from $where]: the first line is exactly the pinned line" "$line" "$FIRST"
    assert_eq "$label [from $where]: stdout is exactly one line" 1 "$NOUT"
    [ "$quiet" = yes ] && assert_eq "$label [from $where]: nothing on stderr" "" "$ERR"
  done
  return 0
}

SUBDIR=src
D='—'   # the em dash the Contract pins
CI_TAIL='; CI runs the self-test on the PR'

# ---------------------------------------------------------------------------
describe "the script exists"

assert_eq "scripts/selftest-needed.sh exists in this repository" \
  "" "$([ -f "$REPO_ROOT/scripts/selftest-needed.sh" ] || printf 'missing')"

# ---------------------------------------------------------------------------
describe "AC-1: a harness path among the story's changes answers run, exit 0"

new_fixture; SN="$d/scripts/selftest-needed.sh"; story_branch
put scripts/x.sh '#!/usr/bin/env bash'; commit_all "add x"
expect "a COMMITTED new scripts/x.sh answers run and names it" 0 \
  "selftest-needed: run $D 1 harness path(s) changed against main (merge-base $(short main)): scripts/x.sh" yes

new_fixture; SN="$d/scripts/selftest-needed.sh"; story_branch
put .claude/tests/project-x.test.sh 'true'; gitc add .claude/tests/project-x.test.sh >/dev/null 2>&1
expect "an UNCOMMITTED (staged) .claude/tests/project-x.test.sh answers run and names it" 0 \
  "selftest-needed: run $D 1 harness path(s) changed against main (merge-base $(short main)): .claude/tests/project-x.test.sh" yes

new_fixture; SN="$d/scripts/selftest-needed.sh"; story_branch
put .github/workflows/ci.yml 'on: push'
expect "an UNTRACKED .github/workflows/ci.yml answers run and names it" 0 \
  "selftest-needed: run $D 1 harness path(s) changed against main (merge-base $(short main)): .github/workflows/ci.yml" yes

new_fixture; SN="$d/scripts/selftest-needed.sh"
put CLAUDE.md '# rules'; commit_all "add CLAUDE.md"; story_branch
put CLAUDE.md '# rules, edited'
expect "an unstaged edit to CLAUDE.md answers run and names it" 0 \
  "selftest-needed: run $D 1 harness path(s) changed against main (merge-base $(short main)): CLAUDE.md" yes

new_fixture; SN="$d/scripts/selftest-needed.sh"
put scripts/y.sh '#!/usr/bin/env bash'; commit_all "add y"; story_branch
rm -f "$d/scripts/y.sh"
expect "a DELETED scripts/y.sh answers run and names it: classification is by path" 0 \
  "selftest-needed: run $D 1 harness path(s) changed against main (merge-base $(short main)): scripts/y.sh" yes

# The mixed diff, and AC-2's control: the AC-2 skip's six paths plus one
# committed harness path. An ignored untracked file sits beside them and is not
# a changed path (ls-files --exclude-standard).
mixed_paths() {
  put src/app.ts 'export const a = 1'
  put src/app.test.ts 'test("a", () => {})'
  put docs/wiki/x.md '# x'
  put package.json '{}'
  put .dockerignore '.claude'
  put vendor/lib.js 'module.exports = 1'
}
new_fixture; SN="$d/scripts/selftest-needed.sh"; story_branch
mixed_paths; put scripts/z.sh '#!/usr/bin/env bash'; commit_all "mixed"
put node_modules/pkg/index.js 'ignored'
expect "a mixed diff whose ONLY harness path is scripts/z.sh, beside source, test, docs, manifest, config and vendor paths, answers run (AC-2's control)" 0 \
  "selftest-needed: run $D 1 harness path(s) changed against main (merge-base $(short main)): scripts/z.sh" yes

new_fixture; SN="$d/scripts/selftest-needed.sh"; story_branch
put scripts/c.sh; put scripts/a.sh; put scripts/b.sh; commit_all "three"
expect "exactly three harness paths are all listed, in sort order, with no \`+N more\`" 0 \
  "selftest-needed: run $D 3 harness path(s) changed against main (merge-base $(short main)): scripts/a.sh, scripts/b.sh, scripts/c.sh" yes

new_fixture; SN="$d/scripts/selftest-needed.sh"; story_branch
put scripts/d.sh; put scripts/c.sh; put scripts/a.sh; put scripts/b.sh; commit_all "four"
expect "four harness paths list the first three in sort order, then \`, +1 more\`" 0 \
  "selftest-needed: run $D 4 harness path(s) changed against main (merge-base $(short main)): scripts/a.sh, scripts/b.sh, scripts/c.sh, +1 more" yes

# ---------------------------------------------------------------------------
describe "AC-2: no harness path among the changes answers skip, exit 1"

new_fixture; SN="$d/scripts/selftest-needed.sh"; story_branch
mixed_paths; commit_all "no harness"
put node_modules/pkg/index.js 'ignored'
expect "source, test, docs, manifest, config and vendor paths only (and an ignored untracked file) answer skip with the count and the base" 1 \
  "selftest-needed: skip $D no harness path among 6 changed path(s) against main (merge-base $(short main))$CI_TAIL" yes

new_fixture; SN="$d/scripts/selftest-needed.sh"; story_branch
expect "a branch with no changes at all answers skip with \`0 changed path(s)\`" 1 \
  "selftest-needed: skip $D no harness path among 0 changed path(s) against main (merge-base $(short main))$CI_TAIL" yes

# ---------------------------------------------------------------------------
describe "AC-3: when the diff cannot be computed, it answers run, exit 0"

new_fixture; SN="$d/scripts/selftest-needed.sh"
gitc branch -M trunk >/dev/null 2>&1; story_branch
put src/app.ts 'export const a = 1'; commit_all "source only"
expect "neither origin/main nor main resolves: run, saying so" 0 \
  "selftest-needed: run $D cannot compute the diff: no origin/main or main to compare against; defaulting to run" no

# An unrelated-history `main`: a root commit of the empty tree, made with
# plumbing so the story branch's checkout is never disturbed.
new_fixture; SN="$d/scripts/selftest-needed.sh"
gitc branch -M story/T-1-fixture >/dev/null 2>&1
put src/app.ts 'export const a = 1'; commit_all "source only"
empty_tree="$(gitc mktree </dev/null 2>/dev/null)"
unrelated="$(gitc commit-tree "$empty_tree" -m unrelated 2>/dev/null)"
gitc update-ref refs/heads/main "$unrelated" >/dev/null 2>&1
assert_eq "precondition: main exists and shares no history with the story branch" \
  "1:1" "$(gitc rev-parse --verify -q main >/dev/null 2>&1 && printf 1):$(gitc merge-base main HEAD >/dev/null 2>&1 || printf 1)"
expect "main resolves but \`git merge-base\` fails: run, naming the base" 0 \
  "selftest-needed: run $D cannot compute the diff: no merge base with main; defaulting to run" no

# Not a git checkout: the scripts, hooks and confs, with no .git anywhere up
# to the ceiling.
nd="$(mktemp -d 2>/dev/null || mktemp -d -t harness.XXXXXX)"; FIXES+=("$nd")
mkdir -p "$nd/.claude" "$nd/$SUBDIR"
cp -r "$REPO_ROOT/scripts" "$nd/scripts"
cp -r "$REPO_ROOT/.claude/hooks" "$nd/.claude/hooks"
cp -r "$REPO_ROOT/.claude/harness" "$nd/.claude/harness"
CEIL="$(dirname "$nd")"
assert_eq "precondition: the directory is not inside any git checkout" \
  "no" "$(cd "$nd" && GIT_CEILING_DIRECTORIES="$CEIL" git rev-parse --show-toplevel >/dev/null 2>&1 && printf yes || printf no)"
d="$nd"; SN="$d/scripts/selftest-needed.sh"
expect "outside any git checkout: run, saying so" 0 \
  "selftest-needed: run $D cannot compute the diff: not a git checkout; defaulting to run" no
CEIL=""

# ---------------------------------------------------------------------------
describe "AC-3: an explicit base ref is used in place of the resolution"

# main has moved past `release` with a harness commit; the story branch adds a
# source file. Against main: one changed path, no harness (skip). Against
# release: the harness commit too (run). The two refs give different answers.
new_fixture; SN="$d/scripts/selftest-needed.sh"
gitc branch release >/dev/null 2>&1
put scripts/x.sh '#!/usr/bin/env bash'; commit_all "harness on main"
story_branch; put src/app.ts 'export const a = 1'; commit_all "source"
expect "\`selftest-needed.sh release\` diffs against release and says \`against release\`" 0 \
  "selftest-needed: run $D 1 harness path(s) changed against release (merge-base $(short release)): scripts/x.sh" yes release
expect "control: the same fixture with no argument resolves main and gives the other answer" 1 \
  "selftest-needed: skip $D no harness path among 1 changed path(s) against main (merge-base $(short main))$CI_TAIL" yes

# ---------------------------------------------------------------------------
describe "AC-3: origin/main is preferred over main when both resolve"

# origin/main is a plain ref one commit behind main (no network). Against
# origin/main the harness commit on main is in the diff (run); against main it
# is not (skip).
new_fixture; SN="$d/scripts/selftest-needed.sh"
behind="$(gitc rev-parse HEAD 2>/dev/null)"
put scripts/x.sh '#!/usr/bin/env bash'; commit_all "harness on main"
gitc update-ref refs/remotes/origin/main "$behind" >/dev/null 2>&1
story_branch; put src/app.ts 'export const a = 1'; commit_all "source"
expect "with both refs present and no argument, origin/main is the base" 0 \
  "selftest-needed: run $D 1 harness path(s) changed against origin/main (merge-base $(short origin/main)): scripts/x.sh" yes
expect "control: \`selftest-needed.sh main\` on the same fixture gives the other answer" 1 \
  "selftest-needed: skip $D no harness path among 1 changed path(s) against main (merge-base $(short main))$CI_TAIL" yes main

# ---------------------------------------------------------------------------
describe "Contract: a second argument, or a \`-\`-prefixed one, is a usage error, exit 2"

new_fixture; SN="$d/scripts/selftest-needed.sh"; story_branch
run_sn "$d" main extra
assert_eq "two arguments exit 2" 2 "$RC"
assert_eq "two arguments print nothing on stdout" 0 "$NOUT"
assert_eq "two arguments say why on stderr" yes "$([ -n "$ERR" ] && printf yes || printf no)"
run_sn "$d" --help
assert_eq "a \`-\`-prefixed argument exits 2" 2 "$RC"
assert_eq "a \`-\`-prefixed argument prints nothing on stdout" 0 "$NOUT"
assert_eq "a \`-\`-prefixed argument says why on stderr" yes "$([ -n "$ERR" ] && printf yes || printf no)"

# ---------------------------------------------------------------------------
# HARNESS-075, Return 1 (GATES -> RED, from the diff review, findings 1-4).
# Four wrong-way skips the cases above could not see: the script called by a
# RELATIVE path, a rename, git itself failing, and a non-ASCII name. Every
# other case calls the script by absolute path, so these are the only ones
# that do not.

describe "AC-1 / Contract: called by a relative path from inside the checkout, it still answers run"

new_fixture; story_branch
put scripts/x.sh '#!/usr/bin/env bash'; commit_all "add x"
REL_LINE="selftest-needed: run $D 1 harness path(s) changed against main (merge-base $(short main)): scripts/x.sh"
for rel in "src|../scripts/selftest-needed.sh" "scripts|selftest-needed.sh"; do
  SN="${rel#*|}"; run_sn "$d/${rel%%|*}"
  assert_eq "\`bash $SN\` from ${rel%%|*}/ exits 0" 0 "$RC"
  assert_eq "\`bash $SN\` from ${rel%%|*}/: the first line is exactly the line the root call gives" "$REL_LINE" "$FIRST"
  assert_eq "\`bash $SN\` from ${rel%%|*}/: stdout is exactly one line" 1 "$NOUT"
  assert_eq "\`bash $SN\` from ${rel%%|*}/: nothing on stderr" "" "$ERR"
done

describe "AC-1: a renamed harness file counts under its OLD name too"

# tools/ is not a harness path (classify.sh calls tools/r.sh `source`), so the
# rename's destination alone answers skip; its source, scripts/r.sh, is the
# one harness path.
new_fixture; SN="$d/scripts/selftest-needed.sh"
put scripts/r.sh '#!/usr/bin/env bash'; commit_all "add r"; story_branch
mkdir -p "$d/tools"; gitc mv scripts/r.sh tools/r.sh >/dev/null 2>&1; commit_all "move r"
assert_eq "precondition: the rename's destination, tools/r.sh, is not a harness path in the fixture" \
  "source" "$(cd "$d" && bash scripts/classify.sh tools/r.sh 2>/dev/null | awk -F'\t' '{ print $1 }')"
expect "a committed \`git mv scripts/r.sh tools/r.sh\` answers run and names scripts/r.sh" 0 \
  "selftest-needed: run $D 1 harness path(s) changed against main (merge-base $(short main)): scripts/r.sh" yes

describe "AC-3 / PO decision 3: when git itself fails to list the changes, it answers run"

# A staged harness file, then an index git cannot read: `git diff` and
# `git ls-files` both fail, while rev-parse and merge-base still work. The
# reason text between the prefix and the suffix is the implementer's.
new_fixture; SN="$d/scripts/selftest-needed.sh"; story_branch
put scripts/new.sh '#!/usr/bin/env bash'; gitc add scripts/new.sh >/dev/null 2>&1
printf garbage > "$d/.git/index"
assert_eq "precondition: \`git diff\` fails on the corrupted index" \
  "fails" "$(gitc diff --name-only main >/dev/null 2>&1 && printf works || printf fails)"
GF_PRE="selftest-needed: run $D cannot compute the diff: "
GF_SUF="; defaulting to run"
for where in root subdir; do
  cwd="$d"; [ "$where" = subdir ] && cwd="$d/$SUBDIR"
  run_sn "$cwd"
  assert_eq "a corrupted index [from $where]: exits 0" 0 "$RC"
  assert_eq "a corrupted index [from $where]: the first line begins \`cannot compute the diff: \`" "$GF_PRE" "${FIRST:0:${#GF_PRE}}"
  assert_eq "a corrupted index [from $where]: the first line ends \`; defaulting to run\`" "$GF_SUF" \
    "$([ "${#FIRST}" -ge "${#GF_SUF}" ] && printf '%s' "${FIRST: -${#GF_SUF}}")"
  assert_eq "a corrupted index [from $where]: stdout is exactly one line" 1 "$NOUT"
done

describe "AC-1: a harness path with a non-ASCII name is seen, and named as the filesystem names it"

new_fixture; SN="$d/scripts/selftest-needed.sh"; story_branch
CAFE='.claude/tests/project-café.test.sh'
put "$CAFE" 'true'
assert_eq "precondition: the file exists under its UTF-8 name" "yes" "$([ -f "$d/$CAFE" ] && printf yes || printf no)"
expect "an UNTRACKED $CAFE answers run and names it unquoted" 0 \
  "selftest-needed: run $D 1 harness path(s) changed against main (merge-base $(short main)): $CAFE" yes

summary "selftest-needed"
