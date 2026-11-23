#!/usr/bin/env bash
# HARNESS-066 - scripts/tidy.sh: finished worktrees and merged branches.
#
# THE CLAIM THIS SUITE PINS
#
# A worktree is reported REMOVABLE only when its HEAD is in the base, its status
# is clean, it is not locked and nothing in it was touched within --idle-hours;
# otherwise KEEP with the FIRST failing reason. A local story/* or harness/*
# branch is DELETABLE only when it is merged, checked out nowhere and has no
# remote-tracking ref. Report mode changes nothing; --apply removes exactly what
# the report named and nothing reported KEEP; a removal git refuses is LEFT on
# disk with the command to finish it. Orphan folders under .claude/worktrees/
# are reported and never removed. Every criterion is mechanical (Contract C-11),
# so every needle below is a WHOLE LINE, compared with awk `$0 == ...`.
#
# REAL REPOSITORIES, REAL WORKTREES. Each fixture is a main checkout on `main`
# with a bare repository as `origin` and `main` pushed, so `origin/main` is a
# real remote-tracking ref; every worktree is made with `git worktree add`,
# never copied (worktree.test.sh says why). Every fixture's distinguishing fact
# is asserted BEFORE its verdict, through `facts`, so a broken fixture fails as
# a fixture and not as a verdict.
#
# THE SCRIPT RUNS FROM A COPY INSIDE EACH FIXTURE. `scripts/` and
# `.claude/hooks/` are copied into every main checkout, untracked, and tidy is
# run as `bash <fixture main>/scripts/tidy.sh` from a directory inside the
# fixture. So whether an implementation finds its repository from the cwd (as
# C-1 requires) or, wrongly, from its own location, the repository it judges -
# and, under --apply, the one it removes from - is a throwaway fixture, never
# this checkout. C-1 itself is pinned in report mode only, by running one
# fixture's copy from another directory.
#
# PATHS ARE GIT'S SPELLING. C-2 prints paths as `git worktree list --porcelain`
# prints them (C:/... under Git for Windows, not /tmp/...). Expected lines are
# built from that same porcelain output, never from the path mktemp returned.
# Worktree order is git's too, and git does not sort it: readdir order of
# .git/worktrees differs between filesystems. So an expected report is built by
# walking the porcelain records in order and asking a per-fixture verdict table
# for each one.
#
# AGES. A fresh worktree's files are all "now". Every fixture meant to be idle
# has every file backdated with `touch -t 202001010000` (portable: GNU and BSD
# both take [[CC]YY]MMDDhhmm), and the `recent` fixture differs only by one
# tracked file left fresh. The 24-hour default is pinned from both sides by a
# file 25 hours old (idle) and one 23 hours old (recent).
#
# NEEDLES. Whole-line matches through awk over a here-string; no `| grep -q`
# under pipefail, no `grep -c ... || printf 0`. Absence checks on a name
# (`no line mentions story/b-open`) are deliberately floating: absence of a
# substring is the STRONGER claim, so it cannot be satisfied by a different
# spelling of the same mention.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t harness.XXXXXX)"
OLD=202001010000

# Every worktree any fixture made, so the trap can remove each through git.
cleanup() {
  local m p
  # HARNESS-122: the rule-6 fixture is chmod 000 on hosts that honour it, and
  # rm -rf cannot descend into it until it is readable again.
  chmod -R u+rwx "$WORK/h122" 2>/dev/null
  for m in "$WORK"/a "$WORK"/b "$WORK"/c "$WORK"/d "$WORK"/e "$WORK"/z \
           "$WORK"/h122/ac1/main "$WORK"/h122/ac3/main "$WORK"/h122/ac4/main; do
    [ -d "$m/.git" ] || continue
    for p in $(awk '/^worktree / { print substr($0, 10) }' <<< "$(git -C "$m" worktree list --porcelain 2>/dev/null)"); do
      git -C "$m" worktree unlock "$p" >/dev/null 2>&1
      git -C "$m" worktree remove --force --force "$p" >/dev/null 2>&1
    done
    git -C "$m" worktree prune >/dev/null 2>&1
  done
  rm -rf "$WORK"
}
trap cleanup EXIT

# --- helpers -----------------------------------------------------------------

# new_repo <name>   $WORK/<name>.git (bare, the origin) and $WORK/<name> (the
# main checkout, on `main`, pushed). [origin] puts the bare repository
# elsewhere (HARNESS-122: a parent holding nothing but what a criterion names).
# Identity and autocrlf are set in the repository's own config, which every
# linked worktree shares. scripts/ and
# .claude/hooks/ are copied in UNTRACKED, so no worktree carries them.
new_repo() {
  local m="$WORK/$1" o="${2:-$WORK/$1.git}"
  git init -q --bare "$o"
  git init -q "$m"
  git -C "$m" symbolic-ref HEAD refs/heads/main
  git -C "$m" config core.autocrlf false
  git -C "$m" config user.email t@t
  git -C "$m" config user.name t
  printf 'node_modules/\n' > "$m/.gitignore"
  printf 'hello\n' > "$m/README"
  mkdir -p "$m/src"; printf 'x\n' > "$m/src/a.txt"
  git -C "$m" add .gitignore README src >/dev/null 2>&1
  git -C "$m" commit -qm init >/dev/null 2>&1
  git -C "$m" remote add origin "$o"
  git -C "$m" push -q origin main >/dev/null 2>&1
  cp -r "$REPO_ROOT/scripts" "$m/scripts"
  mkdir -p "$m/.claude"; cp -r "$REPO_ROOT/.claude/hooks" "$m/.claude/hooks"
}

# commit_in <tree> <file>   One new tracked file, committed in <tree>.
commit_in() {
  printf '%s\n' "$2" > "$1/$2"
  git -C "$1" add "$2" >/dev/null 2>&1
  git -C "$1" commit -qm "$2" >/dev/null 2>&1
}

# merged_branch <main> <name>   A branch with a commit of its own, merged into
# main by fast-forward. Pushing main is the caller's job.
merged_branch() {
  git -C "$1" checkout -q -b "$2" main
  commit_in "$1" "f-${2//\//-}"
  git -C "$1" checkout -q main
  git -C "$1" merge -q --ff-only "$2" >/dev/null 2>&1
}

# open_branch <main> <name>   A branch with a commit main does not have.
open_branch() {
  git -C "$1" checkout -q -b "$2" main
  commit_in "$1" "f-${2//\//-}"
  git -C "$1" checkout -q main
}

# age <dir> <stamp>   Every file and directory under <dir> gets mtime <stamp>.
age() { find "$1" -exec touch -t "$2" {} + 2>/dev/null; }

# ago <hours>   A touch -t stamp for that many hours ago, local time (touch -t
# reads local time and date prints it). GNU date, else BSD date.
ago() {
  local t=$(( $(date +%s) - $1 * 3600 ))
  date -d "@$t" +%Y%m%d%H%M.%S 2>/dev/null || date -r "$t" +%Y%m%d%H%M.%S
}

# porc_paths <main>   Every worktree path, as git prints it, in git's order.
porc_paths() {
  awk '/^worktree / { print substr($0, 10) }' <<< "$(git -C "$1" worktree list --porcelain)"
}

# wtp <main> <basename>   The porcelain path of the worktree with that last
# component. Basenames are unique across this suite's fixtures.
wtp() {
  awk -v b="$2" '{ n = split($0, p, "/"); if (p[n] == b) { print; exit } }' <<< "$(porc_paths "$1")"
}

# locked_of <main> <basename>   yes when that record carries a `locked` line.
locked_of() {
  awk -v b="$2" '
    /^worktree / { n = split(substr($0, 10), p, "/"); on = (p[n] == b); next }
    on && ($0 == "locked" || index($0, "locked ") == 1) { f = 1 }
    END { print (f ? "yes" : "no") }' <<< "$(git -C "$1" worktree list --porcelain)"
}

# facts <main> <dir>   The fixture oracle: the four facts of C-3 against
# origin/main and a 24-hour window, as `merged|clean|unlocked|idle` with each
# field flipped (`unmerged`, `uncommitted`, `locked`, `recent`) when it fails;
# `missing` alone when the folder is gone. This is how each fixture proves it
# differs from a REMOVABLE one in exactly the fact its name says.
facts() {
  local m="$1" w="$2" n a b c d f fresh=0
  n="$(basename "$w")"
  if [ ! -d "$w" ]; then printf missing; return 0; fi
  if git -C "$m" merge-base --is-ancestor "$(git -C "$w" rev-parse HEAD)" origin/main 2>/dev/null; then a=merged; else a=unmerged; fi
  if [ -z "$(git -C "$w" status --porcelain --untracked-files=all 2>/dev/null)" ]; then b=clean; else b=uncommitted; fi
  if [ "$(locked_of "$m" "$n")" = yes ]; then c=locked; else c=unlocked; fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -n "$(find "$w/$f" -prune -mmin -1440 2>/dev/null)" ] && fresh=$((fresh+1))
  done <<< "$(git -C "$w" ls-files -co --exclude-standard)"
  if [ "$fresh" -eq 0 ]; then d=idle; else d=recent; fi
  printf '%s|%s|%s|%s' "$a" "$b" "$c" "$d"
}

# T <main> <cwd> [args...]   Run <main>'s copy of tidy.sh from <cwd>. stdout
# is the result; stderr goes to $WORK/tidy.err for failure messages.
T() {
  local m="$1" d="$2"; shift 2
  ( cd "$d" && unset GITHUB_HEAD_REF PR_HEAD_SHA && bash "$m/scripts/tidy.sh" "$@" 2> "$WORK/tidy.err" )
}
err() { cat "$WORK/tidy.err" 2>/dev/null; }

# lines_eq <text> <line>   How many lines of <text> are exactly <line>.
lines_eq() {
  awk 'BEGIN { n = ARGV[2]; ARGV[2] = "" } $0 == n { c++ } END { print c + 0 }' - "$2" <<< "$1"
}

# has_line <what> <line> <text>   Exactly one line of <text> is <line>.
has_line() {
  local c; c="$(lines_eq "$3" "$2")"
  if [ "$c" = 1 ]; then _ok "$1"
  else _bad "$1" "expected exactly one line: $2
found it $c time(s) in:
$3
stderr: $(err)"; fi
}

# lacks_line <what> <line> <text>   No line of <text> is <line>.
lacks_line() {
  local c; c="$(lines_eq "$3" "$2")"
  if [ "$c" = 0 ]; then _ok "$1"
  else _bad "$1" "expected no line: $2
in:
$3"; fi
}

# mentions <text> <path>   How many lines name <path> as their subject: the
# rest after the first word is <path>, or begins `<path>  `.
mentions() {
  awk 'BEGIN { p = ARGV[2]; ARGV[2] = "" }
    { i = index($0, " "); if (!i) next; r = substr($0, i + 1)
      if (r == p || index(r, p "  ") == 1) c++ }
    END { print c + 0 }' - "$2" <<< "$1"
}

# starts <text> <prefix>   How many lines begin with <prefix>.
starts() {
  awk 'BEGIN { p = ARGV[2]; ARGV[2] = "" } index($0, p) == 1 { c++ } END { print c + 0 }' - "$2" <<< "$1"
}

# whole <what> <expected> <actual>   The whole output, byte for byte.
whole() {
  if [ "$2" = "$3" ]; then _ok "$1"
  else _bad "$1" "expected:
$2
actual:
$3
stderr: $(err)"; fi
}

# line_no <text> <n>
line_no() { awk -v n="$2" 'NR == n { print; exit }' <<< "$1"; }

# expect_report <main> <verdict-fn>   The worktree lines C-2 requires, in
# git's order: for each record after the main checkout, <verdict-fn> <basename>
# prints REMOVABLE, a KEEP reason, or SKIP (the worktree tidy runs in).
expect_report() {
  local p v first=1
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ "$first" = 1 ]; then first=0; continue; fi
    v="$("$2" "$(basename "$p")")"
    case "$v" in
      SKIP) ;;
      REMOVABLE) printf 'REMOVABLE %s\n' "$p" ;;
      *) printf 'KEEP %s  %s\n' "$p" "$v" ;;
    esac
  done <<< "$(porc_paths "$1")"
}

# finish_cmd <path>   C-5's finish-it command for a LEFT worktree.
# remove_cmd <path>   C-6's remove-it command for an ORPHAN (amended by RED).
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) WIN=1 ;;
  *) WIN=0 ;;
esac
remove_cmd() {
  if [ "$WIN" = 1 ]; then printf "Remove-Item -LiteralPath '%s%s' -Recurse -Force" '\\?\' "${1//\//\\}"
  else printf "rm -rf -- '%s'" "$1"; fi
}
finish_cmd() {
  if [ "$WIN" = 1 ]; then printf '%s; git worktree prune' "$(remove_cmd "$1")"
  else printf '%s && git worktree prune' "$(remove_cmd "$1")"; fi
}

# snapshot <main>   Everything AC-1 says report mode must not change: the
# worktree list, every ref and its target, the main checkout's status, and each
# live worktree's status and newest-file listing.
snapshot() {
  local m="$1" p
  git -C "$m" worktree list --porcelain
  git -C "$m" for-each-ref --format='%(refname) %(objectname)'
  git -C "$m" status
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    printf '== %s\n' "$p"
    [ -d "$p" ] || { printf 'absent\n'; continue; }
    git -C "$p" status --porcelain --untracked-files=all
    ( cd "$p" && find . -path ./.git -prune -o -print | LC_ALL=C sort )
  done <<< "$(porc_paths "$m")"
}

census() { printf 'tidy: %s worktree(s), %s removable, %s kept; %s merged branch(es) deletable' "$@"; }

# ===========================================================================
describe "AC-1 negative control: a repository with only its main checkout"

new_repo z
out="$(T "$WORK/z" "$WORK/z")"; rc=$?
assert_eq "AC-1 control: precondition - the fixture has exactly one worktree, its main checkout" \
  1 "$(porc_paths "$WORK/z" | awk 'END { print NR }')"
whole "AC-1 control: tidy in a repository with no other worktree prints only the census, 0 worktree(s), and nothing else" \
  "$(census 0 0 0 0)" "$out"
assert_eq "AC-1 control: and exits 0" 0 "$rc"

# ===========================================================================
describe "AC-2 fixtures: one worktree per fact, each differing from a REMOVABLE one in that fact alone"

new_repo a
A="$WORK/a"
# The removable pair: one detached (the baseline every reason fixture is a
# one-fact edit of), one on a branch whose remote copy exists, so the branch
# can never be DELETABLE and the census's M stays 0 in this repository.
git -C "$A" worktree add -q --detach "$WORK/a-rm-detached" main >/dev/null 2>&1
git -C "$A" worktree add -q -b story/a-rm-branch "$WORK/a-rm-branch" main >/dev/null 2>&1
git -C "$A" push -q origin story/a-rm-branch >/dev/null 2>&1
# unmerged: one commit origin/main does not have.
git -C "$A" worktree add -q --detach "$WORK/a-unmerged" main >/dev/null 2>&1
commit_in "$WORK/a-unmerged" unmerged.txt
# uncommitted: one untracked file.
git -C "$A" worktree add -q --detach "$WORK/a-uncommitted" main >/dev/null 2>&1
printf 'wip\n' > "$WORK/a-uncommitted/notes.txt"
# locked.
git -C "$A" worktree add -q --detach "$WORK/a-locked" main >/dev/null 2>&1
# recent: one tracked file touched now (below, after the backdating).
git -C "$A" worktree add -q --detach "$WORK/a-recent" main >/dev/null 2>&1
# ignored-fresh: a fresh file inside an ignored directory - removable, because
# ignored files are what a removal frees, not evidence of work (C-3).
git -C "$A" worktree add -q --detach "$WORK/a-ignored-fresh" main >/dev/null 2>&1
# idle25 / idle23: the 24-hour default, from both sides.
git -C "$A" worktree add -q --detach "$WORK/a-idle25" main >/dev/null 2>&1
git -C "$A" worktree add -q --detach "$WORK/a-idle23" main >/dev/null 2>&1
# missing: registered, folder gone.
git -C "$A" worktree add -q --detach "$WORK/a-missing" main >/dev/null 2>&1
# ORDER fixtures: each fails several facts and must report the earliest.
git -C "$A" worktree add -q --detach "$WORK/a-all-four" main >/dev/null 2>&1
commit_in "$WORK/a-all-four" ahead.txt
git -C "$A" worktree add -q --detach "$WORK/a-three" main >/dev/null 2>&1
git -C "$A" worktree add -q --detach "$WORK/a-two" main >/dev/null 2>&1
git -C "$A" worktree add -q --detach "$WORK/a-missing-locked" main >/dev/null 2>&1

for n in a-rm-detached a-rm-branch a-unmerged a-uncommitted a-locked a-recent a-ignored-fresh \
         a-idle25 a-idle23 a-missing a-all-four a-three a-two a-missing-locked; do
  age "$WORK/$n" "$OLD"
done
touch "$WORK/a-recent/src/a.txt"
mkdir -p "$WORK/a-ignored-fresh/node_modules/pkg"; printf 'x\n' > "$WORK/a-ignored-fresh/node_modules/pkg/index.js"
touch -t "$(ago 25)" "$WORK/a-idle25/src/a.txt"
touch -t "$(ago 23)" "$WORK/a-idle23/src/a.txt"
printf 'wip\n' > "$WORK/a-all-four/fresh.txt"                   # + uncommitted, recent
git -C "$A" worktree lock "$WORK/a-all-four" >/dev/null 2>&1    # + locked
printf 'wip\n' > "$WORK/a-three/fresh.txt"                      # uncommitted + recent
git -C "$A" worktree lock "$WORK/a-three" >/dev/null 2>&1       # + locked
touch "$WORK/a-two/src/a.txt"                                   # recent
git -C "$A" worktree lock "$WORK/a-two" >/dev/null 2>&1         # + locked
git -C "$A" worktree lock "$WORK/a-locked" >/dev/null 2>&1
git -C "$A" worktree lock "$WORK/a-missing-locked" >/dev/null 2>&1
rm -rf "$WORK/a-missing" "$WORK/a-missing-locked"
# The main checkout is never listed "whatever its state": make it dirty.
printf 'wip\n' > "$A/main-dirty.txt"

# Each fixture's facts, BEFORE any verdict. The left column is what the name
# claims; a fixture that does not have it is a bug in this suite.
for pair in a-rm-detached:merged\|clean\|unlocked\|idle \
            a-rm-branch:merged\|clean\|unlocked\|idle \
            a-unmerged:unmerged\|clean\|unlocked\|idle \
            a-uncommitted:merged\|uncommitted\|unlocked\|idle \
            a-locked:merged\|clean\|locked\|idle \
            a-recent:merged\|clean\|unlocked\|recent \
            a-ignored-fresh:merged\|clean\|unlocked\|idle \
            a-idle25:merged\|clean\|unlocked\|idle \
            a-idle23:merged\|clean\|unlocked\|recent \
            a-missing:missing \
            a-all-four:unmerged\|uncommitted\|locked\|recent \
            a-three:merged\|uncommitted\|locked\|recent \
            a-two:merged\|clean\|locked\|recent \
            a-missing-locked:missing; do
  n="${pair%%:*}"; want="${pair#*:}"
  assert_eq "fixture $n: its facts are $want" "$want" "$(facts "$A" "$WORK/$n")"
done
assert_eq "fixture a-missing-locked: is still locked, with its folder gone (git prints no 'prunable' for it)" \
  yes "$(locked_of "$A" a-missing-locked)"
assert_eq "fixture a-ignored-fresh: does hold a file modified in the last hour, inside node_modules/" \
  1 "$(find "$WORK/a-ignored-fresh/node_modules" -type f -mmin -60 | awk 'END { print NR }')"
assert_eq "fixture a-idle25: src/a.txt is between 24 and 26 hours old" \
  "old|young" "$([ -n "$(find "$WORK/a-idle25/src/a.txt" -mmin +1440)" ] && printf old || printf new)|$([ -n "$(find "$WORK/a-idle25/src/a.txt" -mmin -1560)" ] && printf young || printf ancient)"
assert_eq "fixture a-idle23: src/a.txt is between 22 and 24 hours old" \
  "young|old" "$([ -n "$(find "$WORK/a-idle23/src/a.txt" -mmin -1440)" ] && printf young || printf old)|$([ -n "$(find "$WORK/a-idle23/src/a.txt" -mmin +1320)" ] && printf old || printf new)"
assert_eq "fixture a: the main checkout is dirty" 1 \
  "$(awk 'END { print NR }' <<< "$(git -C "$A" status --porcelain -- main-dirty.txt)")"

verdict_a() {
  case "$1" in
    a-rm-detached|a-rm-branch|a-ignored-fresh|a-idle25) printf REMOVABLE ;;
    a-unmerged|a-all-four) printf unmerged ;;
    a-uncommitted|a-three) printf uncommitted ;;
    a-locked|a-two) printf locked ;;
    a-recent|a-idle23) printf recent ;;
    a-missing|a-missing-locked) printf missing ;;
    *) printf 'UNEXPECTED(%s)' "$1" ;;
  esac
}

# ===========================================================================
describe "AC-1 and AC-2: the report, line by line"

# Fixture a's paths and expected reports, read BEFORE tidy runs: every
# assertion below names a path, a `git worktree list` per name costs a process
# spawn each on Windows, and an expectation built after the run would follow
# whatever the run did to the worktree list.
PA="$(porc_paths "$A")"
P() { awk -v b="$1" '{ n = split($0, p, "/"); if (p[n] == b) { print; exit } }' <<< "$PA"; }
verdict_a_from_recent() { [ "$1" = a-recent ] && printf SKIP || verdict_a "$1"; }
EXPECT_A="$(expect_report "$A" verdict_a; census 14 4 10 0)"
EXPECT_A_RECENT="$(expect_report "$A" verdict_a_from_recent; census 13 4 9 0)"

before="$(snapshot "$A")"
out="$(T "$A" "$A")"; rc=$?
after="$(snapshot "$A")"

has_line "AC-2: a merged, clean, unlocked, idle detached worktree is REMOVABLE" "REMOVABLE $(P a-rm-detached)" "$out"
has_line "AC-2: and so is one on a branch" "REMOVABLE $(P a-rm-branch)" "$out"
has_line "AC-2 unmerged: a worktree whose HEAD is not in origin/main is KEEP, reason unmerged" "KEEP $(P a-unmerged)  unmerged" "$out"
has_line "AC-2 uncommitted: a worktree with an untracked file is KEEP, reason uncommitted" "KEEP $(P a-uncommitted)  uncommitted" "$out"
has_line "AC-2 locked: a locked worktree is KEEP, reason locked" "KEEP $(P a-locked)  locked" "$out"
has_line "AC-2 recent: a worktree with one tracked file modified now is KEEP, reason recent" "KEEP $(P a-recent)  recent" "$out"
has_line "AC-2 missing: a registered worktree whose folder is gone is KEEP, reason missing" "KEEP $(P a-missing)  missing" "$out"
has_line "AC-2.4: a fresh file in an ignored directory does not make a worktree recent" "REMOVABLE $(P a-ignored-fresh)" "$out"
has_line "AC-2.4 default 24h: a tracked file 25 hours old leaves the worktree REMOVABLE" "REMOVABLE $(P a-idle25)" "$out"
has_line "AC-2.4 default 24h: a tracked file 23 hours old makes it KEEP recent" "KEEP $(P a-idle23)  recent" "$out"
has_line "AC-2 order: unmerged + uncommitted + locked + recent reports unmerged" "KEEP $(P a-all-four)  unmerged" "$out"
has_line "AC-2 order: uncommitted + locked + recent reports uncommitted" "KEEP $(P a-three)  uncommitted" "$out"
has_line "AC-2 order: locked + recent reports locked" "KEEP $(P a-two)  locked" "$out"
has_line "AC-2 order: missing is checked before the four - missing and locked reports missing" "KEEP $(P a-missing-locked)  missing" "$out"
assert_eq "AC-2: the main checkout is never listed, though it is dirty" 0 "$(mentions "$out" "$(wtp "$A" a)")"
has_line "AC-1: the census counts 14 worktrees, 4 removable, 10 kept, 0 branches" "$(census 14 4 10 0)" "$out"
whole "AC-1/C-2: the whole report is the worktree lines in git worktree list order, then the census, and nothing else" \
  "$EXPECT_A" "$out"
assert_eq "AC-1: report mode exits 0" 0 "$rc"
if [ "$before" = "$after" ]; then _ok "AC-1: the worktree list, every ref, git status and every worktree's files are byte-identical before and after"
else _bad "AC-1: the worktree list, every ref, git status and every worktree's files are byte-identical before and after" "$(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | awk 'NR <= 20')"; fi

# ===========================================================================
describe "AC-2: the current worktree is never listed, and C-1: the root is the cwd's"

# Run the MAIN checkout's copy from inside a-recent. The current worktree is
# a-recent (by cwd), so it is not listed; the main checkout is now just another
# record and is not listed either. An implementation that took its root from
# the script's location would treat the main checkout as current and list
# a-recent as KEEP recent.
out="$(T "$A" "$WORK/a-recent")"; rc=$?
lacks_line "AC-2: run inside a-recent, a-recent is not listed" "KEEP $(P a-recent)  recent" "$out"
assert_eq "AC-2: run inside a-recent, the main checkout is not listed either" 0 "$(mentions "$out" "$(wtp "$A" a)")"
whole "C-1: run inside a linked worktree, the report is every other non-main worktree, then 13 / 4 / 9" \
  "$EXPECT_A_RECENT" "$out"

# Fixture a's copy, run from fixture z: it judges z, the cwd's repository.
out="$(T "$A" "$WORK/z")"
whole "C-1: a copy of tidy.sh run from another repository judges the cwd's repository, not its own" \
  "$(census 0 0 0 0)" "$out"

# ===========================================================================
describe "AC-2.4 and C-1: --idle-hours and --base"

out="$(T "$A" "$A" --idle-hours 26)"
has_line "--idle-hours 26: the 25-hour-old worktree becomes KEEP recent" "KEEP $(P a-idle25)  recent" "$out"
out="$(T "$A" "$A" --idle-hours 22)"
has_line "--idle-hours 22: the 23-hour-old worktree becomes REMOVABLE" "REMOVABLE $(P a-idle23)" "$out"

UNM="$(git -C "$WORK/a-unmerged" rev-parse HEAD)"
out="$(T "$A" "$A" --base "$UNM")"
has_line "--base REF: judged against the unmerged worktree's own commit, that worktree is REMOVABLE" "REMOVABLE $(P a-unmerged)" "$out"
has_line "--base REF: and a commit outside REF is still unmerged" "KEEP $(P a-all-four)  unmerged" "$out"

before="$(snapshot "$A")"
out="$( cd "$A" && bash "$A/scripts/tidy.sh" --base no/such/ref 2>&1 )"; rc=$?
after="$(snapshot "$A")"
assert_eq "C-1: a --base that does not resolve exits 2" 2 "$rc"
whole "C-1: and prints exactly one line, naming the ref, and nothing else" "tidy: base 'no/such/ref' does not resolve" "$out"
assert_eq "C-1: and changes nothing" same "$([ "$before" = "$after" ] && printf same || printf changed)"

for bad in abc -3 1.5; do
  ( cd "$A" && bash "$A/scripts/tidy.sh" --idle-hours "$bad" >/dev/null 2>&1 ); rc=$?
  assert_eq "C-1: --idle-hours $bad is not a whole number: exit 2" 2 "$rc"
done
( cd "$A" && bash "$A/scripts/tidy.sh" --idle-hours >/dev/null 2>&1 ); rc=$?
assert_eq "C-1: --idle-hours with no value: exit 2" 2 "$rc"
( cd "$A" && bash "$A/scripts/tidy.sh" --frobnicate >/dev/null 2>&1 ); rc=$?
assert_eq "C-1: an unknown option: exit 2" 2 "$rc"

# ===========================================================================
describe "AC-3: merged local branches"

new_repo b
B="$WORK/b"
merged_branch "$B" story/b-done
merged_branch "$B" harness/b-done
merged_branch "$B" claude/b-done
merged_branch "$B" feature/b-done
merged_branch "$B" storyboard/b-done
merged_branch "$B" story/b-still-remote
merged_branch "$B" story/b-checked-out
git -C "$B" push -q origin main >/dev/null 2>&1
git -C "$B" push -q origin story/b-still-remote >/dev/null 2>&1
open_branch "$B" story/b-open
# b-wt holds story/b-checked-out, left fresh, so it is KEEP recent.
git -C "$B" worktree add -q "$WORK/b-wt" story/b-checked-out >/dev/null 2>&1

anc() { git -C "$B" merge-base --is-ancestor "$1" origin/main 2>/dev/null && printf merged || printf unmerged; }
rem() { git -C "$B" rev-parse -q --verify "refs/remotes/origin/$1" >/dev/null 2>&1 && printf remote || printf noremote; }
co()  { [ "$(awk -v r="branch refs/heads/$1" '$0 == r { f = 1 } END { print f + 0 }' <<< "$(git -C "$B" worktree list --porcelain)")" = 1 ] && printf out || printf in; }
bfacts() { printf '%s|%s|%s' "$(anc "$1")" "$(co "$1")" "$(rem "$1")"; }
for pair in story/b-done:merged\|in\|noremote harness/b-done:merged\|in\|noremote \
            claude/b-done:merged\|in\|noremote feature/b-done:merged\|in\|noremote \
            storyboard/b-done:merged\|in\|noremote story/b-open:unmerged\|in\|noremote \
            story/b-checked-out:merged\|out\|noremote story/b-still-remote:merged\|in\|remote \
            main:merged\|out\|remote; do
  n="${pair%%:*}"; want="${pair#*:}"
  assert_eq "fixture branch $n: merged / checked out / remote-tracking ref is $want" "$want" "$(bfacts "$n")"
done
assert_eq "fixture b-wt: its facts are merged|clean|unlocked|recent" "merged|clean|unlocked|recent" "$(facts "$B" "$WORK/b-wt")"

out="$(T "$B" "$B")"; rc=$?
has_line "AC-3: a merged story/* branch, checked out nowhere, with no origin copy, is DELETABLE" "DELETABLE story/b-done" "$out"
has_line "AC-3: and so is a harness/* branch" "DELETABLE harness/b-done" "$out"
for n in main claude/b-done feature/b-done storyboard/b-done story/b-open story/b-checked-out story/b-still-remote; do
  assert_eq "AC-3: $n is never mentioned, on any line" 0 \
    "$(awk 'BEGIN { p = ARGV[2]; ARGV[2] = "" } { i = index($0, " "); r = substr($0, i + 1); if (r == p || index($0, "DELETABLE " p) == 1) c++ } END { print c + 0 }' - "$n" <<< "$out")"
done
for n in claude/b-done feature/b-done storyboard/b-done story/b-open story/b-still-remote; do
  assert_eq "AC-3/C-4: no line names $n at all" absent "$(case "$out" in *"$n"*) printf named ;; *) printf absent ;; esac)"
done
whole "AC-3/C-2: the whole report is the worktree line, the DELETABLE lines sorted, then the census" \
  "KEEP $(wtp "$B" b-wt)  recent
DELETABLE harness/b-done
DELETABLE story/b-done
$(census 1 0 1 2)" "$out"
assert_eq "AC-3: report mode exits 0" 0 "$rc"

out="$(T "$B" "$B" --base story/b-open)"
has_line "--base REF: judged against story/b-open, story/b-open itself is merged and DELETABLE" "DELETABLE story/b-open" "$out"
lacks_line "--base REF: and a branch whose remote copy exists still is not" "DELETABLE story/b-still-remote" "$out"

# ===========================================================================
describe "AC-4: --apply does exactly what the report said"

new_repo c
C="$WORK/c"
merged_branch "$C" story/c-done
git -C "$C" push -q origin main >/dev/null 2>&1
open_branch "$C" story/c-open
git -C "$C" worktree add -q -b story/c-kept-wt "$WORK/c-rm-branch" main >/dev/null 2>&1
git -C "$C" push -q origin story/c-kept-wt >/dev/null 2>&1
git -C "$C" worktree add -q --detach "$WORK/c-rm-detached" main >/dev/null 2>&1
git -C "$C" worktree add -q --detach "$WORK/c-keep-unmerged" main >/dev/null 2>&1
commit_in "$WORK/c-keep-unmerged" unmerged.txt
git -C "$C" worktree add -q --detach "$WORK/c-keep-locked" main >/dev/null 2>&1
for n in c-rm-branch c-rm-detached c-keep-unmerged c-keep-locked; do age "$WORK/$n" "$OLD"; done
git -C "$C" worktree lock "$WORK/c-keep-locked" >/dev/null 2>&1

for pair in c-rm-branch:merged\|clean\|unlocked\|idle c-rm-detached:merged\|clean\|unlocked\|idle \
            c-keep-unmerged:unmerged\|clean\|unlocked\|idle c-keep-locked:merged\|clean\|locked\|idle; do
  n="${pair%%:*}"; want="${pair#*:}"
  assert_eq "fixture $n: its facts are $want" "$want" "$(facts "$C" "$WORK/$n")"
done

verdict_c() {
  case "$1" in
    c-rm-branch|c-rm-detached) printf REMOVABLE ;;
    c-keep-unmerged) printf unmerged ;;
    c-keep-locked) printf locked ;;
    *) printf 'UNEXPECTED(%s)' "$1" ;;
  esac
}
# The actions, in report order: each REMOVABLE worktree, then the branch.
removed_c() {
  local p first=1
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ "$first" = 1 ]; then first=0; continue; fi
    [ "$(verdict_c "$(basename "$p")")" = REMOVABLE ] && printf 'removed %s\n' "$p"
  done <<< "$(porc_paths "$C")"
  return 0
}
EXPECT_C="$(expect_report "$C" verdict_c; printf 'DELETABLE story/c-done\n'; removed_c; printf 'deleted story/c-done\n'; census 4 2 2 1)"
WT_BEFORE="$(porc_paths "$C" | LC_ALL=C sort)"
BR_BEFORE="$(git -C "$C" for-each-ref --format='%(refname:short)' refs/heads | LC_ALL=C sort)"
UNM_HEAD="$(git -C "$WORK/c-keep-unmerged" rev-parse HEAD)"
UNM_FILES="$( cd "$WORK/c-keep-unmerged" && find . -path ./.git -prune -o -print | LC_ALL=C sort )"
RM_BRANCH="$(wtp "$C" c-rm-branch)"; RM_DET="$(wtp "$C" c-rm-detached)"

out="$(T "$C" "$C" --apply)"; rc=$?
whole "AC-4/C-2: --apply prints the report (without its census), then removed <path> per REMOVABLE worktree, then deleted <branch>, then the census of the state it acted on" \
  "$EXPECT_C" "$out"
assert_eq "AC-4: --apply with nothing LEFT exits 0" 0 "$rc"
assert_eq "AC-4: the worktree list lacks exactly the two REMOVABLE entries" \
  "$(awk -v a="$RM_BRANCH" -v b="$RM_DET" '$0 != a && $0 != b' <<< "$WT_BEFORE")" \
  "$(porc_paths "$C" | LC_ALL=C sort)"
assert_eq "AC-4: the branch list lacks exactly the DELETABLE branch" \
  "$(awk '$0 != "story/c-done"' <<< "$BR_BEFORE")" \
  "$(git -C "$C" for-each-ref --format='%(refname:short)' refs/heads | LC_ALL=C sort)"
assert_eq "AC-4: the removed worktrees' folders are gone" "gone|gone" \
  "$([ -e "$WORK/c-rm-branch" ] && printf there || printf gone)|$([ -e "$WORK/c-rm-detached" ] && printf there || printf gone)"
assert_eq "AC-4: a removed worktree's branch is kept" story/c-kept-wt \
  "$(git -C "$C" for-each-ref --format='%(refname:short)' refs/heads/story/c-kept-wt)"
assert_eq "AC-4: the KEEP unmerged worktree is untouched: registered, same HEAD, same files" \
  "1|$UNM_HEAD|same" \
  "$(lines_eq "$(porc_paths "$C")" "$(wtp "$C" c-keep-unmerged)")|$(git -C "$WORK/c-keep-unmerged" rev-parse HEAD 2>/dev/null)|$([ "$UNM_FILES" = "$( cd "$WORK/c-keep-unmerged" 2>/dev/null && find . -path ./.git -prune -o -print | LC_ALL=C sort )" ] && printf same || printf changed)"
assert_eq "AC-4: the KEEP locked worktree is untouched: there, and still locked" "there|yes" \
  "$([ -d "$WORK/c-keep-locked" ] && printf there || printf gone)|$(locked_of "$C" c-keep-locked)"
assert_eq "AC-4: the unmerged branch is kept" story/c-open \
  "$(git -C "$C" for-each-ref --format='%(refname:short)' refs/heads/story/c-open)"

out="$(T "$C" "$C" --apply)"; rc=$?
has_line "AC-4: a second --apply reports 0 removable" "$(census 2 0 2 0)" "$out"
assert_eq "AC-4: and acts on nothing" "0|0|0" \
  "$(starts "$out" 'removed ')|$(starts "$out" 'deleted ')|$(starts "$out" 'LEFT ')"
assert_eq "AC-4: and exits 0" 0 "$rc"

# ===========================================================================
describe "AC-4: a removal git refuses is LEFT, and the script carries on"

# THE LEFT MECHANISM, measured on this host before it was relied on (Git for
# Windows 2.55, 2026-10-19): a worktree holding a committed submodule is clean
# and merged, so it is REMOVABLE, and `git worktree remove` refuses it with
# "fatal: working trees containing submodules cannot be moved or removed",
# exit 128, leaving the folder and the registration in place. The suite
# re-measures that refusal below rather than trusting this comment, and takes
# git's own first line as the expected message.
new_repo e
E="$WORK/e"
git init -q "$WORK/e-subsrc"
git -C "$WORK/e-subsrc" config core.autocrlf false
printf 's\n' > "$WORK/e-subsrc/s"
git -C "$WORK/e-subsrc" add s >/dev/null 2>&1
git -C "$WORK/e-subsrc" -c user.email=t@t -c user.name=t commit -qm s >/dev/null 2>&1
merged_branch "$E" story/e-done
# e-rm is made BEFORE the submodule reaches main, so it holds no gitlink at
# all and git's own submodule refusal cannot reach it.
git -C "$E" worktree add -q --detach "$WORK/e-rm" main >/dev/null 2>&1
git -C "$E" worktree add -q -b story/e-sub "$WORK/e-sub" main >/dev/null 2>&1
git -C "$WORK/e-sub" -c protocol.file.allow=always submodule add -q "$WORK/e-subsrc" sm >/dev/null 2>&1
git -C "$WORK/e-sub" commit -qm "add submodule" >/dev/null 2>&1
git -C "$E" merge -q --ff-only story/e-sub >/dev/null 2>&1
git -C "$E" push -q origin main >/dev/null 2>&1
age "$WORK/e-sub" "$OLD"; age "$WORK/e-rm" "$OLD"
SUB="$(wtp "$E" e-sub)"; ERM="$(wtp "$E" e-rm)"

assert_eq "fixture e-sub: holds a committed submodule" 160000 \
  "$(git -C "$WORK/e-sub" ls-files -s sm | awk '{ print $1 }')"
assert_eq "fixture e-sub: its facts are merged|clean|unlocked|idle" "merged|clean|unlocked|idle" "$(facts "$E" "$WORK/e-sub")"
assert_eq "fixture e-rm: its facts are merged|clean|unlocked|idle" "merged|clean|unlocked|idle" "$(facts "$E" "$WORK/e-rm")"
GITMSG="$(git -C "$E" -c core.longpaths=true worktree remove "$SUB" 2>&1)"; grc=$?
GITMSG="$(line_no "$GITMSG" 1)"
assert_eq "fixture e-sub: git itself refuses to remove it, and leaves it registered and on disk" "refused|1|there" \
  "$([ "$grc" -ne 0 ] && printf refused || printf removed)|$(lines_eq "$(porc_paths "$E")" "$SUB")|$([ -d "$WORK/e-sub" ] && printf there || printf gone)"

verdict_e() { case "$1" in e-sub|e-rm) printf REMOVABLE ;; *) printf 'UNEXPECTED(%s)' "$1" ;; esac; }
actions_e() {
  local p first=1
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ "$first" = 1 ]; then first=0; continue; fi
    case "$(basename "$p")" in
      e-sub) printf 'LEFT %s  %s\n  finish it: %s\n' "$p" "$GITMSG" "$(finish_cmd "$p")" ;;
      e-rm)  printf 'removed %s\n' "$p" ;;
    esac
  done <<< "$(porc_paths "$E")"
}
EXPECT_E="$(expect_report "$E" verdict_e; printf 'DELETABLE story/e-done\n'; actions_e; printf 'deleted story/e-done\n'; census 2 2 0 1)"

out="$(T "$E" "$E" --apply)"; rc=$?
has_line "AC-4: the refused worktree is reported LEFT <path>  <git's first error line>" "LEFT $SUB  $GITMSG" "$out"
has_line "AC-4/C-5: followed by the command for the user to finish it" "  finish it: $(finish_cmd "$SUB")" "$out"
assert_eq "AC-4/C-5: the finish-it line comes straight after the LEFT line" 1 \
  "$(awk 'BEGIN { l = ARGV[2]; f = ARGV[3]; ARGV[2] = ""; ARGV[3] = "" }
          prev == l && $0 == f { c++ } { prev = $0 } END { print c + 0 }' \
        - "LEFT $SUB  $GITMSG" "  finish it: $(finish_cmd "$SUB")" <<< "$out")"
whole "AC-4/C-2: the whole --apply output with one LEFT: report, actions in report order, branch deletion, census" \
  "$EXPECT_E" "$out"
assert_eq "AC-4: a run with a LEFT exits 1" 1 "$rc"
assert_eq "AC-4: the LEFT folder is still on disk and still registered - nothing deleted it by other means" "there|1" \
  "$([ -d "$WORK/e-sub" ] && printf there || printf gone)|$(lines_eq "$(porc_paths "$E")" "$SUB")"
assert_eq "AC-4: it carried on - the other REMOVABLE worktree is removed" "gone|0" \
  "$([ -e "$WORK/e-rm" ] && printf there || printf gone)|$(lines_eq "$(porc_paths "$E")" "$ERM")"
assert_eq "AC-4: it carried on - the DELETABLE branch is deleted after the failure" "" \
  "$(git -C "$E" for-each-ref --format='%(refname:short)' refs/heads/story/e-done)"

# ===========================================================================
describe "AC-5: orphan folders under .claude/worktrees/ are reported, never deleted"

new_repo d
D="$WORK/d"
W="$D/.claude/worktrees"
mkdir -p "$W/o-empty" "$W/o-dirs/node_modules/a/b" "$W/o-dirs/node_modules/c" "$W/o-one" "$W/o-three/x/y"
printf '1\n' > "$W/o-one/f"
printf '1\n' > "$W/o-three/a"; printf '2\n' > "$W/o-three/x/b"; printf '3\n' > "$W/o-three/x/y/c"
printf 'stray\n' > "$W/stray.txt"
mkdir -p "$WORK/d-outside"
git -C "$D" worktree add -q --detach "$W/reg" main >/dev/null 2>&1
DP="$(wtp "$D" d)"
assert_eq "fixture d: reg is a registered worktree under .claude/worktrees/" 1 "$(lines_eq "$(porc_paths "$D")" "$DP/.claude/worktrees/reg")"
assert_eq "fixture d: reg's facts are merged|clean|unlocked|recent" "merged|clean|unlocked|recent" "$(facts "$D" "$W/reg")"
assert_eq "fixture d: o-empty 0 files, o-dirs 0 files in 4 dirs, o-one 1, o-three 3" "0|0|4|1|3" \
  "$(find "$W/o-empty" -type f | awk 'END { print NR }')|$(find "$W/o-dirs" -type f | awk 'END { print NR }')|$(find "$W/o-dirs" -mindepth 1 -type d | awk 'END { print NR }')|$(find "$W/o-one" -type f | awk 'END { print NR }')|$(find "$W/o-three" -type f | awk 'END { print NR }')"

o() { printf '%s/.claude/worktrees/%s' "$DP" "$1"; }
EXPECT_D="KEEP $(o reg)  recent
ORPHAN $(o o-dirs)  empty
  remove it: $(remove_cmd "$(o o-dirs)")
ORPHAN $(o o-empty)  empty
  remove it: $(remove_cmd "$(o o-empty)")
ORPHAN $(o o-one)  1 file(s)
  remove it: $(remove_cmd "$(o o-one)")
ORPHAN $(o o-three)  3 file(s)
  remove it: $(remove_cmd "$(o o-three)")
$(census 1 0 1 0)"
SNAP_D="$(find "$W" | LC_ALL=C sort)"

out="$(T "$D" "$D")"; rc_report=$?
has_line "AC-5: an empty unregistered folder is ORPHAN <path>  empty" "ORPHAN $(o o-empty)  empty" "$out"
has_line "AC-5: a folder holding only empty directories is ORPHAN <path>  empty" "ORPHAN $(o o-dirs)  empty" "$out"
has_line "AC-5: a folder with one file is ORPHAN <path>  1 file(s)" "ORPHAN $(o o-one)  1 file(s)" "$out"
has_line "AC-5: a folder with three files, nested, is ORPHAN <path>  3 file(s)" "ORPHAN $(o o-three)  3 file(s)" "$out"
has_line "AC-5 (C-6 as amended): each ORPHAN line is followed by the command to run" "  remove it: $(remove_cmd "$(o o-three)")" "$out"
assert_eq "AC-5 control: the registered worktree under .claude/worktrees/ is never an ORPHAN, in any spelling" 0 \
  "$(awk 'index($0, "ORPHAN ") == 1 && index($0, "/.claude/worktrees/reg") { c++ } END { print c + 0 }' <<< "$out")"
has_line "AC-5 control: it is listed as the worktree it is" "KEEP $(o reg)  recent" "$out"
assert_eq "C-6: a plain file under .claude/worktrees/ and a folder outside it are never considered" "absent|absent" \
  "$(case "$out" in *stray.txt*) printf named ;; *) printf absent ;; esac)|$(case "$out" in *d-outside*) printf named ;; *) printf absent ;; esac)"
whole "AC-5/C-2: the whole report: worktree lines, ORPHAN lines sorted each with its command, census (orphans not counted)" \
  "$EXPECT_D" "$out"

out="$(T "$D" "$D" --apply)"; rc_apply=$?
whole "AC-5: --apply prints the same report and acts on no orphan" "$EXPECT_D" "$out"
assert_eq "AC-5: --apply leaves every orphan and every file in it on disk" same \
  "$([ "$SNAP_D" = "$(find "$W" | LC_ALL=C sort)" ] && printf same || printf changed)"
assert_eq "AC-5: orphans do not change the exit status: report 0, --apply 0" "0|0" "$rc_report|$rc_apply"

# ===========================================================================
# HARNESS-122 - STRAY: a folder beside the main checkout that holds nothing a
# checkout would, which tidy now reports (story Contract C-1 to C-8). Every
# criterion is mechanical (C-9): whole reports, whole lines, exit statuses, a
# before-and-after listing.
#
# EVERY PARENT HERE IS A DIRECTORY OF ITS OWN, $WORK/h122/<case>/, never $WORK.
# Every fixture above keeps its main checkout directly in $WORK, so $WORK is
# the parent tidy reads for all of them, and a stray-shaped folder there would
# move their whole-report assertions (C-8). Origins go to $WORK/h122/origins/
# and link targets to $WORK/h122/targets/, so each parent holds exactly what
# its criterion names - which the first fact of each case asserts. Nothing the
# fixtures above leave in $WORK is stray-shaped: d-outside is empty (no ignored
# top-level directory, C-2 rule 3), the bare origins and every main hold files,
# and so does h122 itself.
#
# LINKS UNDER GIT FOR WINDOWS (measured by this story's RED, MINGW64, Windows
# 11, 2026-11-23, no Developer Mode): `ln -s` to a missing target fails with
# "No such file or directory"; `ln -s` to an existing file COPIES it (a regular
# file, which `find -type l` does not see); with MSYS=winsymlinks:nativestrict
# it fails "Operation not permitted", and `mklink` for a file needs a privilege
# the host lacks. `cmd /c mklink /J` makes a junction: `find -type l` lists it,
# `[ -L ]` is true, and once its target is removed `[ -e ]` is false. So a
# dangling link here is a junction whose target was removed (the kind C-8 says
# the measured folders hold), and a resolving link is a file symlink where the
# host can make one, else a junction to a directory. That second fixture is the
# one place the suite differs by host, and its fact assertion says which kind it
# made. Every fixture's shape is asserted before tidy runs (h_shape).
#
# RULE 6 (a folder that cannot be read is never STRAY) is pinned only where a
# directory CAN be made unreadable: a probe chmod 000s a scratch directory and
# asks `find` to read it. Under Git for Windows chmod 000 changes nothing and
# the probe says so, and as root nothing is unreadable; on a non-root Linux or
# macOS runner (CI) the case runs. It is not a skipped test: where the probe
# says no, the fixture cannot exist, so there is nothing to assert about it.

H122="$WORK/h122"
mkdir -p "$H122/origins" "$H122/targets"

# h_parent <case>   $WORK/h122/<case>/main, its origin under h122/origins/.
h_parent() {
  mkdir -p "$H122/$1"
  new_repo "h122/$1/main" "$H122/origins/$1.git"
}

# h_link_dangling <link>   A link whose target does not exist.
h_link_dangling() {
  local t="$1.gone"
  if [ "$WIN" = 1 ]; then
    mkdir -p "$t"
    MSYS_NO_PATHCONV=1 cmd /c mklink /J "$(cygpath -w "$1")" "$(cygpath -w "$t")" >/dev/null 2>&1
    rmdir "$t"
  else
    ln -s "$t" "$1"
  fi
}

# h_link_resolving <link> <file>   A link that resolves to <file>, which is
# outside the folder. Prints the kind made: `file`, or `directory` (a junction
# to <file>'s directory) where the host cannot make a file symlink.
h_link_resolving() {
  if [ "$WIN" = 1 ]; then
    if MSYS=winsymlinks:nativestrict ln -s "$2" "$1" 2>/dev/null && [ -L "$1" ]; then printf file; return 0; fi
    MSYS_NO_PATHCONV=1 cmd /c mklink /J "$(cygpath -w "$1")" "$(cygpath -w "${2%/*}")" >/dev/null 2>&1
    printf directory
  else
    ln -s "$2" "$1"; printf file
  fi
}

# h_strays <parent> <dirs-name> <link-name>   The two stray-shaped folders of
# AC-1: one holding directories only, one also holding a dangling link.
h_strays() {
  mkdir -p "$1/$2/node_modules/a/b" "$1/$2/node_modules/c" "$1/$3/node_modules/a/b"
  h_link_dangling "$1/$3/node_modules/a/dead"
}

# h_ls <dir>   Its top-level entries, sorted, comma-joined; `-` when none.
h_ls() {
  ( cd "$1" && ls -A ) | LC_ALL=C sort | awk '{ s = s (NR > 1 ? "," : "") $0 } END { print (NR ? s : "-") }'
}

# h_shape <main> <dir>   The facts that make a folder stray-shaped, as
#   git|listed|files=N|links=N|resolving=N|top=..|ignored=..|nested=N
# `git` when it has a .git entry; `listed` when `git worktree list` names it;
# files and links counted by find at every depth, `resolving` the links for
# which [ -e ] is true; top its top-level entries; ignored those top-level
# directories `git -C <main> check-ignore` matches; nested the directories
# below the top level. Stray-shaped is nogit, unlisted, files=0, any number of
# links with resolving=0, an ignored top-level directory, and nested above 0.
h_shape() {
  local m="$1" d="$2" g=nogit li=unlisted f l=0 r=0 x ig="" n
  if [ -e "$d/.git" ] || [ -L "$d/.git" ]; then g=git; fi
  while IFS= read -r x; do
    [ -n "$x" ] || continue
    if [ "$x" -ef "$d" ]; then li=listed; fi
  done <<< "$(porc_paths "$m")"
  f="$(find "$d" -type f 2>/dev/null | awk 'END { print NR }')"
  while IFS= read -r x; do
    [ -n "$x" ] || continue
    l=$((l + 1)); if [ -e "$x" ]; then r=$((r + 1)); fi
  done <<< "$(find "$d" -type l 2>/dev/null)"
  for x in $(cd "$d" && ls -A); do
    if [ -d "$d/$x" ] && [ ! -L "$d/$x" ] && git -C "$m" check-ignore -q -- "$x/" 2>/dev/null; then ig="$ig${ig:+,}$x"; fi
  done
  n="$(find "$d" -mindepth 2 -type d 2>/dev/null | awk 'END { print NR }')"
  printf '%s|%s|files=%s|links=%s|resolving=%s|top=%s|ignored=%s|nested=%s' \
    "$g" "$li" "$f" "$l" "$r" "$(h_ls "$d")" "${ig:--}" "$n"
}

# h_pair <path>   The STRAY pair for <path>, as C-3 and the criteria spell it.
h_pair() { printf 'STRAY %s  empty\n  remove it: %s' "$1" "$(remove_cmd "$1")"; }

# h_pairs_of <text> <path>   How many times the STRAY pair for <path> appears
# as two consecutive whole lines.
h_pairs_of() {
  awk 'BEGIN { s = ARGV[2]; c = ARGV[3]; ARGV[2] = ""; ARGV[3] = "" }
       prev == s && $0 == c { n++ } { prev = $0 } END { print n + 0 }' \
    - "STRAY $2  empty" "  remove it: $(remove_cmd "$2")" <<< "$1"
}

# h_stray_names <text> <path>   How many lines beginning `STRAY ` name <path>
# or anything under it: the rest of the line is <path>, or begins `<path> ` or
# `<path>/`.
h_stray_names() {
  awk 'BEGIN { p = ARGV[2]; ARGV[2] = "" }
       index($0, "STRAY ") == 1 { r = substr($0, 7)
         if (r == p || index(r, p " ") == 1 || index(r, p "/") == 1) c++ }
       END { print c + 0 }' - "$2" <<< "$1"
}

# h_listing <dir>   Every entry under <dir>, as find lists it, sorted.
h_listing() { find "$1" | LC_ALL=C sort; }

# h_link_where <link>   inside or outside <link>'s top folder, by its target.
h_link_where() {
  local t; t="$(readlink "$1")"
  case "$t" in '') printf unread ;; *"$2"*) printf inside ;; *) printf outside ;; esac
}

STRAY_DIRS="nogit|unlisted|files=0|links=0|resolving=0|top=node_modules|ignored=node_modules|nested=3"
STRAY_LINK="nogit|unlisted|files=0|links=1|resolving=0|top=node_modules|ignored=node_modules|nested=2"

# ===========================================================================
describe "HARNESS-122 AC-1: two stray-shaped folders beside the main checkout are each reported STRAY, with the command to remove them"

h_parent ac1
H1="$H122/ac1"; M1="$H1/main"
h_strays "$H1" s-dirs s-link
G1="$(line_no "$(porc_paths "$M1")" 1)"; P1="${G1%/*}"

assert_eq "fixture h122/ac1: the parent holds the main checkout and the two folders, nothing else" \
  "main,s-dirs,s-link" "$(h_ls "$H1")"
assert_eq "fixture h122/ac1: git lists only the main checkout" 1 "$(porc_paths "$M1" | awk 'END { print NR }')"
assert_eq "fixture s-dirs: stray-shaped - no .git, unlisted, no file, no link, one top-level entry node_modules (ignored), three nested directories" \
  "$STRAY_DIRS" "$(h_shape "$M1" "$H1/s-dirs")"
assert_eq "fixture s-link: stray-shaped, and also holds one link, which is dangling" \
  "$STRAY_LINK" "$(h_shape "$M1" "$H1/s-link")"

EXPECT_H1="$(h_pair "$P1/s-dirs")
$(h_pair "$P1/s-link")
$(census 0 0 0 0)"
out="$(T "$M1" "$M1")"; rc=$?
whole "HARNESS-122 AC-1: the whole report is the STRAY pair for each stray-shaped folder, sorted by name, then the unchanged census" \
  "$EXPECT_H1" "$out"
assert_eq "HARNESS-122 AC-1: and report mode exits 0" 0 "$rc"

# ===========================================================================
describe "HARNESS-122 AC-2: a folder that differs from stray-shaped in one fact is never STRAY"

# (a) one regular file, three levels down; (i) a stray-shaped folder inside (a).
mkdir -p "$H1/c-file/node_modules/a/b" "$H1/c-file/s-inner/node_modules/p/q"
printf 'x\n' > "$H1/c-file/node_modules/a/b/f.txt"
# (b) a .git file; a .git directory.
mkdir -p "$H1/c-gitfile/node_modules/a/b" "$H1/c-gitdir/node_modules/a/b" "$H1/c-gitdir/.git"
printf 'gitdir: %s\n' "$H122/no-such-gitdir" > "$H1/c-gitfile/.git"
# (c) a live linked worktree; (d) one git still lists, reduced by hand to the
# stray shape - everything in it removed, its .git file included.
git -C "$M1" worktree add -q --detach "$H1/c-live" main >/dev/null 2>&1
git -C "$M1" worktree add -q --detach "$H1/c-reduced" main >/dev/null 2>&1
find "$H1/c-reduced" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
mkdir -p "$H1/c-reduced/node_modules/a/b"
# (e) a link that resolves, to a target outside the folder.
printf 'x\n' > "$H122/targets/t.txt"
mkdir -p "$H1/c-goodlink/node_modules/a/b"
E_KIND="$(h_link_resolving "$H1/c-goodlink/node_modules/a/ok" "$H122/targets/t.txt")"
# (f) only top-level entry src, which the repository does not ignore.
mkdir -p "$H1/c-src/src/a/b"
# (g) a completely empty folder; (h) a regular file in the parent.
mkdir -p "$H1/c-empty"
printf 'x\n' > "$H1/c-plain"
# C-2 rule 6, where the host can make a directory unreadable (see the header).
RO=0
mkdir -p "$H122/ro-probe/x"; chmod 000 "$H122/ro-probe"
if ! find "$H122/ro-probe" >/dev/null 2>&1; then RO=1; fi
chmod 755 "$H122/ro-probe"; rmdir "$H122/ro-probe/x" "$H122/ro-probe"
if [ "$RO" = 1 ]; then
  mkdir -p "$H1/c-unreadable/node_modules/a/b"
  chmod 000 "$H1/c-unreadable/node_modules/a"
fi

assert_eq "fixture (a) c-file: differs from stray-shaped only by one regular file, three levels down (and holds (i))" \
  "nogit|unlisted|files=1|links=0|resolving=0|top=node_modules,s-inner|ignored=node_modules|nested=5|node_modules/a/b/f.txt" \
  "$(h_shape "$M1" "$H1/c-file")|$(cd "$H1/c-file" && find . -type f | awk '{ sub(/^\.\//, ""); print }')"
assert_eq "fixture (i) c-file/s-inner: stray-shaped, one level further down than the parent" \
  "nogit|unlisted|files=0|links=0|resolving=0|top=node_modules|ignored=node_modules|nested=2" "$(h_shape "$M1" "$H1/c-file/s-inner")"
assert_eq "fixture (b) c-gitfile: differs from stray-shaped only by a .git file (itself a regular file)" \
  "git|unlisted|files=1|links=0|resolving=0|top=.git,node_modules|ignored=node_modules|nested=2" "$(h_shape "$M1" "$H1/c-gitfile")"
assert_eq "fixture (b) c-gitdir: differs from stray-shaped only by an empty .git directory" \
  "git|unlisted|files=0|links=0|resolving=0|top=.git,node_modules|ignored=node_modules|nested=2" "$(h_shape "$M1" "$H1/c-gitdir")"
assert_eq "fixture (c) c-live: a live linked worktree, listed, merged, clean, unlocked and recent" \
  "listed|merged|clean|unlocked|recent" "$(h_shape "$M1" "$H1/c-live" | awk -F'|' '{ print $2 }')|$(facts "$M1" "$H1/c-live")"
assert_eq "fixture (d) c-reduced: stray-shaped in every fact but one - git still lists it" \
  "nogit|listed|files=0|links=0|resolving=0|top=node_modules|ignored=node_modules|nested=2" "$(h_shape "$M1" "$H1/c-reduced")"
assert_eq "fixture (e) c-goodlink: differs from stray-shaped only by its one link resolving, to a $E_KIND outside the folder" \
  "nogit|unlisted|files=0|links=1|resolving=1|top=node_modules|ignored=node_modules|nested=2|outside" \
  "$(h_shape "$M1" "$H1/c-goodlink")|$(h_link_where "$H1/c-goodlink/node_modules/a/ok" c-goodlink)"
assert_eq "fixture (f) c-src: differs from stray-shaped only by its top-level entry, src, which the repository does not ignore" \
  "nogit|unlisted|files=0|links=0|resolving=0|top=src|ignored=-|nested=2" "$(h_shape "$M1" "$H1/c-src")"
assert_eq "fixture (g) c-empty: a completely empty folder - nothing at all, so no ignored top-level directory" \
  "nogit|unlisted|files=0|links=0|resolving=0|top=-|ignored=-|nested=0" "$(h_shape "$M1" "$H1/c-empty")"
assert_eq "fixture (h) c-plain: a regular file in the parent, not a folder" \
  "file" "$([ -f "$H1/c-plain" ] && [ ! -d "$H1/c-plain" ] && printf file || printf other)"
if [ "$RO" = 1 ]; then
  assert_eq "fixture (rule 6) c-unreadable: stray-shaped as far as it can be read, and find cannot read all of it" \
    "nogit|unlisted|files=0|links=0|resolving=0|top=node_modules|ignored=node_modules|nested=1|unreadable" \
    "$(h_shape "$M1" "$H1/c-unreadable")|$(find "$H1/c-unreadable" >/dev/null 2>&1 && printf readable || printf unreadable)"
fi

out="$(T "$M1" "$M1")"
for pair in "c-file:(a) a folder holding one regular file" \
            "c-gitfile:(b) a folder with a .git file" \
            "c-gitdir:(b) a folder with a .git directory" \
            "c-live:(c) a live linked worktree" \
            "c-reduced:(d) a listed worktree reduced by hand to the stray shape" \
            "c-goodlink:(e) a folder holding a link that resolves" \
            "c-src:(f) a folder whose only top-level entry is src, not ignored" \
            "c-empty:(g) a completely empty folder" \
            "c-plain:(h) a regular file in the parent" \
            "c-file/s-inner:(i) a stray-shaped folder one level further down" \
            "main:the main checkout"; do
  n="${pair%%:*}"; what="${pair#*:}"
  assert_eq "HARNESS-122 AC-2 $what is never named on a STRAY line" 0 "$(h_stray_names "$out" "$P1/$n")"
done
if [ "$RO" = 1 ]; then
  assert_eq "HARNESS-122 AC-2 (C-2 rule 6) a folder find cannot read is never named on a STRAY line" 0 "$(h_stray_names "$out" "$P1/c-unreadable")"
fi
assert_eq "HARNESS-122 AC-2: AC-1's s-dirs still gets its STRAY pair" 1 "$(h_pairs_of "$out" "$P1/s-dirs")"
assert_eq "HARNESS-122 AC-2: AC-1's s-link still gets its STRAY pair" 1 "$(h_pairs_of "$out" "$P1/s-link")"
assert_eq "HARNESS-122 AC-2: and those are the only two STRAY lines, in any spelling" 2 "$(starts "$out" 'STRAY ')"
has_line "HARNESS-122 AC-2 (c): the live worktree gets the worktree line it gets today" "KEEP $(wtp "$M1" c-live)  recent" "$out"

# ===========================================================================
describe "HARNESS-122 AC-3: STRAY pairs follow every ORPHAN line and precede every DELETABLE line, and the census does not count them"

h_parent ac3
H3="$H122/ac3"; M3="$H3/main"
merged_branch "$M3" story/h3-done
git -C "$M3" push -q origin main >/dev/null 2>&1
git -C "$M3" worktree add -q --detach "$H3/h3-rm" main >/dev/null 2>&1
age "$H3/h3-rm" "$OLD"
mkdir -p "$M3/.claude/worktrees/o-h3"
G3="$(line_no "$(porc_paths "$M3")" 1)"; P3="${G3%/*}"

assert_eq "fixture h3-rm: its facts are merged|clean|unlocked|idle" "merged|clean|unlocked|idle" "$(facts "$M3" "$H3/h3-rm")"
assert_eq "fixture story/h3-done: merged, checked out nowhere, no origin copy" "merged|in|noremote" \
  "$(git -C "$M3" merge-base --is-ancestor story/h3-done origin/main 2>/dev/null && printf merged || printf unmerged)|$(case "$(git -C "$M3" worktree list --porcelain)" in *"branch refs/heads/story/h3-done"*) printf out ;; *) printf in ;; esac)|$(git -C "$M3" rev-parse -q --verify refs/remotes/origin/story/h3-done >/dev/null 2>&1 && printf remote || printf noremote)"
assert_eq "fixture o-h3: an empty folder under .claude/worktrees/ that git does not list" "0|unlisted" \
  "$(find "$M3/.claude/worktrees/o-h3" -mindepth 1 | awk 'END { print NR }')|$(h_shape "$M3" "$M3/.claude/worktrees/o-h3" | awk -F'|' '{ print $2 }')"

out="$(T "$M3" "$M3")"
CENSUS_BEFORE="$(awk 'END { print }' <<< "$out")"
assert_eq "HARNESS-122 AC-3: with the two folders absent, the census is 1 / 1 / 0 / 1" "$(census 1 1 0 1)" "$CENSUS_BEFORE"

# Z-dirs before a-link: LC_ALL=C order, which a locale-aware sort reverses.
h_strays "$H3" Z-dirs a-link
assert_eq "fixture h122/ac3: the parent holds the main checkout, the worktree and the two folders" \
  "Z-dirs,a-link,h3-rm,main" "$(h_ls "$H3")"
assert_eq "fixture Z-dirs: stray-shaped, directories only" "$STRAY_DIRS" "$(h_shape "$M3" "$H3/Z-dirs")"
assert_eq "fixture a-link: stray-shaped, with one dangling link" "$STRAY_LINK" "$(h_shape "$M3" "$H3/a-link")"

EXPECT_H3="REMOVABLE $(wtp "$M3" h3-rm)
ORPHAN $G3/.claude/worktrees/o-h3  empty
  remove it: $(remove_cmd "$G3/.claude/worktrees/o-h3")
$(h_pair "$P3/Z-dirs")
$(h_pair "$P3/a-link")
DELETABLE story/h3-done
$(census 1 1 0 1)"
out="$(T "$M3" "$M3")"; rc=$?
whole "HARNESS-122 AC-3: the whole report is the worktree line, the ORPHAN pair, the two STRAY pairs in LC_ALL=C order, the DELETABLE line, then the census" \
  "$EXPECT_H3" "$out"
assert_eq "HARNESS-122 AC-3/C-4: the census is the one printed with the two folders absent" "$CENSUS_BEFORE" "$(awk 'END { print }' <<< "$out")"
assert_eq "HARNESS-122 AC-3: and report mode exits 0" 0 "$rc"

# ===========================================================================
describe "HARNESS-122 AC-4: nothing is deleted, in report mode or with --apply"

h_parent ac4
H4="$H122/ac4"; M4="$H4/main"
h_strays "$H4" s-dirs s-link
G4="$(line_no "$(porc_paths "$M4")" 1)"; P4="${G4%/*}"
assert_eq "fixture s-dirs (ac4): stray-shaped, directories only" "$STRAY_DIRS" "$(h_shape "$M4" "$H4/s-dirs")"
assert_eq "fixture s-link (ac4): stray-shaped, with one dangling link" "$STRAY_LINK" "$(h_shape "$M4" "$H4/s-link")"

LS_DIRS="$(h_listing "$H4/s-dirs")"; LS_LINK="$(h_listing "$H4/s-link")"
EXPECT_H4="$(h_pair "$P4/s-dirs")
$(h_pair "$P4/s-link")
$(census 0 0 0 0)"
out="$(T "$M4" "$M4")"; rc_r=$?
out_a="$(T "$M4" "$M4" --apply)"; rc_a=$?
whole "HARNESS-122 AC-4: report mode prints the two STRAY pairs, then the census" "$EXPECT_H4" "$out"
whole "HARNESS-122 AC-4/C-5: --apply prints the same STRAY pairs and acts on neither" "$EXPECT_H4" "$out_a"
assert_eq "HARNESS-122 AC-4: every entry under each stray folder is still there after both runs, find listing identical" "same|same" \
  "$([ "$LS_DIRS" = "$(h_listing "$H4/s-dirs")" ] && printf same || printf changed)|$([ "$LS_LINK" = "$(h_listing "$H4/s-link")" ] && printf same || printf changed)"
assert_eq "HARNESS-122 AC-4/C-5: STRAY folders do not change the exit status: report 0, --apply 0" "0|0" "$rc_r|$rc_a"

# ===========================================================================
describe "HARNESS-122 AC-5: --help states the STRAY rule (Contract C-6)"

help="$(T "$WORK/z" "$WORK/z" --help)"
C6_1="then one STRAY line per folder beside the main checkout that holds no"
C6_2="regular file and no link that resolves, has no .git, is not a listed"
C6_3="worktree, and has a top-level directory this repository ignores, each"
C6_4="followed by the command to remove it (printed, never run),"
C6_5="A STRAY folder is reported and never removed, with or without --apply."
has_line "HARNESS-122 AC-5: --help has the whole line: $C6_1" "$C6_1" "$help"
has_line "HARNESS-122 AC-5: --help has the whole line: $C6_2" "$C6_2" "$help"
has_line "HARNESS-122 AC-5: --help has the whole line: $C6_3" "$C6_3" "$help"
has_line "HARNESS-122 AC-5: --help has the whole line: $C6_4" "$C6_4" "$help"
has_line "HARNESS-122 AC-5: --help has the whole line: $C6_5" "$C6_5" "$help"
assert_eq "HARNESS-122 AC-5: the four lines of the STRAY rule are consecutive, in C-6's order" 1 \
  "$(awk 'BEGIN { for (i = 2; i <= 5; i++) { w[i - 1] = ARGV[i]; ARGV[i] = "" } }
          { l[NR] = $0 } END { for (i = 1; i + 3 <= NR; i++) if (l[i] == w[1] && l[i+1] == w[2] && l[i+2] == w[3] && l[i+3] == w[4]) c++; print c + 0 }' \
        - "$C6_1" "$C6_2" "$C6_3" "$C6_4" <<< "$help")"

summary "tidy"
