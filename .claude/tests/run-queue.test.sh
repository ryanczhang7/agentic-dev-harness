#!/usr/bin/env bash
# Tests for the machine-wide run queue (HARNESS-108, HARNESS-111): a run that
# queues - a FULL scripts/gates.sh or scripts/selftest.sh run, or any
# scripts/selftest.sh --changed run that gets as far as the run lock - waits
# for any other such run anywhere on the machine - another tree, another
# session - instead of running beside it, and says that it is queued and
# behind what. One lock file per user per machine,
# ${HARNESS_RUN_QUEUE_DIR:-$HOME/.cache/agentic-harness}/run-queue.lock, joined
# inside scripts/run-lock.sh (HARNESS-108 Contract C-1..C-7). Which commands
# queue is run_lock_queues (HARNESS-111 C-2); run_lock_full still says which
# are full, and a --changed run is not one.
#
# The measurement behind it: two refresh self-tests beside another session's
# runs took over three hours; the same self-test takes three to four minutes
# on CI, where it has the machine to itself.
#
# THE QUEUE IS NEVER THE HOST'S. _lib.sh exports HARNESS_RUN_QUEUE=off (AC-7);
# this suite turns the queue on PER CALL, in rq_run's subshell, always with
# HARNESS_RUN_QUEUE_DIR pointing into its own temp directory. The one case that
# unsets HARNESS_RUN_QUEUE_DIR (AC-9) unsets HOME with it, so no case can reach
# $HOME/.cache. Under the real selftest.sh this suite may inherit
# HARNESS_RUN_QUEUE_LOCK / _PID naming the host's queue; they name a different
# path from every queue here, no case depends on their absence, and the cases
# that are about them (AC-6) set them explicitly.
#
# CONCURRENCY IS OBSERVED BY THE RUNS THEMSELVES, NEVER BY THE CLOCK (C-8).
# Every gate command and every fixture suite is m/work.sh. As it starts it
# makes $SH/run.<tree> and records which OTHER trees' run.<tree> exist
# (m/k/overlap-start) and which trees have finished (m/k/done-before); as it
# ends it records the others again (m/k/overlap-end), then marks itself done.
# Because each run makes its own marker BEFORE looking for the others, two
# runs whose work overlaps at all are seen by at least one of them, whatever
# the timing. A HOLDER is a run whose work waits for m/k/release, which the
# test writes. "Has not started" is asserted only after the waiter's queued
# line (or its own start) has appeared, plus at least two poll intervals -
# never after a bare sleep. Every wait is bounded; a defect that waits for
# ever costs the bound and fails, it does not hang the suite.
#
# NEEDLES. C-3's lines are compared WHOLE (grep -cxF), because every one of
# them begins `run-queue: ` and a floating prefix would be satisfied by the
# wrong one. The two lines that carry a duration are matched as a fixed prefix
# plus an anchored span pattern. Exit statuses are exact: 0, 2, 143.
#
# RED: scripts/run-queue.sh and run_lock_full do not exist. The direct cases
# test for them first and fail ONE assertion per row in the if and the else
# alike, so the executed count is the same in RED and GREEN. The cases through
# gates.sh and selftest.sh fail for the right reason on their own: nothing
# queues, so B runs beside A. AC-10's "starts at once" assertions and AC-7's
# queue-off control pass on arrival in RED; DV-3 earns the first at GATES.
#
# HARNESS-111 (--changed). Three more trees, X, Y and Z, each a git checkout
# with a `main` and a story branch, so that `selftest.sh --changed` selects
# what the case says: X every suite (an unmapped x.conf), Y a proper subset
# (m.conf, mentioned by `work` only), Z no suite (a source-only commit). Every
# --changed case asserts its header line first, so a fixture whose selection
# drifted fails as that, not as a queue defect. In RED run_lock_queues does
# not exist and --changed never queues: its table rows fail one assertion
# each in the if and the else alike, and the cases through selftest.sh fail
# on their own - B runs beside A. AC-3 (nested --changed) and AC-4 (no suite)
# pass on arrival; DV-3 and DV-4 earn them at GATES.
#
# HARNESS-120 (asking). scripts/run-status.sh answers, for the tree whose copy
# is run, idle / running / queued and what holds the queue; a run waiting in
# the queue says so in <root>/.claude/state/run.queued. Every answer is
# compared line by line, whole, against Contract C-2's text; stdout and
# stderr apart. "Queued" is believed only for a live waiter: the planted cases
# (a marker with a dead pid, with a pid the run.lock does not record, with no
# run.lock) must never read as queued, and a --fast run or a queue-off run
# beside the holder must read as running (C-8's two controls). In RED
# run-status.sh does not exist: every assertion about an answer tests for the
# file first and fails ONE assertion in the if and the else alike, so the
# executed count is the same in RED and GREEN. The marker assertions fail on
# their own: nothing writes one. An assertion that the marker is ABSENT counts
# only once a marker has been seen (MARKER_SEEN, AC-1), so it cannot pass on a
# tree where nothing writes one. AC-6's text pins read the real CLAUDE.md,
# command, agent and script files, each needle inside the region C-5 names.
#
# fixture-only: .claude/tests/floors.conf
#   writes its fixtures' own floors files; never reads the real one.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

W="$(mktemp -d 2>/dev/null || mktemp -d -t runqueue.XXXXXX)"
W="$(cd "$W" && pwd)"
SH="$W/sh"                 # the shared run markers every tree's work.sh writes
Q="$W/q"                   # the queue directory every queue-on run is given
QL="$Q/run-queue.lock"     # its lock
BG=""                      # every background pid this suite starts; reaped on EXIT
POLL=1                     # HARNESS_RUN_QUEUE_POLL for every queue-on run
A=""; B=""; C=""           # the three trees, set below
X=""; Y=""; Z=""           # the three --changed trees (HARNESS-111), set below

# release_all   Lets every held work.sh in every tree finish.
release_all() {
  local t
  for t in "$A" "$B" "$C" "$X" "$Y" "$Z"; do [ -n "$t" ] && [ -d "$t/m/k" ] && touch "$t/m/k/release"; done
  return 0
}

cleanup() {
  local p t f
  release_all
  for t in "$A" "$B" "$C" "$X" "$Y" "$Z"; do
    [ -n "$t" ] || continue
    for f in "$t"/m/k/n*.pid; do [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null; done
  done
  for p in $BG; do kill "$p" 2>/dev/null; done
  for p in $BG; do wait "$p" 2>/dev/null; done
  rm -rf "$A" "$B" "$C" "$X" "$Y" "$Z" "$W"
}
trap cleanup EXIT

# --- the fixture -------------------------------------------------------------

# fixture_setup <tree> <name>   m/work.sh is the one piece of work every run
# does: the gate `unit`, and the fixture's one suite `work`. `lint` is a
# second gate so that `--skip lint` still runs `unit`. The fixture's
# .claude/tests holds the REAL _lib.sh, work.test.sh and a floors.conf naming
# it, so the fixture's full selftest.sh passes its own floors audit and exits 0.
fixture_setup() {
  local t="$1" n="$2"
  mkdir -p "$t/m/k" "$t/.claude/tests" "$t/.claude/state"
  cp "$REPO_ROOT/.claude/tests/_lib.sh" "$t/.claude/tests/_lib.sh"
  { printf '#!/usr/bin/env bash\n'
    printf "SH='%s'\nN='%s'\nK='%s'\n" "$SH" "$n" "$t/m/k"
    cat <<'WORK'
others() {
  local d o=""
  for d in "$SH"/run.*; do
    [ -d "$d" ] || continue
    [ "$d" = "$SH/run.$N" ] || o="$o ${d##*/run.}"
  done
  printf '%s\n' "${o# }"
}
mkdir "$SH/run.$N" 2>/dev/null
others > "$K/overlap-start"
d=""
for f in "$SH"/done.*; do [ -e "$f" ] && d="$d ${f##*/done.}"; done
printf '%s\n' "${d# }" > "$K/done-before"
if [ -n "${HARNESS_RUN_QUEUE_DIR-}" ]; then
  cp "$HARNESS_RUN_QUEUE_DIR/run-queue.lock" "$K/qlock" 2>/dev/null
fi
touch "$K/started"
if [ -f "$K/hold" ]; then
  i=0
  while [ ! -f "$K/release" ] && [ "$i" -lt 600 ]; do sleep 0.2; i=$((i+1)); done
fi
others > "$K/overlap-end"
touch "$SH/done.$N"
rmdir "$SH/run.$N" 2>/dev/null
touch "$K/finished"
printf 'Tests  1 passed (1)\n'
WORK
  } > "$t/m/work.sh"
  printf '#!/usr/bin/env bash\nprintf '"'"'Tests  1 passed (1)\\n'"'"'\n' > "$t/m/lint.sh"

  cat > "$t/.claude/tests/work.test.sh" <<'SUITE'
#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
bash "$REPO_ROOT/m/work.sh" > /dev/null
assert_eq "work" x x
summary "work"
SUITE
  printf 'floor | work | 1\n' > "$t/.claude/tests/floors.conf"
  conf_work "$t"
}

# conf_work <tree>   Two required gates: unit (m/work.sh) and lint.
conf_work() {
  write_conf "$1" <<'EOF'
gate     | unit | required | . | bash m/work.sh
evidence | unit | Tests +[1-9][0-9]* passed
gate     | lint | required | . | bash m/lint.sh
evidence | lint | Tests +[1-9][0-9]* passed
EOF
}

A="$(make_project_fixture)"; A="$(cd "$A" && pwd)"
B="$(make_project_fixture)"; B="$(cd "$B" && pwd)"
C="$(make_project_fixture)"; C="$(cd "$C" && pwd)"
fixture_setup "$A" A
fixture_setup "$B" B
fixture_setup "$C" C

# nest.sh, A's gate command for AC-6: a full selftest.sh in A, then one in B,
# each in the background with its pid recorded (so cleanup can reach an inner
# run that waits on its own ancestor), each run's status and the queue lock as
# it stands after each run recorded.
{ printf '#!/usr/bin/env bash\n'
  printf "K='%s'\nTB='%s'\n" "$A/m/k" "$B"
  cat <<'NEST'
bash scripts/selftest.sh > "$K/n1.out" 2> "$K/n1.err" < /dev/null &
echo "$!" > "$K/n1.pid"; wait "$!"; echo "$?" > "$K/n1.rc"
cp "$HARNESS_RUN_QUEUE_DIR/run-queue.lock" "$K/n1.qlock" 2>/dev/null
( cd "$TB" && exec bash scripts/selftest.sh ) > "$K/n2.out" 2> "$K/n2.err" < /dev/null &
echo "$!" > "$K/n2.pid"; wait "$!"; echo "$?" > "$K/n2.rc"
cp "$HARNESS_RUN_QUEUE_DIR/run-queue.lock" "$K/n2.qlock" 2>/dev/null
printf 'Tests  1 passed (1)\n'
NEST
} > "$A/m/nest.sh"

# --- the --changed trees (HARNESS-111, C-5) ----------------------------------
# changed_setup <tree> <name> <change>   fixture_setup, plus what --changed
# needs: two suites, `work` (m/work.sh, and its source mentions
# .claude/harness/m.conf) and `other` (mentions nothing); one gate, unit, that
# is m/work.sh unless m/k/nest exists, then m/nest.sh; m/k/ and .claude/state/
# ignored; all of it committed on `main`; then a story branch carrying one
# committed change:
#   every   .claude/harness/x.conf, mapped by no rule  -> every suite
#   subset  .claude/harness/m.conf, mentioned by work  -> work only
#   none    src/app.ts, a source path                  -> no suite
# The work tree is clean afterwards, so the selection cannot drift as runs
# write their markers and their state.
cgit() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }
changed_setup() {
  local t="$1" n="$2"
  fixture_setup "$t" "$n"
  cat > "$t/.claude/tests/work.test.sh" <<'SUITE'
#!/usr/bin/env bash
# reads .claude/harness/m.conf
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
bash "$REPO_ROOT/m/work.sh" > /dev/null
assert_eq "work" x x
summary "work"
SUITE
  cat > "$t/.claude/tests/other.test.sh" <<'SUITE'
#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
assert_eq "other" x x
summary "other"
SUITE
  printf 'floor | other | 1\nfloor | work  | 1\n' > "$t/.claude/tests/floors.conf"
  printf '#!/usr/bin/env bash\nif [ -f m/k/nest ]; then exec bash m/nest.sh; fi\nexec bash m/work.sh\n' > "$t/m/gate.sh"
  write_conf "$t" <<'EOF'
gate     | unit | required | . | bash m/gate.sh
evidence | unit | Tests +[1-9][0-9]* passed
gate     | lint | required | . | bash m/lint.sh
evidence | lint | Tests +[1-9][0-9]* passed
EOF
  printf '.claude/state/\nm/k/\n' >> "$t/.gitignore"
  cgit "$t" branch -M main >/dev/null 2>&1
  cgit "$t" add -A >/dev/null 2>&1
  cgit "$t" commit -qm "two suites" >/dev/null 2>&1
  cgit "$t" checkout -q -b story/T-1-fixture >/dev/null 2>&1
  case "$3" in
    every)  printf 'x\n' > "$t/.claude/harness/x.conf" ;;
    subset) printf 'm\n' > "$t/.claude/harness/m.conf" ;;
    none)   mkdir -p "$t/src"; printf 'export const a = 1\n' > "$t/src/app.ts" ;;
  esac
  cgit "$t" add -A >/dev/null 2>&1
  cgit "$t" commit -qm "the change" >/dev/null 2>&1
}
X="$(make_project_fixture)"; X="$(cd "$X" && pwd)"
Y="$(make_project_fixture)"; Y="$(cd "$Y" && pwd)"
Z="$(make_project_fixture)"; Z="$(cd "$Z" && pwd)"

# X's m/nest.sh, X's gate command for HARNESS-111 AC-3 once m/k/nest exists:
# selftest.sh --changed in X (the holder's own tree), then in Y, each in the
# background with its pid recorded, each run's status and the queue lock as it
# stands after each run recorded - the shape of A's nest.sh above. Written
# before changed_setup, so that it is committed on main with the rest.
mkdir -p "$X/m"
{ printf '#!/usr/bin/env bash\n'
  printf "K='%s'\nTB='%s'\n" "$X/m/k" "$Y"
  cat <<'NEST'
bash scripts/selftest.sh --changed > "$K/n1.out" 2> "$K/n1.err" < /dev/null &
echo "$!" > "$K/n1.pid"; wait "$!"; echo "$?" > "$K/n1.rc"
cp "$HARNESS_RUN_QUEUE_DIR/run-queue.lock" "$K/n1.qlock" 2>/dev/null
( cd "$TB" && exec bash scripts/selftest.sh --changed ) > "$K/n2.out" 2> "$K/n2.err" < /dev/null &
echo "$!" > "$K/n2.pid"; wait "$!"; echo "$?" > "$K/n2.rc"
cp "$HARNESS_RUN_QUEUE_DIR/run-queue.lock" "$K/n2.qlock" 2>/dev/null
printf 'Tests  1 passed (1)\n'
NEST
} > "$X/m/nest.sh"

changed_setup "$X" X every
changed_setup "$Y" Y subset
changed_setup "$Z" Z none

# The header line each selection prints on stdout before the run lock: the
# precondition every --changed case asserts first.
HDR_X="selftest: --changed — every suite: .claude/harness/x.conf is mapped by no rule; defaulting to every suite"
HDR_Y="selftest: --changed — 1 of 2 suite(s) selected: work"
HDR_Z="selftest: --changed selected no suite — selftest-needed: skip — no harness path among 1 changed path(s) against main (merge-base $(git -C "$Z" rev-parse --short main 2>/dev/null)); CI runs the self-test on the PR"
CHG="scripts/selftest.sh --changed"

# --- instruments -------------------------------------------------------------

present()  { if [ -e "$1" ]; then printf present; else printf absent; fi; }
is_alive() { if kill -0 "$1" 2>/dev/null; then printf alive; else printf gone; fi; }
readf()    { cat "$1" 2>/dev/null; }

# count_line <exact line> <file>   Whole-line occurrences.
count_line() { grep -cxF -- "$1" "$2" 2>/dev/null; }
# count_re <ere> <file>
count_re()   { awk -v re="$1" '$0 ~ re { n++ } END { print n + 0 }' "$2" 2>/dev/null; }
# count_span <fixed prefix> <ere for the rest> <file>   Lines that begin with
# the prefix verbatim and whose remainder matches the anchored pattern.
count_span() {
  awk -v p="$1" -v re="$2" 'index($0, p) == 1 && substr($0, length(p) + 1) ~ re { n++ } END { print n + 0 }' "$3" 2>/dev/null
}
# rq_lines <file>   The run-queue: lines of a file, in order.
rq_lines() { awk 'index($0, "run-queue:") == 1' "$1" 2>/dev/null; }
first_rq() { rq_lines "$1" | awk 'NR == 1'; }
last_rq()  { rq_lines "$1" | awk '{ l = $0 } END { print l }'; }
at_least() { if [ "$2" -ge "$1" ] 2>/dev/null; then printf yes; else printf 'no (%s)' "$2"; fi; }

# rec_field <record file> <key>   One TAB-separated field of a queue record.
rec_field() { awk -F'\t' -v k="$2" '$1 == k { print $2; exit }' "$1" 2>/dev/null; }
rec_keys()  { awk -F'\t' 'NF == 2 { printf "%s%s", s, $1; s = " " } NF != 2 { printf "%s<bad:%s>", s, $0; s = " " }' "$1" 2>/dev/null; }

# qsnap   Every file in the queue directory, name and exact bytes; empty when
# the directory holds nothing.
qsnap() {
  local f
  [ -d "$Q" ] || { printf 'no-dir'; return 0; }
  for f in "$Q"/* "$Q"/.[!.]*; do
    [ -e "$f" ] || continue
    printf '%s:' "${f##*/}"; cat "$f"; printf '|'
  done
  return 0
}

# qlock   The queue lock's own exact bytes, or <no lock>. For comparing the
# lock while a waiter is alive: a waiter writes and removes its temporary
# record run-queue.lock.<pid> on every poll, so qsnap - the whole directory -
# would race it (R-1). Where no waiter is alive, qsnap is the stronger check.
qlock() {
  if [ -f "$QL" ]; then cat "$QL"; printf '|eof'; else printf '<no lock>'; fi
}

# qplant <pid-or-empty> <started> <command> <root> [dir]   A queue lock
# written by hand. An empty pid writes no pid line.
qplant() {
  local d="${5:-$Q}"
  mkdir -p "$d"
  { [ -n "$1" ] && printf 'pid\t%s\n' "$1"
    printf 'started\t%s\ncommand\t%s\nroot\t%s\n' "$2" "$3" "$4"; } > "$d/run-queue.lock"
}

# leftovers <tree>   run.lock and run.lock.* files in the tree.
leftovers() {
  local n=0 f
  for f in "$1"/.claude/state/run.lock "$1"/.claude/state/run.lock.*; do
    [ -e "$f" ] && n=$((n+1))
  done
  printf '%s' "$n"
}

# wait_until <seconds> <cmd> [args]   Polls every 0.2 s. 0 once cmd succeeds.
wait_until() {
  local n=$(( $1 * 5 )) i=0; shift
  while ! "$@"; do
    i=$((i+1)); [ "$i" -ge "$n" ] && return 1
    sleep 0.2
  done
  return 0
}
is_started()        { [ -e "$1/m/k/started" ]; }
is_queued()         { [ "$(count_re '^run-queue: queued: ' "$1")" -gt 0 ]; }
started_or_queued() { is_started "$1" || is_queued "$2"; }

# wait_bounded <pid> <seconds>   Waits for a child of this shell. Sets WRC to
# its status and WTO to yes if it outlived the bound - in which case every
# holder is released and it is sent TERM, then KILL.
WRC=""; WTO=""
wait_bounded() {
  local i=0 n=$(( $2 * 5 ))
  while kill -0 "$1" 2>/dev/null && [ "$i" -lt "$n" ]; do sleep 0.2; i=$((i+1)); done
  if kill -0 "$1" 2>/dev/null; then
    WTO=yes
    release_all
    kill -TERM "$1" 2>/dev/null
    i=0
    while kill -0 "$1" 2>/dev/null && [ "$i" -lt 50 ]; do sleep 0.2; i=$((i+1)); done
    kill -KILL "$1" 2>/dev/null
  else
    WTO=no
  fi
  wait "$1" 2>/dev/null; WRC=$?
}

# The queue environment of the next rq_run. rq_defaults: queue on (empty
# HARNESS_RUN_QUEUE), this suite's $Q, nothing else set. RQ_PATH (HARNESS-112
# C-2), when set, is prepended to PATH in the run's subshell only - never in
# this suite's own shell, so every other removal here uses the real rm.
RQ_MODE=""; RQ_DIR=""; RQ_XLOCK=""; RQ_XPID=""; RQ_NOHOME=""; RQ_CI=""; RQ_PATH=""
rq_defaults() { RQ_MODE=""; RQ_DIR="$Q"; RQ_XLOCK=""; RQ_XPID=""; RQ_NOHOME=""; RQ_CI=""; RQ_PATH=""; }

# rq_run <var> <tree> <name> <script> [args...]   Starts `bash <script>` in the
# tree, in the background, with the queue environment above; stdout and stderr
# to $W/<name>.out and $W/<name>.err. `exec`, so <var> gets the script's own
# pid - the pid a queue record holds and the one a TERM must reach.
rq_run() {
  local __rv="$1" __rt="$2" __ro="$W/$3"; shift 3
  rm -f "$__ro.out" "$__ro.err"
  ( cd "$__rt" || exit 97
    if [ "$RQ_MODE" = "<unset>" ]; then unset HARNESS_RUN_QUEUE
    else HARNESS_RUN_QUEUE="$RQ_MODE"; export HARNESS_RUN_QUEUE; fi
    if [ "$RQ_DIR" = "<unset>" ]; then unset HARNESS_RUN_QUEUE_DIR
    else HARNESS_RUN_QUEUE_DIR="$RQ_DIR"; export HARNESS_RUN_QUEUE_DIR; fi
    HARNESS_RUN_QUEUE_POLL="$POLL"; HARNESS_RUN_QUEUE_HEARTBEAT=1
    export HARNESS_RUN_QUEUE_POLL HARNESS_RUN_QUEUE_HEARTBEAT
    if [ -n "$RQ_XLOCK" ]; then HARNESS_RUN_QUEUE_LOCK="$RQ_XLOCK"; export HARNESS_RUN_QUEUE_LOCK; fi
    if [ -n "$RQ_XPID" ]; then HARNESS_RUN_QUEUE_PID="$RQ_XPID"; export HARNESS_RUN_QUEUE_PID; fi
    if [ -n "$RQ_NOHOME" ]; then unset HOME; fi
    if [ -n "$RQ_CI" ]; then CI="$RQ_CI"; export CI; fi
    if [ -n "$RQ_PATH" ]; then PATH="$RQ_PATH:$PATH"; export PATH; fi
    exec bash "$@" ) > "$__ro.out" 2> "$__ro.err" < /dev/null &
  printf -v "$__rv" '%s' "$!"
  BG="$BG $!"
}

# hold_run <var> <tree> <name> <script> [args...]   rq_run, with the tree's
# work held on m/k/release. HOLDING is yes once the work reported itself started.
HOLDING=no
hold_run() {
  local __ht="$2"
  touch "$__ht/m/k/hold"
  rq_run "$@"
  if wait_until 60 is_started "$__ht"; then HOLDING=yes; else HOLDING=no; fi
  rm -f "$__ht/m/k/hold"
}

# new_case   Empty queue directory, no shared markers, every tree's markers
# and run lock gone, the default queue environment.
new_case() {
  local t
  rm -rf "$Q" "$SH"; mkdir -p "$Q" "$SH"
  for t in "$A" "$B" "$C" "$X" "$Y" "$Z"; do
    [ -n "$t" ] || continue
    rm -rf "$t/m/k"; mkdir -p "$t/m/k"
    rm -f "$t"/.claude/state/run.lock* "$t/.claude/state/run.queued"
  done
  rq_defaults
}

# C-3's lines. <self> is the waiting run's command string.
q1() { printf 'run-queue: queued: %s waits for another harness run on this machine to finish.' "$1"; }
q2() { printf 'run-queue:   behind pid %s, started %s, in %s: %s' "$1" "$2" "$3" "$4"; }   # pid started root command
q3() { printf 'run-queue: this is waiting, not hanging: it starts by itself when that run ends. If pid %s is not that run, delete %s and it starts.' "$1" "$2"; }
hb_prefix() { printf 'run-queue: still queued behind pid %s in %s: %s (waited ' "$1" "$2" "$3"; }
HB_RE='^[0-9]+m[0-5][0-9]s\)$'
start_prefix() { printf 'run-queue: starting %s after waiting ' "$1"; }
START_RE='^[0-9]+m[0-5][0-9]s\.$'
stale_line()  { printf 'run-queue: reclaimed a stale queue lock from pid %s (%s, in %s); that process is no longer running.' "$1" "$2" "$3"; }
unread_line() { printf 'run-queue: reclaimed an unreadable queue lock (no pid recorded in %s).' "$1"; }
cannot_line() { printf 'run-queue: cannot use %s; %s runs without the machine-wide queue.' "$1" "$2"; }
nohome_line() { printf 'run-queue: neither HARNESS_RUN_QUEUE_DIR nor HOME is set; %s runs without the machine-wide queue.' "$1"; }
missing_line(){ printf 'run-queue: scripts/run-queue.sh is missing; %s runs without the machine-wide queue.' "$1"; }
UTC_RE='^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$'

# Processes the suite owns: two live ones that are not harness runs, and one
# that has exited.
hold_until_killed LIVE1; BG="$BG $LIVE1"
hold_until_killed LIVE2; BG="$BG $LIVE2"
bash -c 'exit 0' & DEAD=$!; wait "$DEAD" 2>/dev/null
PLANT_STARTED="2026-01-02T03:04:05Z"

# The status each kind of full run has alone, with the queue off: what AC-1
# compares a queued run's status with. Measured, not assumed.
new_case; RQ_MODE=off
rq_run p "$A" solo-gates scripts/gates.sh;    wait_bounded "$p" 120; SOLO_GATES=$WRC
new_case; RQ_MODE=off
rq_run p "$B" solo-self scripts/selftest.sh;  wait_bounded "$p" 120; SOLO_SELF=$WRC

# ---------------------------------------------------------------------------
# pair_case <label> <holder script> <waiter script>   AC-1: A's full run holds
# the queue; B's full run is started; B must not start its work while A holds,
# and must run once A ends.
pair_case() {
  local lbl="$1" hs="$2" ws="$3" hp wp arc brc bto solo
  case "$ws" in gates.sh) solo="$SOLO_GATES" ;; *) solo="$SOLO_SELF" ;; esac
  new_case
  hold_run hp "$A" "$lbl-A" "scripts/$hs"
  assert_eq "$lbl: precondition: A's full $hs is in progress, held on its release file" yes "$HOLDING"
  cp "$QL" "$W/$lbl-A.rec" 2>/dev/null || : > "$W/$lbl-A.rec"
  rq_run wp "$B" "$lbl-B" "scripts/$ws"
  wait_until 60 started_or_queued "$B" "$W/$lbl-B.err"
  sleep 3.5   # at least two poll intervals after it queued, and AC-3's three seconds held
  assert_eq "$lbl: B's full $ws has not started its work while A holds the queue, over two poll intervals after it queued" \
    absent "$(present "$B/m/k/started")"
  assert_eq "$lbl: precondition: A is still running at that moment" alive "$(is_alive "$hp")"
  touch "$A/m/k/release"
  wait_bounded "$hp" 60; arc=$WRC
  wait_bounded "$wp" 60; brc=$WRC; bto=$WTO
  assert_eq "$lbl: A finishes with its own status" 0 "$arc"
  assert_eq "$lbl: once A ends, B gets through by itself, within the bound" no "$bto"
  assert_eq "$lbl: B's work runs to its end" present "$(present "$B/m/k/finished")"
  assert_eq "$lbl: B exits with the status the same run has alone, queue off ($solo)" "$solo" "$brc"
  assert_eq "$lbl: B's work records, as it starts, that A's had finished" "A" "$(readf "$B/m/k/done-before")"
  assert_eq "$lbl: B's work saw no other run in progress as it started" "" "$(readf "$B/m/k/overlap-start")"
  assert_eq "$lbl: A's work saw no other run in progress as it ended" "" "$(readf "$A/m/k/overlap-end")"
  assert_eq "$lbl: the queue directory holds nothing once both have ended" "" "$(qsnap)"
  PAIR_HP="$hp"
}

describe "AC-1  a full run in another tree waits for the full run that holds the queue, then runs"

pair_case ac1-gg gates.sh gates.sh;    GG_HP="$PAIR_HP"
pair_case ac1-gs gates.sh selftest.sh; GS_HP="$PAIR_HP"
pair_case ac1-sg selftest.sh gates.sh; SG_HP="$PAIR_HP"

# ---------------------------------------------------------------------------
describe "AC-3  the queued run says it is queued, behind what, and that it is waiting; on stderr"

E="$W/ac1-gg-B.err"
H_STARTED="$(rec_field "$W/ac1-gg-A.rec" started)"
assert_eq "AC-3: queued line 1 names the waiting run, exactly once" 1 "$(count_line "$(q1 scripts/gates.sh)" "$E")"
assert_eq "AC-3: queued line 2 names A's pid, start, tree root and command from A's record, exactly once" 1 \
  "$(count_line "$(q2 "$GG_HP" "$H_STARTED" "$A" scripts/gates.sh)" "$E")"
assert_eq "AC-3: queued line 3 says it is waiting and names the lock to delete, exactly once" 1 \
  "$(count_line "$(q3 "$GG_HP" "$QL")" "$E")"
assert_eq "AC-3: the first run-queue: line is the queued line, printed before it waits" \
  "$(q1 scripts/gates.sh)" "$(first_rq "$E")"
assert_eq "AC-3: with a heartbeat of 1 s and A held over 3 s, at least one still-queued line naming A" yes \
  "$(at_least 1 "$(count_span "$(hb_prefix "$GG_HP" "$A" scripts/gates.sh)" "$HB_RE" "$E")")"
assert_eq "AC-3: one starting line with the total wait" 1 \
  "$(count_span "$(start_prefix scripts/gates.sh)" "$START_RE" "$E")"
last_rq "$E" > "$W/ac3-last"
assert_eq "AC-3: and the starting line is the last run-queue: line" 1 \
  "$(count_span "$(start_prefix scripts/gates.sh)" "$START_RE" "$W/ac3-last")"
assert_eq "AC-3: no run-queue: line goes to stdout" 0 "$(count_re '^run-queue:' "$W/ac1-gg-B.out")"
assert_eq "AC-3: a queued selftest.sh names itself in its queued line" 1 \
  "$(count_line "$(q1 scripts/selftest.sh)" "$W/ac1-gs-B.err")"
assert_eq "AC-3: and a gates.sh queued behind a selftest.sh names A's command as scripts/selftest.sh" 1 \
  "$(count_line "$(q2 "$SG_HP" "$(rec_field "$W/ac1-sg-A.rec" started)" "$A" scripts/selftest.sh)" "$W/ac1-sg-B.err")"

# ---------------------------------------------------------------------------
describe "AC-2  two runs queued behind a holder both finish, and no two of the three ever run together"

new_case
hold_run hp "$A" ac2-A scripts/gates.sh
assert_eq "AC-2: precondition: A's full gates.sh holds, its work in progress" yes "$HOLDING"
rq_run bp "$B" ac2-B scripts/gates.sh
rq_run cp_ "$C" ac2-C scripts/gates.sh
wait_until 60 started_or_queued "$B" "$W/ac2-B.err"
wait_until 60 started_or_queued "$C" "$W/ac2-C.err"
sleep 2   # two poll intervals: both have attempted the queue at least twice
touch "$A/m/k/release"
wait_bounded "$hp" 60;  arc=$WRC
wait_bounded "$bp" 90;  brc=$WRC
wait_bounded "$cp_" 90; crc=$WRC
assert_eq "AC-2: A exits 0" 0 "$arc"
assert_eq "AC-2: B runs to completion and exits 0" 0 "$brc"
assert_eq "AC-2: C runs to completion and exits 0" 0 "$crc"
assert_eq "AC-2: B's work finished" present "$(present "$B/m/k/finished")"
assert_eq "AC-2: C's work finished" present "$(present "$C/m/k/finished")"
for t in A B C; do
  eval "tp=\$$t"
  assert_eq "AC-2: $t's work saw no other run in progress as it started" "" "$(readf "$tp/m/k/overlap-start")"
  assert_eq "AC-2: $t's work saw no other run in progress as it ended" "" "$(readf "$tp/m/k/overlap-end")"
done
assert_eq "AC-2: the queue directory holds nothing afterwards" "" "$(qsnap)"

# ---------------------------------------------------------------------------
describe "AC-4  an uncontended full run takes the queue silently, records itself, and leaves nothing"

# ac4_case <script> <command string>
ac4_case() {
  local s="$1" cmd="$2" p offrc onrc
  new_case; RQ_MODE=off
  rq_run p "$A" "ac4-$s-off" "scripts/$s"; wait_bounded "$p" 120; offrc=$WRC
  new_case
  rq_run p "$A" "ac4-$s-on" "scripts/$s"; wait_bounded "$p" 120; onrc=$WRC
  local R="$A/m/k/qlock"
  assert_eq "AC-4 $s: while its work ran, the queue lock existed" present "$(present "$R")"
  assert_eq "AC-4 $s: the lock records the run's pid" "$p" "$(rec_field "$R" pid)"
  assert_eq "AC-4 $s: the lock records when it started, UTC to the second" 1 \
    "$(rec_field "$R" started | awk -v re="$UTC_RE" '$0 ~ re { n++ } END { print n + 0 }')"
  assert_eq "AC-4 $s: the lock records the run's command" "$cmd" "$(rec_field "$R" command)"
  assert_eq "AC-4 $s: the lock records the run's tree root, absolute" "$A" "$(rec_field "$R" root)"
  assert_eq "AC-4 $s: the lock is four TAB-separated lines: pid, started, command, root" \
    "pid started command root" "$(rec_keys "$R")"
  assert_eq "AC-4 $s: it prints no run-queue: line on stdout or stderr" 0 \
    "$(cat "$W/ac4-$s-on.out" "$W/ac4-$s-on.err" | awk 'index($0, "run-queue:") == 1 { n++ } END { print n + 0 }')"
  if cmp -s "$W/ac4-$s-off.err" "$W/ac4-$s-on.err"; then
    _ok "AC-4 $s: its stderr is byte-for-byte the same run's with HARNESS_RUN_QUEUE=off"
  else
    _bad "AC-4 $s: its stderr is byte-for-byte the same run's with HARNESS_RUN_QUEUE=off" \
      "$(diff "$W/ac4-$s-off.err" "$W/ac4-$s-on.err" 2>&1 | awk 'NR <= 10')"
  fi
  assert_eq "AC-4 $s: it exits as the same run does with the queue off ($offrc)" "$offrc" "$onrc"
  assert_eq "AC-4 $s: afterwards the queue directory holds neither the lock nor a temporary record" "" "$(qsnap)"
}
ac4_case gates.sh scripts/gates.sh
ac4_case selftest.sh scripts/selftest.sh

# ---------------------------------------------------------------------------
describe "AC-5  a stale or unreadable queue lock is reclaimed; a live pid never is"

assert_eq "AC-5: precondition: the dead pid is not running" gone "$(is_alive "$DEAD")"

# reclaim_case <label> <pid-or-empty> <expected line>
reclaim_case() {
  local lbl="$1" p
  new_case
  qplant "$2" "$PLANT_STARTED" "scripts/selftest.sh ghost" "/ghost/tree"
  rq_run p "$B" "$lbl" scripts/gates.sh; wait_bounded "$p" 60
  assert_eq "$lbl: prints the reclaim line, exactly once" 1 "$(count_line "$3" "$W/$lbl.err")"
  assert_eq "$lbl: does not wait: no queued line" 0 "$(count_re '^run-queue: queued: ' "$W/$lbl.err")"
  assert_eq "$lbl: runs its work and exits 0" "0 present" "$WRC $(present "$B/m/k/finished")"
  assert_eq "$lbl: having taken the queue: its work saw a lock recording its own pid" "$p" "$(rec_field "$B/m/k/qlock" pid)"
  assert_eq "$lbl: and leaves the queue directory empty" "" "$(qsnap)"
}
reclaim_case ac5-stale "$DEAD" "$(stale_line "$DEAD" "scripts/selftest.sh ghost" /ghost/tree)"
reclaim_case ac5-nopid "" "$(unread_line "$QL")"
reclaim_case ac5-nonnumeric "not-a-pid" "$(unread_line "$QL")"

describe "AC-5  a lock whose pid is a live process that is not a harness run: wait, never reclaim"

new_case
sleep 600 & SP=$!; BG="$BG $SP"
assert_eq "AC-5 live: precondition: the plain sleep holding the pid is running" alive "$(is_alive "$SP")"
qplant "$SP" "$PLANT_STARTED" "scripts/selftest.sh ghost" "/ghost/tree"
before="$(qlock)"
rq_run p "$B" ac5-live scripts/gates.sh
wait_until 60 started_or_queued "$B" "$W/ac5-live.err"
sleep 2.5
assert_eq "AC-5 live: the run has not started its work, over two poll intervals after it queued" absent "$(present "$B/m/k/started")"
assert_eq "AC-5 live: it names the live pid as what it waits behind" 1 \
  "$(count_line "$(q2 "$SP" "$PLANT_STARTED" /ghost/tree "scripts/selftest.sh ghost")" "$W/ac5-live.err")"
assert_eq "AC-5 live: it prints no reclaim line while the pid lives" 0 "$(count_re '^run-queue: reclaimed' "$W/ac5-live.err")"
assert_eq "AC-5 live: and the lock is byte-identical: a live pid is never reclaimed" "$before" "$(qlock)"
kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null
wait_bounded "$p" 60
assert_eq "AC-5 live: once the pid has gone, the run reclaims, runs and exits 0" "0 present" "$WRC $(present "$B/m/k/finished")"
assert_eq "AC-5 live: with the stale line naming that pid, exactly once" 1 \
  "$(count_line "$(stale_line "$SP" "scripts/selftest.sh ghost" /ghost/tree)" "$W/ac5-live.err")"
assert_eq "AC-5 live: and one starting line, since it had printed the queued lines" 1 \
  "$(count_span "$(start_prefix scripts/gates.sh)" "$START_RE" "$W/ac5-live.err")"
assert_eq "AC-5 live: the queue directory is empty afterwards" "" "$(qsnap)"

# ---------------------------------------------------------------------------
describe "AC-6  full runs nested under the holder, in its own tree and another, pass through"

new_case
write_conf "$A" <<'EOF'
gate     | unit | required | . | bash m/nest.sh
evidence | unit | Tests +[1-9][0-9]* passed
gate     | lint | required | . | bash m/lint.sh
evidence | lint | Tests +[1-9][0-9]* passed
EOF
rq_run op "$A" ac6-outer scripts/gates.sh; wait_bounded "$op" 120
orc=$WRC; oto=$WTO
for f in "$A"/m/k/n*.pid; do [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null; done
conf_work "$A"
assert_eq "AC-6: the whole arrangement completes within the bound: it does not wait on itself" no "$oto"
assert_eq "AC-6: the outer full gates.sh finishes with its own status" 0 "$orc"
assert_eq "AC-6: the inner full selftest.sh in A (the holder's tree) exits 0" 0 "$(readf "$A/m/k/n1.rc")"
assert_eq "AC-6: the inner full selftest.sh in B (another tree) exits 0, its suite run" "0 present" \
  "$(readf "$A/m/k/n2.rc") $(present "$B/m/k/finished")"
assert_eq "AC-6: neither inner run prints a run-queue: line" 0 \
  "$(cat "$A/m/k/n1.out" "$A/m/k/n1.err" "$A/m/k/n2.out" "$A/m/k/n2.err" 2>/dev/null | awk 'index($0, "run-queue:") == 1 { n++ } END { print n + 0 }')"
assert_eq "AC-6: after the inner run in A has ended, the queue lock still records the outer run's pid" "$op" \
  "$(rec_field "$A/m/k/n1.qlock" pid)"
assert_eq "AC-6: after the inner run in B has ended, the queue lock still records the outer run's pid" "$op" \
  "$(rec_field "$A/m/k/n2.qlock" pid)"
assert_eq "AC-6: and once the outer run has ended the queue directory is empty" "" "$(qsnap)"

describe "AC-6  the inherited variables are not a bypass"

assert_eq "AC-6: precondition: both live holders are alive" "alive alive" "$(is_alive "$LIVE1") $(is_alive "$LIVE2")"
# bypass_case <label> <lock var> <pid var>
bypass_case() {
  local lbl="$1" p before
  new_case
  qplant "$LIVE1" "$PLANT_STARTED" "scripts/gates.sh" "$A"
  before="$(qlock)"
  RQ_XLOCK="$2"; RQ_XPID="$3"
  rq_run p "$B" "$lbl" scripts/gates.sh
  wait_until 60 started_or_queued "$B" "$W/$lbl.err"
  sleep 2.5
  assert_eq "$lbl: B queues behind the live holder" 1 "$(count_line "$(q1 scripts/gates.sh)" "$W/$lbl.err")"
  assert_eq "$lbl: B has not started its work, over two poll intervals after it queued" absent "$(present "$B/m/k/started")"
  assert_eq "$lbl: the holder's lock is byte-identical" "$before" "$(qlock)"
  kill -TERM "$p" 2>/dev/null; wait_bounded "$p" 15
}
mkdir -p "$W/q-other"
qplant "$LIVE1" "$PLANT_STARTED" "scripts/gates.sh" "$A" "$W/q-other"
bypass_case ac6-wrong-pid "$QL" "$LIVE2"
bypass_case ac6-wrong-path "$W/q-other/run-queue.lock" "$LIVE1"

# ---------------------------------------------------------------------------
describe "AC-7 / AC-10  beside a held queue: HARNESS_RUN_QUEUE=off and every run that does not queue starts at once"

new_case
hold_run hp "$A" ac10-A scripts/gates.sh
assert_eq "precondition: A's full gates.sh holds the queue, its work in progress" yes "$HOLDING"

# beside_case <label> <script> [args...]   B started while A holds; it must
# start its work at once, say nothing and leave the queue directory alone.
beside_case() {
  local lbl="$1" p before; shift
  rm -rf "$B/m/k"; mkdir -p "$B/m/k"; rm -f "$B"/.claude/state/run.lock*
  before="$(qsnap)"
  rq_run p "$B" "$lbl" "$@"
  wait_until 60 started_or_queued "$B" "$W/$lbl.err"
  assert_eq "$lbl: starts its work at once, while A holds" present "$(present "$B/m/k/started")"
  assert_eq "$lbl: precondition: A is still running then" alive "$(is_alive "$hp")"
  if is_started "$B"; then wait_bounded "$p" 60; else kill -TERM "$p" 2>/dev/null; wait_bounded "$p" 15; fi
  assert_eq "$lbl: exits 0" 0 "$WRC"
  assert_eq "$lbl: prints no run-queue: line" 0 \
    "$(cat "$W/$lbl.out" "$W/$lbl.err" | awk 'index($0, "run-queue:") == 1 { n++ } END { print n + 0 }')"
  assert_eq "$lbl: creates, changes and removes nothing in the queue directory" "$before" "$(qsnap)"
}

RQ_MODE=off
beside_case "AC-7 full gates.sh, HARNESS_RUN_QUEUE=off" scripts/gates.sh
assert_eq "AC-7 control: B's work ran beside A's - the arrangement can see two runs at once" "A" \
  "$(readf "$B/m/k/overlap-start")"
RQ_MODE=""
beside_case "AC-10 gates.sh --fast"      scripts/gates.sh --fast
beside_case "AC-10 gates.sh --gate unit" scripts/gates.sh --gate unit
beside_case "AC-10 gates.sh --skip lint" scripts/gates.sh --skip lint
beside_case "AC-10 gates.sh --required"  scripts/gates.sh --required
beside_case "AC-10 selftest.sh work"     scripts/selftest.sh work

# The run lock is unchanged: a non-full run in the tree A holds is refused.
rq_run p "$A" ac10-same scripts/gates.sh --fast; wait_bounded "$p" 60
assert_eq "AC-10: a non-full run in the tree A's full run holds is refused with exit 2" 2 "$WRC"
assert_eq "AC-10: by the run lock, as today" 1 \
  "$(count_line "run-lock: refusing to start scripts/gates.sh --fast: another harness run holds this worktree's lock." "$W/ac10-same.err")"

touch "$A/m/k/release"; wait_bounded "$hp" 60
assert_eq "AC-10: A then finishes, exit 0" 0 "$WRC"

describe "AC-10  a run in progress that does not queue is not waited for: a full run takes the queue at once"

new_case
hold_run bp "$B" ac10-B scripts/gates.sh --gate unit
assert_eq "precondition: B's gates.sh --gate unit is in progress" yes "$HOLDING"
assert_eq "AC-10: B's non-full run has written nothing in the queue directory" "" "$(qsnap)"
rq_run ap "$A" ac10-full scripts/gates.sh
wait_until 60 started_or_queued "$A" "$W/ac10-full.err"
assert_eq "AC-10: A's full run starts its work at once, beside B's" "present B" \
  "$(present "$A/m/k/started") $(readf "$A/m/k/overlap-start")"
assert_eq "AC-10: and has taken the queue: its work saw a lock recording its pid" "$ap" "$(rec_field "$A/m/k/qlock" pid)"
touch "$B/m/k/release"
wait_bounded "$bp" 60; brc=$WRC
wait_bounded "$ap" 60; arc=$WRC
assert_eq "AC-10: both exit 0" "0 0" "$brc $arc"
assert_eq "AC-10: the queue directory is empty afterwards" "" "$(qsnap)"

describe "AC-10  run_lock_full answers as C-5's table says"

# rows: <0 full | 1 not full>|<command string>
FULL_ROWS='0|scripts/gates.sh
0|scripts/gates.sh --story T-1
0|scripts/selftest.sh
1|scripts/gates.sh --fast
1|scripts/gates.sh --gate unit
1|scripts/gates.sh --skip unit
1|scripts/gates.sh --required
1|scripts/gates.sh --story T-1 --fast
1|scripts/gates.sh --list
1|scripts/gates.sh --audit
1|scripts/selftest.sh run-queue
1|scripts/selftest.sh run-queue run-lock
1|scripts/selftest.sh --changed
1|scripts/selftest.sh --changed origin/main
1|scripts/selftest-needed.sh --suites
1|scripts/check-boundaries.sh
1|scripts/ci-local.sh
1|scripts/attest.sh -- bash scripts/gates.sh
1|'
HAVE_FULL="$( ( . "$REPO_ROOT/scripts/run-lock.sh" && type run_lock_full >/dev/null 2>&1 ) && printf yes || printf no)"
while IFS='|' read -r want cmd; do
  [ -n "$want" ] || continue
  if [ "$want" = 0 ]; then word=full; else word="not full"; fi
  if [ "$HAVE_FULL" = yes ]; then
    got="$( . "$REPO_ROOT/scripts/run-lock.sh"; set -f; run_lock_full "$cmd"; printf '%s' "$?")"
    assert_eq "run_lock_full '$cmd' is $word" "$want" "$got"
  else
    _bad "run_lock_full '$cmd' is $word" "scripts/run-lock.sh defines no run_lock_full"
  fi
done <<EOF
$FULL_ROWS
EOF

# ---------------------------------------------------------------------------
describe "AC-7  any value but off, and CI=true on its own, leave the queue on"

# value_case <label> <RQ_MODE> <RQ_CI>
value_case() {
  local lbl="$1" p
  new_case
  qplant "$LIVE1" "$PLANT_STARTED" "scripts/gates.sh" "$A"
  RQ_MODE="$2"; RQ_CI="$3"
  rq_run p "$B" "$lbl" scripts/gates.sh
  wait_until 60 started_or_queued "$B" "$W/$lbl.err"
  assert_eq "$lbl: the run queues behind the live holder" 1 "$(count_line "$(q1 scripts/gates.sh)" "$W/$lbl.err")"
  assert_eq "$lbl: and has not started its work" absent "$(present "$B/m/k/started")"
  kill -TERM "$p" 2>/dev/null; wait_bounded "$p" 15
}
value_case "AC-7 HARNESS_RUN_QUEUE unset"           "<unset>" ""
value_case "AC-7 HARNESS_RUN_QUEUE=OFF"             "OFF"     ""
value_case "AC-7 HARNESS_RUN_QUEUE=no"              "no"      ""
value_case "AC-7 CI=true, HARNESS_RUN_QUEUE unset"  "<unset>" "true"

describe "AC-7  _lib.sh exports HARNESS_RUN_QUEUE=off to every suite"

assert_eq "AC-7: sourcing _lib.sh with HARNESS_RUN_QUEUE unset leaves it off" off \
  "$(env -u HARNESS_RUN_QUEUE bash -c '. "$1" >/dev/null 2>&1; printf "%s" "${HARNESS_RUN_QUEUE-<unset>}"' _ "$TESTS_DIR/_lib.sh")"
assert_eq "AC-7: unconditionally: with HARNESS_RUN_QUEUE=on in the environment it is still off" off \
  "$(HARNESS_RUN_QUEUE=on bash -c '. "$1" >/dev/null 2>&1; printf "%s" "${HARNESS_RUN_QUEUE-<unset>}"' _ "$TESTS_DIR/_lib.sh")"
assert_eq "AC-7: and exported: a process the suite starts sees off" off \
  "$(env -u HARNESS_RUN_QUEUE bash -c '. "$1" >/dev/null 2>&1; bash -c "printf %s \"\${HARNESS_RUN_QUEUE-<unset>}\""' _ "$TESTS_DIR/_lib.sh")"

# ---------------------------------------------------------------------------
describe "AC-8  TERM: a waiter exits 143 having run nothing; a holder's exit lets the next run in"

# term_waiter <label> <script>
term_waiter() {
  local lbl="$1" s="$2" p before
  new_case
  qplant "$LIVE1" "$PLANT_STARTED" "scripts/gates.sh" "$A"
  before="$(qsnap)"
  rq_run p "$B" "$lbl" "scripts/$s"
  wait_until 60 started_or_queued "$B" "$W/$lbl.err"
  assert_eq "$lbl: precondition: the run is queued" 1 "$(count_line "$(q1 "scripts/$s")" "$W/$lbl.err")"
  kill -TERM "$p" 2>/dev/null
  wait_bounded "$p" 10
  assert_eq "$lbl: sent TERM while queued, it exits within a few poll intervals" no "$WTO"
  assert_eq "$lbl: with status 143" 143 "$WRC"
  assert_eq "$lbl: having run nothing" absent "$(present "$B/m/k/started")"
  assert_eq "$lbl: the queue directory holds only the holder's lock, unchanged" "$before" "$(qsnap)"
  assert_eq "$lbl: and the waiter's tree holds no run.lock" 0 "$(leftovers "$B")"
}
term_waiter "AC-8 gates.sh waiter" gates.sh
term_waiter "AC-8 selftest.sh waiter" selftest.sh

new_case
hold_run hp "$A" ac8-A scripts/gates.sh
assert_eq "AC-8 holder: precondition: A's full gates.sh holds" yes "$HOLDING"
rq_run bp "$B" ac8-B scripts/gates.sh
wait_until 60 started_or_queued "$B" "$W/ac8-B.err"
kill -TERM "$hp" 2>/dev/null
touch "$A/m/k/release"   # gates.sh waits for its running gate command before acting on TERM
wait_bounded "$hp" 30
assert_eq "AC-8 holder: A, sent TERM, exits 143" 143 "$WRC"
assert_eq "AC-8 holder: once A has exited, the queue lock no longer records A" yes \
  "$(if [ "$(rec_field "$QL" pid)" != "$hp" ]; then printf yes; else printf 'no: it still records %s' "$hp"; fi)"
wait_bounded "$bp" 60
assert_eq "AC-8 holder: the run waiting behind A starts, runs and exits 0" "0 present" "$WRC $(present "$B/m/k/finished")"
assert_eq "AC-8 holder: and its work began only after A's had ended" "" "$(readf "$B/m/k/overlap-start")"
assert_eq "AC-8 holder: the queue directory is empty afterwards" "" "$(qsnap)"
# INT is not tested: a background job of a non-interactive shell starts with
# INT ignored, and an ignored signal cannot be trapped (C-4, Signals).

# ---------------------------------------------------------------------------
describe "AC-9  a queue it cannot use: one line, and the run runs as it would have"

touch "$W/afile"
# noq_case <label> <tree> <script> <expected line> <expected status>
noq_case() {
  local lbl="$1" t="$2" p
  rm -rf "$t/m/k"; mkdir -p "$t/m/k"; rm -f "$t"/.claude/state/run.lock*
  rq_run p "$t" "$lbl" "scripts/$3"; wait_bounded "$p" 60
  assert_eq "$lbl: prints the one line for its case" 1 "$(count_line "$4" "$W/$lbl.err")"
  assert_eq "$lbl: and no other run-queue: line" 1 "$(count_re '^run-queue:' "$W/$lbl.err")"
  assert_eq "$lbl: runs its work, with its own exit status ($5)" "$5 present" "$WRC $(present "$t/m/k/finished")"
}
new_case; RQ_DIR="$W/afile/q"
noq_case "AC-9 gates.sh, queue dir under a regular file" "$B" gates.sh \
  "$(cannot_line "$W/afile/q" scripts/gates.sh)" "$SOLO_GATES"
noq_case "AC-9 selftest.sh, queue dir under a regular file" "$B" selftest.sh \
  "$(cannot_line "$W/afile/q" scripts/selftest.sh)" "$SOLO_SELF"

new_case; RQ_DIR="<unset>"; RQ_NOHOME=1; RQ_MODE=off
rq_run p "$B" ac9-nohome-off scripts/gates.sh; wait_bounded "$p" 60; NOHOME_RC=$WRC
RQ_MODE=""
noq_case "AC-9 gates.sh, neither HARNESS_RUN_QUEUE_DIR nor HOME" "$B" gates.sh \
  "$(nohome_line scripts/gates.sh)" "$NOHOME_RC"

new_case
mv "$C/scripts/run-queue.sh" "$W/run-queue.sh.kept" 2>/dev/null
noq_case "AC-9 gates.sh, a tree without run-queue.sh" "$C" gates.sh \
  "$(missing_line scripts/gates.sh)" "$SOLO_GATES"
assert_eq "AC-9: a tree with no scripts/run-queue.sh writes nothing in the queue directory" "" "$(qsnap)"
mv "$W/run-queue.sh.kept" "$C/scripts/run-queue.sh" 2>/dev/null

# A directory at the lock path (R-2). GNU ln links a file INTO an existing
# directory, so without a type check the run would "take" the queue
# silently, leave its record inside the directory, and no full run on the
# machine would ever queue again. It is a queue it cannot use: C-3's line.
new_case
mkdir "$QL"
noq_case "AC-9 gates.sh, the queue lock path is a directory" "$B" gates.sh \
  "$(cannot_line "$Q" scripts/gates.sh)" "$SOLO_GATES"
assert_eq "AC-9 gates.sh, the queue lock path is a directory: nothing is left inside that directory" "" \
  "$(ls -A "$QL" 2>/dev/null)"
rm -rf "$QL"

# ===========================================================================
# HARNESS-111  a --changed run queues: every one that reaches the run lock
# (Contract C-1..C-5). Trees X (every suite), Y (a proper subset) and Z (no
# suite) are described where they are built. The holder, where there is one,
# is a full gates.sh in A, except in AC-2's reverse pair, where it is X's
# --changed run. Every case asserts its header line before the queue.
# ===========================================================================

# The status each --changed run has alone, with the queue off: what a queued
# or nested one is compared with. Measured, not assumed. solo-cx's stderr is
# also AC-2's byte-for-byte reference.
new_case; RQ_MODE=off
rq_run p "$X" solo-cx scripts/selftest.sh --changed; wait_bounded "$p" 120; SOLO_CX=$WRC
new_case; RQ_MODE=off
rq_run p "$Y" solo-cy scripts/selftest.sh --changed; wait_bounded "$p" 120; SOLO_CY=$WRC

# ---------------------------------------------------------------------------
describe "HARNESS-111 AC-1  a --changed run in another tree waits for the full run that holds the queue, then runs"

# changed_pair <label> <tree> <name> <header> <solo status> <other blocks>
# A's full gates.sh holds; <tree>'s --changed run is started; it must not
# start a suite while A holds, must say so naming A, and must run its own
# selection once A ends. <other blocks> is how many `=== other ===` blocks its
# stdout carries: 1 for every suite, 0 for the subset, which selects work only.
changed_pair() {
  local lbl="$1" t="$2" n="$3" hdr="$4" solo="$5" nother="$6" hp wp arc brc bto
  new_case
  hold_run hp "$A" "$lbl-A" scripts/gates.sh
  assert_eq "$lbl: precondition: A's full gates.sh is in progress, held on its release file" yes "$HOLDING"
  cp "$QL" "$W/$lbl-A.rec" 2>/dev/null || : > "$W/$lbl-A.rec"
  rq_run wp "$t" "$lbl-B" scripts/selftest.sh --changed
  wait_until 60 started_or_queued "$t" "$W/$lbl-B.err"
  sleep 3.5   # at least two poll intervals after it queued
  assert_eq "$lbl: precondition: $n's stdout carries the --changed header line for its selection" 1 \
    "$(count_line "$hdr" "$W/$lbl-B.out")"
  assert_eq "$lbl: $n's --changed run has not started its work while A holds the queue, over two poll intervals after it queued" \
    absent "$(present "$t/m/k/started")"
  assert_eq "$lbl: nor printed a suite block: no === <suite> === line yet" 0 "$(count_re '^=== ' "$W/$lbl-B.out")"
  assert_eq "$lbl: precondition: A is still running at that moment" alive "$(is_alive "$hp")"
  assert_eq "$lbl: queued line 1 names the waiting run as $CHG, exactly once, on stderr" 1 \
    "$(count_line "$(q1 "$CHG")" "$W/$lbl-B.err")"
  assert_eq "$lbl: queued line 2 names A's pid, start, tree root and command from A's record, exactly once" 1 \
    "$(count_line "$(q2 "$hp" "$(rec_field "$W/$lbl-A.rec" started)" "$A" scripts/gates.sh)" "$W/$lbl-B.err")"
  assert_eq "$lbl: queued line 3 says it is waiting and names the lock to delete, exactly once" 1 \
    "$(count_line "$(q3 "$hp" "$QL")" "$W/$lbl-B.err")"
  touch "$A/m/k/release"
  wait_bounded "$hp" 60; arc=$WRC
  wait_bounded "$wp" 90; brc=$WRC; bto=$WTO
  assert_eq "$lbl: A finishes with its own status" 0 "$arc"
  assert_eq "$lbl: once A ends, $n's run gets through by itself, within the bound" no "$bto"
  assert_eq "$lbl: $n's work runs to its end" present "$(present "$t/m/k/finished")"
  assert_eq "$lbl: $n's run exits with the status the same run has alone, queue off ($solo)" "$solo" "$brc"
  assert_eq "$lbl: $n's work records, as it starts, that A's had finished" "A" "$(readf "$t/m/k/done-before")"
  assert_eq "$lbl: $n's work saw no other run in progress as it started" "" "$(readf "$t/m/k/overlap-start")"
  assert_eq "$lbl: A's work saw no other run in progress as it ended" "" "$(readf "$A/m/k/overlap-end")"
  assert_eq "$lbl: one starting line naming $CHG, with the total wait" 1 \
    "$(count_span "$(start_prefix "$CHG")" "$START_RE" "$W/$lbl-B.err")"
  assert_eq "$lbl: it runs the suite its selection holds: one === work === block" 1 \
    "$(count_line '=== work ===' "$W/$lbl-B.out")"
  assert_eq "$lbl: and $nother === other === block(s), as its selection says" "$nother" \
    "$(count_line '=== other ===' "$W/$lbl-B.out")"
  assert_eq "$lbl: the queue directory holds nothing once both have ended" "" "$(qsnap)"
}
changed_pair "AC-1 every suite" "$X" X "$HDR_X" "$SOLO_CX" 1
changed_pair "AC-1 subset"      "$Y" Y "$HDR_Y" "$SOLO_CY" 0

# ---------------------------------------------------------------------------
describe "HARNESS-111 AC-2  an uncontended --changed run takes the queue silently, records itself, and leaves nothing"

new_case
rq_run p "$X" ac2c-on scripts/selftest.sh --changed; wait_bounded "$p" 120; onrc=$WRC
R="$X/m/k/qlock"
assert_eq "AC-2 --changed: precondition: its stdout carries the every-suite header line" 1 \
  "$(count_line "$HDR_X" "$W/ac2c-on.out")"
assert_eq "AC-2 --changed: while its suite ran, the queue lock existed" present "$(present "$R")"
assert_eq "AC-2 --changed: the lock records the run's pid" "$p" "$(rec_field "$R" pid)"
assert_eq "AC-2 --changed: the lock records the run's command, $CHG" "$CHG" "$(rec_field "$R" command)"
assert_eq "AC-2 --changed: the lock records the run's tree root, absolute" "$X" "$(rec_field "$R" root)"
assert_eq "AC-2 --changed: it prints no run-queue: line on stdout or stderr" 0 \
  "$(cat "$W/ac2c-on.out" "$W/ac2c-on.err" | awk 'index($0, "run-queue:") == 1 { n++ } END { print n + 0 }')"
if cmp -s "$W/solo-cx.err" "$W/ac2c-on.err"; then
  _ok "AC-2 --changed: its stderr is byte-for-byte the same run's with HARNESS_RUN_QUEUE=off"
else
  _bad "AC-2 --changed: its stderr is byte-for-byte the same run's with HARNESS_RUN_QUEUE=off" \
    "$(diff "$W/solo-cx.err" "$W/ac2c-on.err" 2>&1 | awk 'NR <= 10')"
fi
assert_eq "AC-2 --changed: it exits as the same run does with the queue off ($SOLO_CX)" "$SOLO_CX" "$onrc"
assert_eq "AC-2 --changed: afterwards the queue directory holds neither the lock nor a temporary record" "" "$(qsnap)"

describe "HARNESS-111 AC-2  a --changed run that holds the queue is waited for: a full gates.sh queues behind it"

new_case
hold_run hp "$X" ac2r-X scripts/selftest.sh --changed
assert_eq "AC-2 reverse: precondition: X's --changed run is in progress, held on its release file" yes "$HOLDING"
assert_eq "AC-2 reverse: precondition: X's stdout carries the every-suite header line" 1 \
  "$(count_line "$HDR_X" "$W/ac2r-X.out")"
cp "$QL" "$W/ac2r-X.rec" 2>/dev/null || : > "$W/ac2r-X.rec"
rq_run ap "$A" ac2r-A scripts/gates.sh
wait_until 60 started_or_queued "$A" "$W/ac2r-A.err"
sleep 3.5   # at least two poll intervals after it queued
assert_eq "AC-2 reverse: A's full gates.sh has not started its gate command while X's --changed run holds, over two poll intervals after it queued" \
  absent "$(present "$A/m/k/started")"
assert_eq "AC-2 reverse: precondition: X's run is still running at that moment" alive "$(is_alive "$hp")"
assert_eq "AC-2 reverse: A's queued line 1 names A's own command, exactly once" 1 \
  "$(count_line "$(q1 scripts/gates.sh)" "$W/ac2r-A.err")"
assert_eq "AC-2 reverse: A's queued line 2 names X's pid, start, tree root and $CHG, exactly once" 1 \
  "$(count_line "$(q2 "$hp" "$(rec_field "$W/ac2r-X.rec" started)" "$X" "$CHG")" "$W/ac2r-A.err")"
touch "$X/m/k/release"
wait_bounded "$hp" 60; xrc=$WRC
wait_bounded "$ap" 90; arc=$WRC; ato=$WTO
assert_eq "AC-2 reverse: X's --changed run finishes with its own status ($SOLO_CX)" "$SOLO_CX" "$xrc"
assert_eq "AC-2 reverse: once X ends, A gets through by itself, within the bound" no "$ato"
assert_eq "AC-2 reverse: A's work runs to its end" present "$(present "$A/m/k/finished")"
assert_eq "AC-2 reverse: A exits with the status it has alone ($SOLO_GATES)" "$SOLO_GATES" "$arc"
assert_eq "AC-2 reverse: A's work records, as it starts, that X's had finished" "X" "$(readf "$A/m/k/done-before")"
assert_eq "AC-2 reverse: A's work saw no other run in progress as it started" "" "$(readf "$A/m/k/overlap-start")"
assert_eq "AC-2 reverse: the queue directory holds nothing once both have ended" "" "$(qsnap)"

# ---------------------------------------------------------------------------
describe "HARNESS-111 AC-3  --changed runs nested under the holder, in its own tree and another, pass through"

new_case
touch "$X/m/k/nest"
rq_run op "$X" ac3c-outer scripts/gates.sh; wait_bounded "$op" 120
orc=$WRC; oto=$WTO
for f in "$X"/m/k/n*.pid; do [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null; done
assert_eq "AC-3: precondition: the inner run in X (the holder's tree) carries the every-suite header line" 1 \
  "$(count_line "$HDR_X" "$X/m/k/n1.out")"
assert_eq "AC-3: precondition: the inner run in Y (another tree) carries the subset header line" 1 \
  "$(count_line "$HDR_Y" "$X/m/k/n2.out")"
assert_eq "AC-3: the whole arrangement completes within the bound: a nested --changed run does not wait on its ancestor" no "$oto"
assert_eq "AC-3: the outer full gates.sh finishes with its own status" 0 "$orc"
assert_eq "AC-3: the inner --changed run in X exits as it does alone ($SOLO_CX)" "$SOLO_CX" "$(readf "$X/m/k/n1.rc")"
assert_eq "AC-3: the inner --changed run in Y exits as it does alone ($SOLO_CY), its suite run" "$SOLO_CY present" \
  "$(readf "$X/m/k/n2.rc") $(present "$Y/m/k/finished")"
assert_eq "AC-3: neither inner run prints a run-queue: line" 0 \
  "$(cat "$X/m/k/n1.out" "$X/m/k/n1.err" "$X/m/k/n2.out" "$X/m/k/n2.err" 2>/dev/null | awk 'index($0, "run-queue:") == 1 { n++ } END { print n + 0 }')"
assert_eq "AC-3: after the inner run in X has ended, the queue lock still records the outer run's pid" "$op" \
  "$(rec_field "$X/m/k/n1.qlock" pid)"
assert_eq "AC-3: after the inner run in Y has ended, the queue lock still records the outer run's pid" "$op" \
  "$(rec_field "$X/m/k/n2.qlock" pid)"
assert_eq "AC-3: and once the outer run has ended the queue directory is empty" "" "$(qsnap)"

# ---------------------------------------------------------------------------
describe "HARNESS-111 AC-4, AC-1 control  beside a held queue: a --changed run that selects no suite, and one with the queue off"

new_case
hold_run hp "$A" ac4c-A scripts/gates.sh
assert_eq "AC-4: precondition: A's full gates.sh holds the queue, its work in progress" yes "$HOLDING"
before="$(qsnap)"
rq_run p "$Z" ac4c-Z scripts/selftest.sh --changed; wait_bounded "$p" 60
assert_eq "AC-4: Z's --changed run that selects no suite exits 1 at once, within the bound, while A holds" "no 1" "$WTO $WRC"
assert_eq "AC-4: its stdout is exactly the selected-no-suite line" "$HDR_Z" "$(tr -d '\r' < "$W/ac4c-Z.out")"
assert_eq "AC-4: it prints no run-queue: line on stdout or stderr" 0 \
  "$(cat "$W/ac4c-Z.out" "$W/ac4c-Z.err" | awk 'index($0, "run-queue:") == 1 { n++ } END { print n + 0 }')"
assert_eq "AC-4: it creates, changes and removes nothing in the queue directory" "$before" "$(qsnap)"
assert_eq "AC-4: and leaves no run.lock in Z" 0 "$(leftovers "$Z")"
assert_eq "AC-4: nothing ran: Z's work never started" absent "$(present "$Z/m/k/started")"
assert_eq "AC-4: precondition: A is still running then" alive "$(is_alive "$hp")"

RQ_MODE=off
rq_run p "$X" ac1c-off scripts/selftest.sh --changed
wait_until 60 started_or_queued "$X" "$W/ac1c-off.err"
assert_eq "AC-1 control: precondition: X's stdout carries the every-suite header line" 1 \
  "$(count_line "$HDR_X" "$W/ac1c-off.out")"
assert_eq "AC-1 control: with HARNESS_RUN_QUEUE=off, X's --changed run starts its work while A holds" present \
  "$(present "$X/m/k/started")"
assert_eq "AC-1 control: and its work saw A's in progress - the arrangement can see two runs at once" "A" \
  "$(readf "$X/m/k/overlap-start")"
assert_eq "AC-1 control: precondition: A is still running then" alive "$(is_alive "$hp")"
wait_bounded "$p" 60
assert_eq "AC-1 control: X's run exits as it does alone ($SOLO_CX)" "$SOLO_CX" "$WRC"
RQ_MODE=""
touch "$A/m/k/release"; wait_bounded "$hp" 60
assert_eq "AC-4: A then finishes, exit 0" 0 "$WRC"

# ---------------------------------------------------------------------------
describe "HARNESS-111 AC-5  run_lock_queues answers as C-2's table says"

# rows: <0 queues | 1 does not>|<command string>
QUEUE_ROWS='0|scripts/gates.sh
0|scripts/gates.sh --story T-1
0|scripts/selftest.sh
0|scripts/selftest.sh --changed
0|scripts/selftest.sh --changed origin/main
1|scripts/selftest.sh --changedx
1|scripts/selftest.sh run-queue --changed
1|scripts/selftest.sh run-queue
1|scripts/selftest.sh run-queue run-lock
1|scripts/gates.sh --fast
1|scripts/gates.sh --gate unit
1|scripts/gates.sh --skip unit
1|scripts/gates.sh --required
1|scripts/gates.sh --story T-1 --fast
1|scripts/gates.sh --list
1|scripts/gates.sh --audit
0|scripts/gates.sh --changed
1|scripts/selftest-needed.sh --suites
1|scripts/check-boundaries.sh
1|scripts/ci-local.sh
1|scripts/attest.sh -- bash scripts/selftest.sh --changed
1|'
HAVE_QUEUES="$( ( . "$REPO_ROOT/scripts/run-lock.sh" && type run_lock_queues >/dev/null 2>&1 ) && printf yes || printf no)"
while IFS='|' read -r want cmd; do
  [ -n "$want" ] || continue
  if [ "$want" = 0 ]; then word=queues; else word="does not queue"; fi
  if [ "$HAVE_QUEUES" = yes ]; then
    got="$( . "$REPO_ROOT/scripts/run-lock.sh"; set -f; run_lock_queues "$cmd"; printf '%s' "$?")"
    assert_eq "run_lock_queues '$cmd' $word" "$want" "$got"
  else
    _bad "run_lock_queues '$cmd' $word" "scripts/run-lock.sh defines no run_lock_queues"
  fi
done <<EOF
$QUEUE_ROWS
EOF

describe "HARNESS-111 C-2, C-3  the two lines of scripts/run-lock.sh the suite and DV-1 depend on"

assert_eq "scripts/run-lock.sh opens run_lock_queues alone on its line" 1 \
  "$(grep -cxF 'run_lock_queues() {' "$REPO_ROOT/scripts/run-lock.sh" 2>/dev/null || :)"
assert_eq "run_lock_join asks run_lock_queues, on exactly the one line DV-1 mutates" 1 \
  "$(grep -cxF '  run_lock_queues "$2" || return 0' "$REPO_ROOT/scripts/run-lock.sh" 2>/dev/null || :)"

# ===========================================================================
# HARNESS-112  a queue lock that cannot be removed (Contract C-2, C-3). The
# reclaim code in run_queue_acquire removes a stale or unreadable lock and
# tries again; if the lock is still there, unchanged, it gives up on the queue
# with C-3's `cannot use` line instead of going round for ever. The input that
# reaches that exit is a regular lock file `rm` cannot delete, made by an rm
# shim on the run's PATH (RQ_PATH) that refuses only a path ending
# /run-queue.lock and records each refusal: the record is each case's
# precondition, so a host where the shim was not picked up fails as that.
# These tests are written against the shipped module and pass on arrival;
# DV-1 earns them at GATES by making the exit's condition false.
# ===========================================================================
describe "HARNESS-112 AC-1, AC-2  a queue lock that cannot be removed: the reclaim line once, then one line, and the run runs"

REAL_RM="$(command -v rm)"
mkdir -p "$W/shim"
cat > "$W/shim/rm" <<SHIM
#!/usr/bin/env bash
for a in "\$@"; do
  case "\$a" in */run-queue.lock) printf '%s\n' "\$a" >> '$W/shim/refused'; exit 1 ;; esac
done
exec '$REAL_RM' "\$@"
SHIM
chmod +x "$W/shim/rm"

assert_eq "HARNESS-112 AC-2: precondition: the dead pid is not running" gone "$(is_alive "$DEAD")"

# unremovable_case <label> <pid-or-empty> <expected reclaim line>   A planted
# lock (no pid line when <pid> is empty), the rm shim on the run's PATH, a
# full gates.sh in B with the queue on.
unremovable_case() {
  local lbl="$1" p before
  new_case
  qplant "$2" "$PLANT_STARTED" "scripts/selftest.sh ghost" "/ghost/tree"
  cp "$QL" "$W/$lbl.planted"
  before="$(qsnap)"
  rm -f "$W/shim/refused"
  RQ_PATH="$W/shim"
  rq_run p "$B" "$lbl" scripts/gates.sh; wait_bounded "$p" 60
  RQ_PATH=""
  assert_eq "$lbl: precondition: the run tried to remove the queue lock and the rm shim refused it" yes \
    "$(at_least 1 "$(count_line "$QL" "$W/shim/refused")")"
  assert_eq "$lbl: exits within the bound: it does not go round the reclaim loop" no "$WTO"
  assert_eq "$lbl: prints the reclaim line, exactly once" 1 "$(count_line "$3" "$W/$lbl.err")"
  assert_eq "$lbl: then gives up on the queue: the cannot-use line naming the queue directory, exactly once" 1 \
    "$(count_line "$(cannot_line "$Q" scripts/gates.sh)" "$W/$lbl.err")"
  assert_eq "$lbl: and prints no other run-queue: line" 2 "$(count_re '^run-queue:' "$W/$lbl.err")"
  assert_eq "$lbl: the first run-queue: line is the reclaim line" "$3" "$(first_rq "$W/$lbl.err")"
  assert_eq "$lbl: the last run-queue: line is the cannot-use line" \
    "$(cannot_line "$Q" scripts/gates.sh)" "$(last_rq "$W/$lbl.err")"
  assert_eq "$lbl: runs its work, with the status it has alone ($SOLO_GATES)" "$SOLO_GATES present" \
    "$WRC $(present "$B/m/k/finished")"
  assert_eq "$lbl: its work saw the lock as planted, not a record of its own" same \
    "$(if cmp -s "$W/$lbl.planted" "$B/m/k/qlock"; then printf same; else printf differs; fi)"
  assert_eq "$lbl: the queue directory afterwards holds the planted lock, byte for byte, and nothing else" \
    "$before" "$(qsnap)"
  assert_eq "$lbl: and the tree holds no run lock" 0 "$(leftovers "$B")"
}
unremovable_case "HARNESS-112 AC-1 no pid" "" "$(unread_line "$QL")"
unremovable_case "HARNESS-112 AC-2 stale pid" "$DEAD" \
  "$(stale_line "$DEAD" "scripts/selftest.sh ghost" /ghost/tree)"

# ---------------------------------------------------------------------------
describe "C-4, C-6  the shipped pieces the mutations and the messages depend on"

RQS="$REPO_ROOT/scripts/run-queue.sh"
assert_eq "scripts/run-queue.sh defines run_queue_alive on exactly the one line DV-1 mutates" 1 \
  "$(grep -cxF 'run_queue_alive() { kill -0 "$1" 2>/dev/null; }' "$RQS" 2>/dev/null || :)"
assert_eq "scripts/run-lock.sh opens run_lock_full on exactly the one line DV-3 mutates" 1 \
  "$(grep -cxF 'run_lock_full() {' "$REPO_ROOT/scripts/run-lock.sh" 2>/dev/null || :)"
assert_eq "scripts/run-queue.sh tests for a lock it could not remove on exactly the one line HARNESS-112 DV-1 mutates" 1 \
  "$(grep -cxF '    if [ -e "$lock" ] && [ "$(run_queue_pid "$lock")" = "$pid" ]; then' "$RQS" 2>/dev/null || :)"
for row in '0 0m00s' '59 0m59s' '60 1m00s' '65 1m05s' '10800 180m00s'; do
  n="${row% *}"; want="${row#* }"
  if [ -f "$RQS" ]; then
    assert_eq "run_queue_span $n is $want" "$want" "$( . "$RQS"; run_queue_span "$n")"
  else
    _bad "run_queue_span $n is $want" "scripts/run-queue.sh does not exist"
  fi
done

# ===========================================================================
# HARNESS-120  a queued run answers when asked, and the queue is named where
# an agent reads first (Contract C-1, C-2, C-5). Lines are C-2's, compared
# whole; needles are C-5's, each inside its region.
# ===========================================================================

RS="$REPO_ROOT/scripts/run-status.sh"
if [ -f "$RS" ]; then HAVE_RS=yes; else HAVE_RS=no; fi
MARKER_SEEN=no

# rs_eq <what> <expected> <actual>   An assertion about an answer of
# run-status.sh: one assertion whether or not the script exists (C-7).
rs_eq() {
  if [ "$HAVE_RS" = yes ]; then assert_eq "$1" "$2" "$3"
  else _bad "$1" "scripts/run-status.sh does not exist (expected: $2)"; fi
}
# mk_eq <what> <expected> <actual>   An assertion that a run.queued is absent:
# it counts only once AC-1 has seen a waiter write one.
mk_eq() {
  if [ "$MARKER_SEEN" = yes ]; then assert_eq "$1" "$2" "$3"
  else _bad "$1" "no run.queued was ever seen while a run was queued (AC-1); its absence here proves nothing"; fi
}

marker()     { printf '%s/.claude/state/run.queued' "$1"; }
has_marker() { [ -f "$(marker "$1")" ]; }
rs_line()    { awk -v n="$2" 'NR == n { print; exit }' "$1" 2>/dev/null; }
rs_count()   { awk 'END { print NR + 0 }' "$1" 2>/dev/null; }

# snapdir <dir>   Every file in <dir>, name and exact bytes; no-dir if absent.
snapdir() {
  local f
  [ -d "$1" ] || { printf 'no-dir'; return 0; }
  for f in "$1"/* "$1"/.[!.]*; do
    [ -e "$f" ] || continue
    printf '%s:' "${f##*/}"; cat "$f"; printf '|'
  done
  return 0
}

# lplant <tree> <pid-or-empty> <started> <command>   A run.lock by hand.
lplant() {
  mkdir -p "$1/.claude/state"
  { [ -n "$2" ] && printf 'pid\t%s\n' "$2"
    printf 'started\t%s\ncommand\t%s\n' "$3" "$4"; } > "$1/.claude/state/run.lock"
}
# mplant <tree> <pid> <since> <command>   A run.queued by hand (C-1's form).
mplant() {
  mkdir -p "$1/.claude/state"
  printf 'pid\t%s\nsince\t%s\ncommand\t%s\n' "$2" "$3" "$4" > "$(marker "$1")"
}

# rs_ask <cwd> <label> [args...]   Runs run-status.sh (ASK_SCRIPT, default the
# cwd's own scripts/run-status.sh) in the background with the queue
# environment of rq_run, bounded at 20 s. HARNESS_RUN_QUEUE=off: C-2 reads the
# queue lock whatever that is set to. Sets ASK_RC and ASK_TO.
ASK_SCRIPT=""; ASK_RC=""; ASK_TO=""
rs_ask() {
  local RQ_MODE=off p c="$1" l="$2"; shift 2
  rq_run p "$c" "$l" "${ASK_SCRIPT:-scripts/run-status.sh}" "$@"
  wait_bounded "$p" 20
  ASK_RC=$WRC; ASK_TO=$WTO
}

# rs_expect <what> <label> <line>...   The whole answer: within the bound,
# exit 0, nothing on stderr, exactly these lines on stdout, in order.
rs_expect() {
  local what="$1" f="$W/$2" n=0 l; shift 2
  rs_eq "$what: answers within the bound: it never waits" no "$ASK_TO"
  rs_eq "$what: exits 0" 0 "$ASK_RC"
  rs_eq "$what: prints nothing on stderr" "" "$(readf "$f.err")"
  rs_eq "$what: prints exactly $# line(s) on stdout" "$#" "$(rs_count "$f.out")"
  for l in "$@"; do
    n=$((n+1))
    rs_eq "$what: stdout line $n" "$l" "$(rs_line "$f.out" "$n")"
  done
}

# C-2's lines.
s_idle()   { printf 'run-status: idle: no harness run holds %s.' "$1"; }
s_left()   { printf 'run-status: idle: .claude/state/run.lock is left over from pid %s, which is no longer running; the next run reclaims it.' "$1"; }
S_NOPID='run-status: idle: .claude/state/run.lock records no pid; the next run reclaims it.'
s_run()    { printf 'run-status: running: pid %s, started %s: %s' "$1" "$2" "$3"; }               # P T C
s_q1()     { printf 'run-status: queued: pid %s, waiting since %s: %s' "$1" "$2" "$3"; }          # P since C
s_q2()     { printf 'run-status:   behind pid %s, started %s, in %s: %s' "$1" "$2" "$3" "$4"; }  # Q T2 R2 C2
S_Q2NONE='run-status:   behind nothing at this instant: it takes the queue at its next poll.'
S_Q3='run-status: this is waiting, not hanging: it starts by itself when that run ends. Never stop a queued run to requeue it.'
S_NOHOME='run-status: machine queue: cannot be located: neither HARNESS_RUN_QUEUE_DIR nor HOME is set.'
s_free()   { printf 'run-status: machine queue: free (%s)' "$1"; }
s_held()   { printf 'run-status: machine queue: held by pid %s, started %s, in %s: %s' "$1" "$2" "$3" "$4"; }
s_stale()  { printf 'run-status: machine queue: stale lock from pid %s, which is no longer running; the next run that queues reclaims it (%s)' "$1" "$2"; }
s_unread() { printf 'run-status: machine queue: unreadable lock, no pid recorded; the next run that queues reclaims it (%s)' "$1"; }
PLANT_SINCE="2026-01-02T03:05:06Z"

# ---------------------------------------------------------------------------
describe "HARNESS-120 AC-1  asked while queued: the queued lines, behind what, and the holder; asked in the holder: running"

new_case
hold_run hp "$A" st1-A scripts/gates.sh
assert_eq "HARNESS-120 AC-1: precondition: A's full gates.sh holds the queue, its work in progress" yes "$HOLDING"
rq_run wp "$B" st1-B scripts/gates.sh
wait_until 60 is_queued "$W/st1-B.err"
assert_eq "HARNESS-120 AC-1: precondition: B's full gates.sh has printed its run-queue: queued: line" 1 \
  "$(count_line "$(q1 scripts/gates.sh)" "$W/st1-B.err")"
wait_until 5 has_marker "$B"
MK="$(marker "$B")"
assert_eq "HARNESS-120 C-1: while B waits, B's tree holds .claude/state/run.queued" present "$(present "$MK")"
if [ -f "$MK" ]; then MARKER_SEEN=yes; cp "$MK" "$W/st1-B.marker"; else : > "$W/st1-B.marker"; fi
assert_eq "HARNESS-120 C-1: the marker is three TAB-separated lines: pid, since, command" \
  "pid since command" "$(rec_keys "$W/st1-B.marker")"
assert_eq "HARNESS-120 C-1: the marker records the waiting script's pid" "$wp" "$(rec_field "$W/st1-B.marker" pid)"
assert_eq "HARNESS-120 C-1: the marker records when it began waiting, UTC to the second" 1 \
  "$(rec_field "$W/st1-B.marker" since | awk -v re="$UTC_RE" '$0 ~ re { n++ } END { print n + 0 }')"
assert_eq "HARNESS-120 C-1: the marker records the command the queue lock would record" scripts/gates.sh \
  "$(rec_field "$W/st1-B.marker" command)"
mk_eq "HARNESS-120 C-1: the holder, which never waited, writes no marker in A" absent "$(present "$(marker "$A")")"
SINCE="$(rec_field "$W/st1-B.marker" since)"
cp "$QL" "$W/st1.qrec" 2>/dev/null || : > "$W/st1.qrec"
T2="$(rec_field "$W/st1.qrec" started)"; R2="$(rec_field "$W/st1.qrec" root)"; C2="$(rec_field "$W/st1.qrec" command)"
BC="$(rec_field "$B/.claude/state/run.lock" command)"
AT="$(rec_field "$A/.claude/state/run.lock" started)"; AC="$(rec_field "$A/.claude/state/run.lock" command)"
assert_eq "HARNESS-120 AC-1: precondition: B's run.lock records B's pid, and the queue lock A's" "$wp $hp" \
  "$(rec_field "$B/.claude/state/run.lock" pid) $(rec_field "$W/st1.qrec" pid)"

rs_ask "$B" st1-askB
rs_expect "HARNESS-120 AC-1 asked in B (queued)" st1-askB \
  "$(s_q1 "$wp" "$SINCE" "$BC")" \
  "$(s_q2 "$hp" "$T2" "$R2" "$C2")" \
  "$S_Q3" \
  "$(s_held "$hp" "$T2" "$R2" "$C2")"
rs_ask "$A" st1-askA
rs_expect "HARNESS-120 AC-1 asked in A (the holder, at the same moment)" st1-askA \
  "$(s_run "$hp" "$AT" "$AC")" \
  "$(s_held "$hp" "$T2" "$R2" "$C2")"
rs_eq "HARNESS-120 AC-1: B's work has still not started after both answers, and A is still running" "absent alive" \
  "$(present "$B/m/k/started") $(is_alive "$hp")"

# ---------------------------------------------------------------------------
describe "HARNESS-120 AC-2  once B gets through: running and held by B, no marker; once it ends: idle and free"

touch "$B/m/k/hold"
touch "$A/m/k/release"
wait_bounded "$hp" 60
assert_eq "HARNESS-120 AC-2: precondition: A finishes, exit 0" 0 "$WRC"
if wait_until 60 is_started "$B"; then st2=yes; else st2=no; fi
rm -f "$B/m/k/hold"
assert_eq "HARNESS-120 AC-2: precondition: B, through the queue, has started its work (held)" yes "$st2"
mk_eq "HARNESS-120 AC-2: once B has started its work, its run.queued is gone" absent "$(present "$MK")"
cp "$QL" "$W/st2.qrec" 2>/dev/null || : > "$W/st2.qrec"
rs_ask "$B" st2-askB
rs_expect "HARNESS-120 AC-2 asked in B (running, holding the queue)" st2-askB \
  "$(s_run "$wp" "$(rec_field "$B/.claude/state/run.lock" started)" "$BC")" \
  "$(s_held "$wp" "$(rec_field "$W/st2.qrec" started)" "$B" "$(rec_field "$W/st2.qrec" command)")"
touch "$B/m/k/release"
wait_bounded "$wp" 60
assert_eq "HARNESS-120 AC-2: precondition: B finishes with the status it has alone ($SOLO_GATES)" "$SOLO_GATES" "$WRC"
rs_ask "$B" st2-idleB
rs_expect "HARNESS-120 AC-2 asked in B after both ended" st2-idleB "$(s_idle "$B")" "$(s_free "$QL")"
rs_ask "$A" st2-idleA
rs_expect "HARNESS-120 AC-2 asked in A after both ended" st2-idleA "$(s_idle "$A")" "$(s_free "$QL")"
mk_eq "HARNESS-120 AC-2: neither tree holds a run.queued afterwards" "absent absent" \
  "$(present "$(marker "$A")") $(present "$(marker "$B")")"

# ---------------------------------------------------------------------------
describe "HARNESS-120 AC-3 (a)  a waiter sent TERM exits 143 and takes its marker with it"

# term_marker <label> <script>
term_marker() {
  local lbl="$1" s="$2" p seen
  new_case
  qplant "$LIVE1" "$PLANT_STARTED" "scripts/gates.sh" "$A"
  rq_run p "$B" "$lbl" "scripts/$s"
  wait_until 60 is_queued "$W/$lbl.err"
  assert_eq "$lbl: precondition: the run is queued" 1 "$(count_line "$(q1 "scripts/$s")" "$W/$lbl.err")"
  if wait_until 5 has_marker "$B"; then seen=seen; else seen=never-written; fi
  kill -TERM "$p" 2>/dev/null
  wait_bounded "$p" 10
  assert_eq "$lbl: it wrote a marker while queued, exits 143 on TERM, and the marker is gone" "seen 143 absent" \
    "$seen $WRC $(present "$(marker "$B")")"
}
term_marker "HARNESS-120 AC-3 (a) gates.sh waiter" gates.sh
term_marker "HARNESS-120 AC-3 (a) selftest.sh waiter" selftest.sh

# ---------------------------------------------------------------------------
describe "HARNESS-120 AC-3 (b), (c)  queued means a live waiter the run.lock records, never a file"

assert_eq "HARNESS-120 AC-3: precondition: the dead pid is gone and both live holders are alive" "gone alive alive" \
  "$(is_alive "$DEAD") $(is_alive "$LIVE1") $(is_alive "$LIVE2")"

# plant_case <label> <run.lock pid|-none-> <marker pid|-none-> <expected first line>
# B's state planted by hand, an empty queue directory: the answer is the
# state line the run.lock alone decides, then the free line.
plant_case() {
  local lbl="$1"
  new_case
  [ "$2" = -none- ] || lplant "$B" "$2" "$PLANT_STARTED" scripts/gates.sh
  [ "$3" = -none- ] || mplant "$B" "$3" "$PLANT_SINCE" scripts/gates.sh
  rs_ask "$B" "$lbl"
  rs_expect "$lbl" "$lbl" "$4" "$(s_free "$QL")"
}
plant_case "HARNESS-120 AC-3 (b) marker and run.lock both name a dead pid" \
  "$DEAD" "$DEAD" "$(s_left "$DEAD")"
plant_case "HARNESS-120 AC-3 (b) marker names a dead pid, run.lock a live one" \
  "$LIVE1" "$DEAD" "$(s_run "$LIVE1" "$PLANT_STARTED" scripts/gates.sh)"
plant_case "HARNESS-120 AC-3 (b) marker names a live pid the run.lock does not record" \
  "$LIVE1" "$LIVE2" "$(s_run "$LIVE1" "$PLANT_STARTED" scripts/gates.sh)"
plant_case "HARNESS-120 AC-3 (b) a marker naming a live pid and no run.lock" \
  -none- "$LIVE1" "$(s_idle "$B")"
plant_case "HARNESS-120 AC-3 (c) a run.lock whose pid is not running" \
  "$DEAD" -none- "$(s_left "$DEAD")"
plant_case "HARNESS-120 C-2 a run.lock with no pid" \
  "" -none- "$S_NOPID"
plant_case "HARNESS-120 C-2 a run.lock with a non-numeric pid" \
  "not-a-pid" -none- "$S_NOPID"
plant_case "HARNESS-120 C-2 a live run.lock and no marker" \
  "$LIVE1" -none- "$(s_run "$LIVE1" "$PLANT_STARTED" scripts/gates.sh)"
plant_case "HARNESS-120 C-2 nothing in the tree" \
  -none- -none- "$(s_idle "$B")"

describe "HARNESS-120 C-2  the planted waiter that IS believed: the control for the controls above"

# A marker and a run.lock naming the same live pid is a waiter. The planted
# cases above are controls only if this one reads as queued.
new_case
lplant "$B" "$LIVE1" "$PLANT_STARTED" scripts/gates.sh
mplant "$B" "$LIVE1" "$PLANT_SINCE" scripts/gates.sh
qplant "$LIVE2" "$PLANT_STARTED" "scripts/selftest.sh ghost" "/ghost/tree"
rs_ask "$B" st3-live
rs_expect "HARNESS-120 C-2 planted waiter behind a live holder" st3-live \
  "$(s_q1 "$LIVE1" "$PLANT_SINCE" scripts/gates.sh)" \
  "$(s_q2 "$LIVE2" "$PLANT_STARTED" /ghost/tree "scripts/selftest.sh ghost")" \
  "$S_Q3" \
  "$(s_held "$LIVE2" "$PLANT_STARTED" /ghost/tree "scripts/selftest.sh ghost")"

new_case
lplant "$B" "$LIVE1" "$PLANT_STARTED" scripts/gates.sh
mplant "$B" "$LIVE1" "$PLANT_SINCE" scripts/gates.sh
rs_ask "$B" st3-none
rs_expect "HARNESS-120 C-2 planted waiter, no queue lock: behind nothing at this instant" st3-none \
  "$(s_q1 "$LIVE1" "$PLANT_SINCE" scripts/gates.sh)" "$S_Q2NONE" "$S_Q3" "$(s_free "$QL")"

new_case
lplant "$B" "$LIVE1" "$PLANT_STARTED" scripts/gates.sh
mplant "$B" "$LIVE1" "$PLANT_SINCE" scripts/gates.sh
qplant "$LIVE1" "$PLANT_STARTED" scripts/gates.sh "$B"
rs_ask "$B" st3-self
rs_expect "HARNESS-120 C-2 planted waiter, the queue lock naming the waiter itself: behind nothing" st3-self \
  "$(s_q1 "$LIVE1" "$PLANT_SINCE" scripts/gates.sh)" "$S_Q2NONE" "$S_Q3" \
  "$(s_held "$LIVE1" "$PLANT_STARTED" "$B" scripts/gates.sh)"

describe "HARNESS-120 C-2  the queue line for each state of the queue lock"

# queue_case <label> <queue pid|-none-> <expected queue line>   B idle.
queue_case() {
  local lbl="$1"
  new_case
  [ "$2" = -none- ] || qplant "$2" "$PLANT_STARTED" "scripts/selftest.sh ghost" "/ghost/tree"
  rs_ask "$B" "$lbl"
  rs_expect "$lbl" "$lbl" "$(s_idle "$B")" "$3"
}
queue_case "HARNESS-120 C-2 queue held by a live pid" "$LIVE2" \
  "$(s_held "$LIVE2" "$PLANT_STARTED" /ghost/tree "scripts/selftest.sh ghost")"
queue_case "HARNESS-120 C-2 queue lock from a dead pid" "$DEAD" "$(s_stale "$DEAD" "$QL")"
queue_case "HARNESS-120 C-2 queue lock with no pid" "" "$(s_unread "$QL")"
queue_case "HARNESS-120 C-2 queue lock with a non-numeric pid" "not-a-pid" "$(s_unread "$QL")"

describe "HARNESS-120 C-2  the root is the script's own, never \$PWD or CLAUDE_PROJECT_DIR"

new_case
lplant "$A" "$LIVE1" "$PLANT_STARTED" scripts/gates.sh
OLD_CPD="${CLAUDE_PROJECT_DIR-<unset>}"
CLAUDE_PROJECT_DIR="$A"; export CLAUDE_PROJECT_DIR
ASK_SCRIPT="$B/scripts/run-status.sh"
rs_ask "$A" st3-root
ASK_SCRIPT=""
if [ "$OLD_CPD" = "<unset>" ]; then unset CLAUDE_PROJECT_DIR; else CLAUDE_PROJECT_DIR="$OLD_CPD"; fi
rs_expect "HARNESS-120 C-2 B's copy run from A's directory, CLAUDE_PROJECT_DIR=A, A running: answers for B" st3-root \
  "$(s_idle "$B")" "$(s_free "$QL")"

# ---------------------------------------------------------------------------
describe "HARNESS-120 AC-4  a run beside the holder is running, not queued"

new_case
hold_run hp "$A" st4-A scripts/gates.sh
assert_eq "HARNESS-120 AC-4: precondition: A's full gates.sh holds the queue, its work in progress" yes "$HOLDING"
cp "$QL" "$W/st4.qrec" 2>/dev/null || : > "$W/st4.qrec"
T2="$(rec_field "$W/st4.qrec" started)"

# beside_status <label> <script> [args...]   B started beside A, held; asked.
beside_status() {
  local lbl="$1" bp; shift
  rm -rf "$B/m/k"; mkdir -p "$B/m/k"; rm -f "$B"/.claude/state/run.lock* "$(marker "$B")"
  hold_run bp "$B" "$lbl" "$@"
  assert_eq "$lbl: precondition: B's run is in progress beside A, held" "yes alive" "$HOLDING $(is_alive "$hp")"
  rs_ask "$B" "$lbl-ask"
  rs_expect "$lbl" "$lbl-ask" \
    "$(s_run "$bp" "$(rec_field "$B/.claude/state/run.lock" started)" "$(rec_field "$B/.claude/state/run.lock" command)")" \
    "$(s_held "$hp" "$T2" "$A" scripts/gates.sh)"
  mk_eq "$lbl: B holds no run.queued" absent "$(present "$(marker "$B")")"
  touch "$B/m/k/release"; wait_bounded "$bp" 60
}
beside_status "HARNESS-120 AC-4 (a) gates.sh --fast beside the holder" scripts/gates.sh --fast
RQ_MODE=off
beside_status "HARNESS-120 AC-4 (b) full gates.sh, HARNESS_RUN_QUEUE=off, beside the holder" scripts/gates.sh
RQ_MODE=""
touch "$A/m/k/release"; wait_bounded "$hp" 60
assert_eq "HARNESS-120 AC-4: precondition: A then finishes, exit 0" 0 "$WRC"

# ---------------------------------------------------------------------------
describe "HARNESS-120 C-1  a waiter that goes on without the queue takes its marker with it (R-1)"

# B queues behind a planted live holder; the queue lock then becomes a
# directory, so B's next poll gets run_queue_link's 2 and takes the
# "cannot use ...; runs without the machine-wide queue" exit in the wait
# loop (the `2)` arm of run_queue_acquire's case). B then works, held, beside
# nothing: its marker must be gone, and asked it must read as running, never
# queued - AC-4's answer for a run working beside the holder.
saw_cannot() { [ "$(count_line "$(cannot_line "$Q" scripts/gates.sh)" "$1")" -gt 0 ]; }
new_case
qplant "$LIVE1" "$PLANT_STARTED" "scripts/selftest.sh ghost" "/ghost/tree"
touch "$B/m/k/hold"
rq_run wp "$B" st6-B scripts/gates.sh
wait_until 60 is_queued "$W/st6-B.err"
if wait_until 5 has_marker "$B"; then st6m=present; else st6m=absent; fi
assert_eq "HARNESS-120 C-1 R-1: precondition: B is queued behind the planted holder and has written its marker" "1 present" \
  "$(count_line "$(q1 scripts/gates.sh)" "$W/st6-B.err") $st6m"
rm -f "$QL"; mkdir "$QL"
wait_until 30 saw_cannot "$W/st6-B.err"
if wait_until 30 is_started "$B"; then st6s=yes; else st6s=no; fi
rm -f "$B/m/k/hold"
assert_eq "HARNESS-120 C-1 R-1: precondition: with the queue lock a directory, B prints the cannot-use line once and starts its work" "1 yes" \
  "$(count_line "$(cannot_line "$Q" scripts/gates.sh)" "$W/st6-B.err") $st6s"
assert_eq "HARNESS-120 C-1 R-1: once B goes on without the queue, B's run.queued is gone" absent "$(present "$(marker "$B")")"
rs_ask "$B" st6-askB
rs_eq "HARNESS-120 C-1 R-1: asked in B, working without the queue, the first line is running for B's pid" \
  "$(s_run "$wp" "$(rec_field "$B/.claude/state/run.lock" started)" scripts/gates.sh)" "$(rs_line "$W/st6-askB.out" 1)"
touch "$B/m/k/release"; wait_bounded "$wp" 60
rmdir "$QL" 2>/dev/null

# ---------------------------------------------------------------------------
describe "HARNESS-120 AC-5  asking changes nothing, creates nothing, and never waits"

new_case
lplant "$B" "$LIVE1" "$PLANT_STARTED" scripts/gates.sh
mplant "$B" "$LIVE1" "$PLANT_SINCE" scripts/gates.sh
qplant "$LIVE2" "$PLANT_STARTED" "scripts/selftest.sh ghost" "/ghost/tree"
qbefore="$(snapdir "$Q")"; sbefore="$(snapdir "$B/.claude/state")"
rs_ask "$B" st5-same
rs_eq "HARNESS-120 AC-5: asked with the queue and the run.lock held, it answers within the bound, exit 0" "no 0" "$ASK_TO $ASK_RC"
rs_eq "HARNESS-120 AC-5: and it did answer: its first line is the queued line" \
  "$(s_q1 "$LIVE1" "$PLANT_SINCE" scripts/gates.sh)" "$(rs_line "$W/st5-same.out" 1)"
rs_eq "HARNESS-120 AC-5: the queue directory holds exactly the files, byte for byte, it held before" "$qbefore" "$(snapdir "$Q")"
rs_eq "HARNESS-120 AC-5: the tree's .claude/state holds exactly the files, byte for byte, it held before" "$sbefore" \
  "$(snapdir "$B/.claude/state")"

new_case; rm -rf "$W/q-absent"; RQ_DIR="$W/q-absent"
rs_ask "$B" st5-absent
RQ_DIR="$Q"
rs_expect "HARNESS-120 AC-5 an absent queue directory" st5-absent "$(s_idle "$B")" "$(s_free "$W/q-absent/run-queue.lock")"
rs_eq "HARNESS-120 AC-5: and the queue directory is still absent afterwards" absent "$(present "$W/q-absent")"

new_case; RQ_DIR="<unset>"; RQ_NOHOME=1
rs_ask "$B" st5-nohome
rq_defaults
rs_expect "HARNESS-120 AC-5 neither HARNESS_RUN_QUEUE_DIR nor HOME" st5-nohome "$(s_idle "$B")" "$S_NOHOME"

# usage_case <label> <arg>...
usage_case() {
  local lbl="$1"; shift
  new_case
  rs_ask "$B" "$lbl" "$@"
  rs_eq "$lbl: exits 2" 2 "$ASK_RC"
  rs_eq "$lbl: prints exactly the usage line on stderr" "usage: bash scripts/run-status.sh [--all]" "$(readf "$W/$lbl.err")"
  rs_eq "$lbl: and nothing on stdout" "" "$(readf "$W/$lbl.out")"
}
usage_case "HARNESS-120 AC-5 an argument (--help)" --help
usage_case "HARNESS-120 AC-5 an argument (a tree path)" "$A"
usage_case "HARNESS-120 AC-5 an empty argument" ""

# ---------------------------------------------------------------------------
describe "HARNESS-120 AC-6  the queue is named where an agent reads first, each needle inside its region"

NEVER="Never stop a queued run to requeue it"
FENCE='```'
# md_section <file> <heading>   From the heading line to the next ## heading.
md_section() { awk -v h="$2" 'f && index($0, "## ") == 1 { exit } $0 == h { f = 1 } f' "$1" 2>/dev/null; }
# first_fence   The first fenced block of stdin, its fences excluded.
first_fence() { awk -v t="$FENCE" 'index($0, t) == 1 { if (f) exit; f = 1; next } f'; }
# md_between <file> <start prefix> <end prefix>
md_between() { awk -v s="$2" -v e="$3" 'f && index($0, e) == 1 { exit } !f && index($0, s) == 1 { f = 1 } f' "$1" 2>/dev/null; }
# lock_comment <file>   The comment block holding the HARNESS-034 run-lock
# heading, to the first non-comment line, each line's leading # stripped.
lock_comment() {
  awk 'f && index($0, "#") != 1 { exit }
       !f && index($0, "#") == 1 && $0 ~ /[Rr][Uu][Nn] [Ll][Oo][Cc][Kk] \(HARNESS-034\)/ { f = 1 }
       f { sub(/^#+ ?/, ""); print }' "$1" 2>/dev/null
}
# has <needle>   yes if stdin, each line trimmed and the lines joined by one
# space, contains the needle as a fixed string: a sentence wrapped across two
# lines of prose is still the same words.
has() {
  awk -v n="$1" '{ sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); j = j s $0; s = " " }
                 END { if (index(j, n) > 0) printf "yes"; else printf "no" }'
}
# tool_entries <file>   The frontmatter allowed-tools: line, one entry per line.
tool_entries() {
  awk 'NR == 1 && $0 == "---" { f = 1; next }
       f && $0 == "---" { exit }
       f && index($0, "allowed-tools:") == 1 { sub(/^allowed-tools:[ ]*/, ""); n = split($0, a, /,[ ]*/); for (i = 1; i <= n; i++) print a[i] }' "$1" 2>/dev/null
}

md_section "$REPO_ROOT/CLAUDE.md" "## Running things" > "$W/rt.sect"
first_fence < "$W/rt.sect" > "$W/rt.fence"
assert_eq "HARNESS-120 AC-6 (a): CLAUDE.md's Running things command block has one line beginning bash scripts/run-status.sh, then a # comment" 1 \
  "$(count_span "bash scripts/run-status.sh" '^ +# [^ ]' "$W/rt.fence")"
assert_eq "HARNESS-120 AC-6 (a): CLAUDE.md's Running things section names run-queue.lock" yes "$(has run-queue.lock < "$W/rt.sect")"
assert_eq "HARNESS-120 AC-6 (a): CLAUDE.md's Running things section carries: $NEVER" yes "$(has "$NEVER" < "$W/rt.sect")"

md_between "$REPO_ROOT/.claude/commands/advance-story.md" "**GREEN → GATES.**" "**GATES → REVIEW.**" > "$W/adv.gg"
assert_eq "HARNESS-120 AC-6 (b): /advance-story's GREEN → GATES brief names bash scripts/run-status.sh" yes \
  "$(has "bash scripts/run-status.sh" < "$W/adv.gg")"
assert_eq "HARNESS-120 AC-6 (b): /advance-story's GREEN → GATES brief carries: $NEVER" yes "$(has "$NEVER" < "$W/adv.gg")"
assert_eq "HARNESS-120 AC-6 (b): /advance-story's GREEN → GATES brief tells it to report queued behind" yes \
  "$(has "queued behind" < "$W/adv.gg")"

md_section "$REPO_ROOT/.claude/agents/feature-developer.md" "## Run and report" > "$W/fd.rr"
assert_eq "HARNESS-120 AC-6 (c): feature-developer.md's Run and report names bash scripts/run-status.sh" yes \
  "$(has "bash scripts/run-status.sh" < "$W/fd.rr")"
assert_eq "HARNESS-120 AC-6 (c): feature-developer.md's Run and report carries: $NEVER" yes "$(has "$NEVER" < "$W/fd.rr")"

for cf in advance-story complete-story; do
  tool_entries "$REPO_ROOT/.claude/commands/$cf.md" > "$W/$cf.tools"
  assert_eq "HARNESS-120 AC-6 (d): /$cf's allowed-tools line carries the entry Bash(bash scripts/run-status.sh:*), exactly once" 1 \
    "$(count_line 'Bash(bash scripts/run-status.sh:*)' "$W/$cf.tools")"
done

for sf in gates.sh selftest.sh; do
  lock_comment "$REPO_ROOT/scripts/$sf" > "$W/$sf.lockc"
  assert_eq "HARNESS-120 AC-6 (e): the run-lock comment in scripts/$sf names scripts/run-queue.sh" yes \
    "$(has scripts/run-queue.sh < "$W/$sf.lockc")"
  assert_eq "HARNESS-120 AC-6 (e): the run-lock comment in scripts/$sf is there and no longer says it never waits" "found no" \
    "$(if [ -s "$W/$sf.lockc" ]; then printf found; else printf missing; fi) $(has "it never waits" < "$W/$sf.lockc")"
done


# ===========================================================================
# HARNESS-121  one command lists every run waiting in the machine queue
# (Contract C-1, C-2, C-4, C-5). A run that begins to wait writes
# <queue dir>/run-queue.waiter.<pid> and removes it when it stops waiting;
# `bash scripts/run-status.sh --all` prints the no-argument lines, then one
# `waiting` line per BELIEVED record, a count line and the `predates` line.
# Every line is C-2's, compared whole; stdout and stderr apart.
#
# RED: --all is a usage error and no record is written. Every answer
# assertion fails ONE assertion per expected line whether --all is supported
# or not, and every loop is over a fixed list, so the executed count is the
# same in RED and GREEN. An assertion that a record is ABSENT is made only
# beside the case's own sighting of it ("seen absent", C-2 "Presence before
# absence"), and the byte-for-byte assertions that a reader or a sweep left
# something alone are made only beside the evidence that the reader answered
# or the sweep ran - so none of them passes on a tree that writes nothing.
#
# D, "a fourth tree where nothing runs", is the --changed tree Z: new_case
# resets it, and no HARNESS-121 case runs anything in it but run-status.sh.
# ===========================================================================

D="$Z"

# Live processes the planted cases own: eight, so that every planted record
# of AC-3 (b) has a pid of its own and a combined case can hold all of them.
for _v in WL1 WL2 WL3 WL4 WL5 WL6 WL7 WL8; do
  hold_until_killed "$_v"; eval "BG=\"\$BG \$$_v\""
done

wrec()    { printf '%s/run-queue.waiter.%s' "$Q" "$1"; }   # <pid or name suffix>
has_rec() { [ -f "$(wrec "$1")" ]; }
# wrecs   The waiter records and their .tmp files in $Q, by name, or none.
wrecs() {
  local f o=""
  for f in "$Q"/run-queue.waiter.*; do [ -e "$f" ] && o="$o ${f##*/}"; done
  o="${o# }"; printf '%s' "${o:-none}"
}
# rplant <name suffix> <pid value|-none-> <since> <root> <command>   A
# record by hand, in C-1's order: pid, since, command, root.
rplant() {
  mkdir -p "$Q"
  { [ "$2" = -none- ] || printf 'pid\t%s\n' "$2"
    printf 'since\t%s\ncommand\t%s\nroot\t%s\n' "$3" "$5" "$4"; } > "$(wrec "$1")"
}
# snaptree <dir>   Every regular file under <dir>, recursively (gate-logs/
# included), path and exact bytes; no-dir if absent.
snaptree() {
  [ -d "$1" ] || { printf 'no-dir'; return 0; }
  ( cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do printf '%s:' "$f"; cat "$f"; printf '|'; done )
}
# states5   The four trees' .claude/state, for AC-5.
states5() {
  printf '%s#%s#%s#%s' "$(snaptree "$A/.claude/state")" "$(snaptree "$B/.claude/state")" \
    "$(snaptree "$C/.claude/state")" "$(snaptree "$D/.claude/state")"
}
# same_file <a> <b>
same_file() { if cmp -s "$1" "$2"; then printf same; else printf differs; fi; }
# utc_after <since>   0 once the UTC second is past <since>.
utc_after() { [ "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \> "$1" ]; }
# since_of <answer file> <pid>   The since of the waiting line for <pid>.
since_of() {
  awk -v p="run-status: waiting: pid $2, since " 'index($0, p) == 1 { s = substr($0, length(p) + 1); sub(/, in .*/, "", s); print s; exit }' "$1" 2>/dev/null
}
# since_q1 <answer file>   The since of a no-argument queued line.
since_q1() {
  awk 'index($0, "run-status: queued: pid ") == 1 { s = $0; sub(/^run-status: queued: pid [0-9]+, waiting since /, "", s); sub(/: .*/, "", s); print s; exit }' "$1" 2>/dev/null
}

# C-2's list lines.
s_wait()  { printf 'run-status: waiting: pid %s, since %s, in %s: %s' "$1" "$2" "$3" "$4"; }   # P S R C
S_NONE='run-status: nothing is waiting in the machine queue.'
S_ONE='run-status: 1 run is waiting.'
s_many()  { printf 'run-status: %s runs are waiting, listed in the order they began to wait. Whichever polls first after the holder ends starts next; that need not be the first listed.' "$1"; }
S_PRED='run-status: a run in a tree whose harness predates this list waits without appearing in it.'

# ---------------------------------------------------------------------------
describe "HARNESS-121 AC-1  asked with --all in the holder, in each waiter and in an idle tree: every waiter, in the order they began to wait"

new_case
hold_run hp "$A" w1-A scripts/gates.sh
assert_eq "HARNESS-121 AC-1: precondition: A's full gates.sh holds the queue, its work in progress" yes "$HOLDING"
rq_run bp "$B" w1-B scripts/gates.sh
wait_until 60 is_queued "$W/w1-B.err"
if wait_until 5 has_rec "$bp"; then seenB=seen; cp "$(wrec "$bp")" "$W/w1-B.rec"; else seenB=never-written; : > "$W/w1-B.rec"; fi
wait_until 5 has_marker "$B"
SINCE_B="$(rec_field "$(marker "$B")" since)"
# C starts only once B's record is there and the UTC second has moved on
# (C-2): bounded waits on the condition, never a fixed sleep.
wait_until 5 utc_after "$SINCE_B"
rq_run cp_ "$C" w1-C scripts/gates.sh
wait_until 60 is_queued "$W/w1-C.err"
if wait_until 5 has_rec "$cp_"; then seenC=seen; else seenC=never-written; fi
wait_until 5 has_marker "$C"
SINCE_C="$(rec_field "$(marker "$C")" since)"
assert_eq "HARNESS-121 AC-1: precondition: B and then C have each printed their run-queue: queued: line" "1 1" \
  "$(count_line "$(q1 scripts/gates.sh)" "$W/w1-B.err") $(count_line "$(q1 scripts/gates.sh)" "$W/w1-C.err")"
assert_eq "HARNESS-121 AC-1: precondition: B began to wait in an earlier UTC second than C" yes \
  "$(if [ -n "$SINCE_B" ] && [ "$SINCE_B" \< "$SINCE_C" ]; then printf yes; else printf 'no (%s / %s)' "$SINCE_B" "$SINCE_C"; fi)"
assert_eq "HARNESS-121 AC-1: precondition: B's and C's run.lock record B's and C's pids, the queue lock A's" "$bp $cp_ $hp" \
  "$(rec_field "$B/.claude/state/run.lock" pid) $(rec_field "$C/.claude/state/run.lock" pid) $(rec_field "$QL" pid)"

assert_eq "HARNESS-121 C-1: while B waits, the queue directory holds run-queue.waiter.<B's pid>" seen "$seenB"
assert_eq "HARNESS-121 C-1: the record is four TAB-separated lines: pid, since, command, root" \
  "pid since command root" "$(rec_keys "$W/w1-B.rec")"
assert_eq "HARNESS-121 C-1: the record's pid is the waiting script's own pid" "$bp" "$(rec_field "$W/w1-B.rec" pid)"
assert_eq "HARNESS-121 C-1: the record's since is the since of B's run.queued, to the second (one date call)" \
  "$SINCE_B" "$(rec_field "$W/w1-B.rec" since)"
assert_eq "HARNESS-121 C-1: the record's command and root are the strings the queue lock would record" \
  "scripts/gates.sh|$B" "$(rec_field "$W/w1-B.rec" command)|$(rec_field "$W/w1-B.rec" root)"

cp "$QL" "$W/w1.qrec" 2>/dev/null || : > "$W/w1.qrec"
T2="$(rec_field "$W/w1.qrec" started)"; R2="$(rec_field "$W/w1.qrec" root)"; C2="$(rec_field "$W/w1.qrec" command)"
AT="$(rec_field "$A/.claude/state/run.lock" started)"; AC="$(rec_field "$A/.claude/state/run.lock" command)"
BC="$(rec_field "$B/.claude/state/run.lock" command)"; CC="$(rec_field "$C/.claude/state/run.lock" command)"
WB="$(s_wait "$bp" "$SINCE_B" "$B" scripts/gates.sh)"
WC="$(s_wait "$cp_" "$SINCE_C" "$C" scripts/gates.sh)"
HELD="$(s_held "$hp" "$T2" "$R2" "$C2")"

rs_ask "$A" w1-askA --all
rs_expect "HARNESS-121 AC-1 --all in A (the holder)" w1-askA \
  "$(s_run "$hp" "$AT" "$AC")" "$HELD" "$WB" "$WC" "$(s_many 2)" "$S_PRED"
rs_ask "$B" w1-askB --all
rs_expect "HARNESS-121 AC-1 --all in B (the first waiter)" w1-askB \
  "$(s_q1 "$bp" "$SINCE_B" "$BC")" "$(s_q2 "$hp" "$T2" "$R2" "$C2")" "$S_Q3" "$HELD" "$WB" "$WC" "$(s_many 2)" "$S_PRED"
rs_ask "$C" w1-askC --all
rs_expect "HARNESS-121 AC-1 --all in C (the second waiter)" w1-askC \
  "$(s_q1 "$cp_" "$SINCE_C" "$CC")" "$(s_q2 "$hp" "$T2" "$R2" "$C2")" "$S_Q3" "$HELD" "$WB" "$WC" "$(s_many 2)" "$S_PRED"
rs_ask "$D" w1-askD --all
rs_expect "HARNESS-121 AC-1 --all in D (nothing runs there)" w1-askD \
  "$(s_idle "$D")" "$HELD" "$WB" "$WC" "$(s_many 2)" "$S_PRED"
rs_ask "$B" w1-askB0
rs_eq "HARNESS-121 AC-1: the since on B's waiting line is the since on B's own no-argument queued line" \
  "$(since_q1 "$W/w1-askB0.out")" "$(since_of "$W/w1-askD.out" "$bp")"
assert_eq "HARNESS-121 AC-1: neither B's nor C's work has started after all four answers, and A is still running" \
  "absent absent alive" "$(present "$B/m/k/started") $(present "$C/m/k/started") $(is_alive "$hp")"

# ---------------------------------------------------------------------------
describe "HARNESS-121 AC-2  one waiter through: held by it, the other listed alone; all ended: nothing waits, no record left"

touch "$B/m/k/hold" "$C/m/k/hold"
touch "$A/m/k/release"
wait_bounded "$hp" 60
assert_eq "HARNESS-121 AC-2: precondition: A finishes, exit 0" 0 "$WRC"
either_started() { is_started "$B" || is_started "$C"; }
wait_until 60 either_started
if is_started "$B"; then fp="$bp"; ft="$B"; fseen="$seenB"; op="$cp_"; ot="$C"; osince="$SINCE_C"
elif is_started "$C"; then fp="$cp_"; ft="$C"; fseen="$seenC"; op="$bp"; ot="$B"; osince="$SINCE_B"
else fp=none; ft=none; fseen=never-written; op=none; ot=none; osince=none; fi
assert_eq "HARNESS-121 AC-2: precondition: exactly one of B and C has started its work, through the queue" 1 \
  "$(( $(if is_started "$B"; then echo 1; else echo 0; fi) + $(if is_started "$C"; then echo 1; else echo 0; fi) ))"
cp "$QL" "$W/w2.qrec" 2>/dev/null || : > "$W/w2.qrec"
rs_ask "$D" w2-askD --all
rs_expect "HARNESS-121 AC-2 --all in D, one waiter through" w2-askD \
  "$(s_idle "$D")" "$(s_held "$fp" "$(rec_field "$W/w2.qrec" started)" "$ft" scripts/gates.sh)" \
  "$(s_wait "$op" "$osince" "$ot" scripts/gates.sh)" "$S_ONE" "$S_PRED"
assert_eq "HARNESS-121 AC-2: the queue directory holds no record for the one that started (seen while it waited)" \
  "seen absent" "$fseen $(present "$(wrec "$fp")")"
touch "$B/m/k/release" "$C/m/k/release"
wait_bounded "$bp" 60; w2b="$WRC $WTO"
wait_bounded "$cp_" 60; w2c="$WRC $WTO"
assert_eq "HARNESS-121 AC-2: precondition: B and C both finish within the bound, with the status they have alone ($SOLO_GATES)" \
  "$SOLO_GATES no $SOLO_GATES no" "$w2b $w2c"
rs_ask "$D" w2-endD --all
rs_expect "HARNESS-121 AC-2 --all in D after all three ended" w2-endD "$(s_idle "$D")" "$(s_free "$QL")" "$S_NONE" "$S_PRED"
rs_ask "$B" w2-endB --all
rs_expect "HARNESS-121 AC-2 --all in B after all three ended" w2-endB "$(s_idle "$B")" "$(s_free "$QL")" "$S_NONE" "$S_PRED"
assert_eq "HARNESS-121 AC-2: the queue directory holds no record at all, each having been seen while its run waited" \
  "seen seen none" "$seenB $seenC $(wrecs)"

# ---------------------------------------------------------------------------
describe "HARNESS-121 AC-3 (a)  a waiter sent TERM exits 143, takes its record with it, and is no longer listed"

# term_record <label> <script>   B queued behind a planted live holder.
term_record() {
  local lbl="$1" s="$2" p seen sn
  new_case
  qplant "$LIVE1" "$PLANT_STARTED" scripts/gates.sh "$A"
  rq_run p "$B" "$lbl" "scripts/$s"
  wait_until 60 is_queued "$W/$lbl.err"
  assert_eq "$lbl: precondition: the run is queued" 1 "$(count_line "$(q1 "scripts/$s")" "$W/$lbl.err")"
  if wait_until 5 has_rec "$p"; then seen=seen; else seen=never-written; fi
  wait_until 5 has_marker "$B"; sn="$(rec_field "$(marker "$B")" since)"
  rs_ask "$D" "$lbl-before" --all
  rs_expect "$lbl: --all in D while it waits" "$lbl-before" \
    "$(s_idle "$D")" "$(s_held "$LIVE1" "$PLANT_STARTED" "$A" scripts/gates.sh)" \
    "$(s_wait "$p" "$sn" "$B" "scripts/$s")" "$S_ONE" "$S_PRED"
  kill -TERM "$p" 2>/dev/null
  wait_bounded "$p" 10
  assert_eq "$lbl: its record was seen while it waited; it exits 143 on TERM; the record is gone" "seen 143 absent" \
    "$seen $WRC $(present "$(wrec "$p")")"
  rs_ask "$D" "$lbl-after" --all
  rs_expect "$lbl: --all in D once it has exited" "$lbl-after" \
    "$(s_idle "$D")" "$(s_held "$LIVE1" "$PLANT_STARTED" "$A" scripts/gates.sh)" "$S_NONE" "$S_PRED"
}
term_record "HARNESS-121 AC-3 (a) gates.sh waiter" gates.sh
term_record "HARNESS-121 AC-3 (a) selftest.sh waiter" selftest.sh

# ---------------------------------------------------------------------------
describe "HARNESS-121 AC-3 (b)  listed means a live waiter its tree's run.lock records, never a file: one rule per planted record"

assert_eq "HARNESS-121 AC-3 (b): precondition: the dead pid is gone and the eight planted pids are alive" \
  "gone alive alive alive alive alive alive alive alive" \
  "$(is_alive "$DEAD") $(is_alive "$WL1") $(is_alive "$WL2") $(is_alive "$WL3") $(is_alive "$WL4") $(is_alive "$WL5") $(is_alive "$WL6") $(is_alive "$WL7") $(is_alive "$WL8")"

# The planted world. The queue is held by WL1, whose recorded root WR/h has a
# run.lock recording WL1 too. Each bad record has a root of its own; the
# control record CTL shares WR/2 with the rule-5 record, whose pid that
# run.lock does not record.
WR="$W/wr"
WR_SINCE="2026-01-02T03:06:07Z"
HELD_PLANT="$(s_held "$WL1" "$PLANT_STARTED" "$WR/h" "scripts/selftest.sh ghost")"
wr_world() {
  new_case
  rm -rf "$WR"; mkdir -p "$WR/1" "$WR/2" "$WR/3" "$WR/5" "$WR/6" "$WR/7" "$WR/h"
  qplant "$WL1" "$PLANT_STARTED" "scripts/selftest.sh ghost" "$WR/h"
  lplant "$WR/h" "$WL1" "$PLANT_STARTED" "scripts/selftest.sh ghost"
  lplant "$WR/1" "$DEAD" "$PLANT_STARTED" scripts/gates.sh
  lplant "$WR/2" "$WL3"  "$PLANT_STARTED" scripts/gates.sh
  lplant "$WR/5" "$WL5"  "$PLANT_STARTED" scripts/gates.sh
  lplant "$WR/6" "$WL7"  "$PLANT_STARTED" scripts/gates.sh
  lplant "$WR/7" "$WL8"  "$PLANT_STARTED" scripts/gates.sh
}
# The seven, each failing exactly one rule of C-2 and passing the other four.
r_dead()    { rplant "$DEAD"     "$DEAD"     "$WR_SINCE" "$WR/1" scripts/gates.sh; }   # rule 3: not alive
r_notlock() { rplant "$WL2"      "$WL2"      "$WR_SINCE" "$WR/2" scripts/gates.sh; }   # rule 5: run.lock records WL3
r_nolock()  { rplant "$WL4"      "$WL4"      "$WR_SINCE" "$WR/3" scripts/gates.sh; }   # rule 5: no run.lock in WR/3
r_holder()  { rplant "$WL1"      "$WL1"      "$WR_SINCE" "$WR/h" scripts/gates.sh; }   # rule 4: the queue holder
r_nopid()   { rplant "$WL5"      not-a-pid   "$WR_SINCE" "$WR/5" scripts/gates.sh; }   # rule 2: no numeric pid
r_differ()  { rplant "$WL6"      "$WL7"      "$WR_SINCE" "$WR/6" scripts/gates.sh; }   # rule 2: name WL6, pid WL7
r_tmp()     { rplant "$WL8.tmp"  "$WL8"      "$WR_SINCE" "$WR/7" scripts/gates.sh; }   # rule 1: a .tmp
r_ctl()     { rplant "$WL3"      "$WL3"      "$WR_SINCE" "$WR/2" "scripts/gates.sh ctl"; }   # passes all five

# bad_case <label> <planter>...   The world, these records; --all in D lists none.
bad_case() {
  local lbl="$1" f; shift
  wr_world
  for f in "$@"; do "$f"; done
  rs_ask "$D" "$lbl" --all
  rs_expect "$lbl" "$lbl" "$(s_idle "$D")" "$HELD_PLANT" "$S_NONE" "$S_PRED"
}
bad_case "HARNESS-121 AC-3 (b) rule 3: a record whose pid is not running" r_dead
bad_case "HARNESS-121 AC-3 (b) rule 5: a live pid its tree's run.lock does not record" r_notlock
bad_case "HARNESS-121 AC-3 (b) rule 5: a live pid whose tree has no run.lock" r_nolock
bad_case "HARNESS-121 AC-3 (b) rule 4: the pid that holds the queue, beside a run.lock recording it" r_holder
bad_case "HARNESS-121 AC-3 (b) rule 2: a record with no numeric pid" r_nopid
bad_case "HARNESS-121 AC-3 (b) rule 2: a record whose file name and recorded pid differ" r_differ
bad_case "HARNESS-121 AC-3 (b) rule 1: a .tmp record" r_tmp
bad_case "HARNESS-121 AC-3 (b) all seven together" r_dead r_notlock r_nolock r_holder r_nopid r_differ r_tmp

describe "HARNESS-121 C-2  the planted waiter that IS believed: the control for the seven above"

wr_world; r_ctl
rs_ask "$D" w3-ctl --all
rs_expect "HARNESS-121 C-2 the control record alone is listed" w3-ctl \
  "$(s_idle "$D")" "$HELD_PLANT" "$(s_wait "$WL3" "$WR_SINCE" "$WR/2" "scripts/gates.sh ctl")" "$S_ONE" "$S_PRED"
wr_world; r_dead; r_notlock; r_nolock; r_holder; r_nopid; r_differ; r_tmp; r_ctl
rs_ask "$D" w3-ctl8 --all
rs_expect "HARNESS-121 C-2 the seven and the control: only the control is listed" w3-ctl8 \
  "$(s_idle "$D")" "$HELD_PLANT" "$(s_wait "$WL3" "$WR_SINCE" "$WR/2" "scripts/gates.sh ctl")" "$S_ONE" "$S_PRED"

describe "HARNESS-121 C-2  believed records in ascending order of since, ties in ascending numeric pid"

if [ "$WL4" -gt "$WL5" ]; then OBIG="$WL4"; OSMALL="$WL5"; else OBIG="$WL5"; OSMALL="$WL4"; fi
o_world() {
  wr_world; rm -rf "$WR/o1" "$WR/o2"
  lplant "$WR/o1" "$OBIG"   "$PLANT_STARTED" scripts/gates.sh
  lplant "$WR/o2" "$OSMALL" "$PLANT_STARTED" scripts/gates.sh
}
# The larger pid began to wait first: since order is not pid order.
o_world
rplant "$OBIG"   "$OBIG"   "2026-01-02T03:06:08Z" "$WR/o1" scripts/gates.sh
rplant "$OSMALL" "$OSMALL" "2026-01-02T03:06:09Z" "$WR/o2" scripts/gates.sh
rs_ask "$D" w3-ord --all
rs_expect "HARNESS-121 C-2 two waiters, the larger pid earlier: listed by since" w3-ord \
  "$(s_idle "$D")" "$HELD_PLANT" \
  "$(s_wait "$OBIG" "2026-01-02T03:06:08Z" "$WR/o1" scripts/gates.sh)" \
  "$(s_wait "$OSMALL" "2026-01-02T03:06:09Z" "$WR/o2" scripts/gates.sh)" "$(s_many 2)" "$S_PRED"
o_world
rplant "$OBIG"   "$OBIG"   "2026-01-02T03:06:08Z" "$WR/o1" scripts/gates.sh
rplant "$OSMALL" "$OSMALL" "2026-01-02T03:06:08Z" "$WR/o2" scripts/gates.sh
rs_ask "$D" w3-tie --all
rs_expect "HARNESS-121 C-2 two waiters in the same second: the smaller pid first" w3-tie \
  "$(s_idle "$D")" "$HELD_PLANT" \
  "$(s_wait "$OSMALL" "2026-01-02T03:06:08Z" "$WR/o2" scripts/gates.sh)" \
  "$(s_wait "$OBIG" "2026-01-02T03:06:08Z" "$WR/o1" scripts/gates.sh)" "$(s_many 2)" "$S_PRED"

# ---------------------------------------------------------------------------
describe "HARNESS-121 AC-3 (c)  the next waiter sweeps dead records by name, and leaves a live waiter's alone"

new_case
qplant "$LIVE1" "$PLANT_STARTED" scripts/gates.sh "$A"
rplant "$DEAD"     "$DEAD" "$WR_SINCE" "$W/wr/1" scripts/gates.sh
rplant "$DEAD.tmp" "$DEAD" "$WR_SINCE" "$W/wr/1" scripts/gates.sh
rplant abc         "$WL2"  "$WR_SINCE" "$W/wr/2" scripts/gates.sh
rplant "$WL6"      "$WL6"  "$WR_SINCE" "$W/wr/6" "scripts/gates.sh live"
rplant "$WL7.tmp"  "$WL7"  "$WR_SINCE" "$W/wr/6" "scripts/gates.sh live"
cp "$(wrec "$WL6")" "$W/w4-live.rec"; cp "$(wrec "$WL7.tmp")" "$W/w4-live.tmp"
assert_eq "HARNESS-121 AC-3 (c): precondition: the planted records are in the queue directory" \
  "present present present present present" \
  "$(present "$(wrec "$DEAD")") $(present "$(wrec "$DEAD.tmp")") $(present "$(wrec abc)") $(present "$(wrec "$WL6")") $(present "$(wrec "$WL7.tmp")")"
rq_run sp "$B" w4-B scripts/gates.sh
wait_until 60 is_queued "$W/w4-B.err"
if wait_until 5 has_rec "$sp"; then sw=seen; else sw=never-written; fi
assert_eq "HARNESS-121 AC-3 (c): the new waiter wrote its record, and the dead pid's record is gone" "seen absent" \
  "$sw $(present "$(wrec "$DEAD")")"
assert_eq "HARNESS-121 AC-3 (c): and so is the dead pid's .tmp" "seen absent" "$sw $(present "$(wrec "$DEAD.tmp")")"
assert_eq "HARNESS-121 AC-3 (c): and so is a record whose name is not all digits" "seen absent" "$sw $(present "$(wrec abc)")"
assert_eq "HARNESS-121 AC-3 (c): the live waiter's record is byte for byte what it was" "seen same" \
  "$sw $(same_file "$W/w4-live.rec" "$(wrec "$WL6")")"
assert_eq "HARNESS-121 AC-3 (c): a live pid's .tmp is byte for byte what it was" "seen same" \
  "$sw $(same_file "$W/w4-live.tmp" "$(wrec "$WL7.tmp")")"
# Every run-queue: line B printed is the queued line, its two companions or a
# heartbeat: nothing about the sweep.
other_rq() {
  local a b c
  a="$(q1 scripts/gates.sh)"; b="$(q2 "$LIVE1" "$PLANT_STARTED" "$A" scripts/gates.sh)"; c="$(q3 "$LIVE1" "$QL")"
  rq_lines "$1" | HBR="$HB_RE" awk -v a="$a" -v b="$b" -v c="$c" -v h="$(hb_prefix "$LIVE1" "$A" scripts/gates.sh)" '
    $0 == a || $0 == b || $0 == c { next }
    index($0, h) == 1 && substr($0, length(h) + 1) ~ ENVIRON["HBR"] { next }
    { n++ } END { print n + 0 }'
}
assert_eq "HARNESS-121 AC-3 (c): B printed its queued line once, and no run-queue: line says anything about either record" \
  "seen 1 0" "$sw $(count_line "$(q1 scripts/gates.sh)" "$W/w4-B.err") $(other_rq "$W/w4-B.err")"
kill -TERM "$sp" 2>/dev/null; wait_bounded "$sp" 10

# ---------------------------------------------------------------------------
describe "HARNESS-121 AC-4 (a), (b)  a run beside the holder is running, never listed, and neither writes a record"

new_case
hold_run hp "$A" w5-A scripts/gates.sh
assert_eq "HARNESS-121 AC-4: precondition: A's full gates.sh holds the queue, its work in progress" yes "$HOLDING"
cp "$QL" "$W/w5.qrec" 2>/dev/null || : > "$W/w5.qrec"
T2="$(rec_field "$W/w5.qrec" started)"

# beside_list <label> <script> [args...]   B started beside A, held; --all in B.
beside_list() {
  local lbl="$1" bp_; shift
  rm -rf "$B/m/k"; mkdir -p "$B/m/k"; rm -f "$B"/.claude/state/run.lock* "$(marker "$B")"
  hold_run bp_ "$B" "$lbl" "$@"
  assert_eq "$lbl: precondition: B's run is in progress beside A, held" "yes alive" "$HOLDING $(is_alive "$hp")"
  rs_ask "$B" "$lbl-ask" --all
  rs_expect "$lbl" "$lbl-ask" \
    "$(s_run "$bp_" "$(rec_field "$B/.claude/state/run.lock" started)" "$(rec_field "$B/.claude/state/run.lock" command)")" \
    "$(s_held "$hp" "$T2" "$A" scripts/gates.sh)" "$S_NONE" "$S_PRED"
  assert_eq "$lbl: at that moment the count line says nothing is waiting, and the queue directory holds no record (A's or B's)" \
    "$S_NONE|none" "$(rs_line "$W/$lbl-ask.out" 3)|$(wrecs)"
  touch "$B/m/k/release"; wait_bounded "$bp_" 60
}
beside_list "HARNESS-121 AC-4 (a) gates.sh --fast beside the holder" scripts/gates.sh --fast
RQ_MODE=off
beside_list "HARNESS-121 AC-4 (b) full gates.sh, HARNESS_RUN_QUEUE=off, beside the holder" scripts/gates.sh
RQ_MODE=""
touch "$A/m/k/release"; wait_bounded "$hp" 60
assert_eq "HARNESS-121 AC-4: precondition: A then finishes, exit 0" 0 "$WRC"

# ---------------------------------------------------------------------------
describe "HARNESS-121 AC-4 (c)  a waiter that goes on without the queue takes its record with it and is not listed"

# Built as HARNESS-120's R-1 case: a planted live holder, B queued, the queue
# lock then a directory, so B's next poll takes the `2)` exit and B works.
new_case
qplant "$LIVE1" "$PLANT_STARTED" "scripts/selftest.sh ghost" "/ghost/tree"
touch "$B/m/k/hold"
rq_run wp "$B" w6-B scripts/gates.sh
wait_until 60 is_queued "$W/w6-B.err"
if wait_until 5 has_rec "$wp"; then w6r=seen; else w6r=never-written; fi
assert_eq "HARNESS-121 AC-4 (c): precondition: B is queued behind the planted holder" 1 \
  "$(count_line "$(q1 scripts/gates.sh)" "$W/w6-B.err")"
rm -f "$QL"; mkdir "$QL"
wait_until 30 saw_cannot "$W/w6-B.err"
if wait_until 30 is_started "$B"; then w6s=yes; else w6s=no; fi
rm -f "$B/m/k/hold"
assert_eq "HARNESS-121 AC-4 (c): precondition: with the queue lock a directory, B prints the cannot-use line once and starts its work" "1 yes" \
  "$(count_line "$(cannot_line "$Q" scripts/gates.sh)" "$W/w6-B.err") $w6s"
assert_eq "HARNESS-121 AC-4 (c): B's record, seen while it waited, is gone once it goes on without the queue" "seen absent" \
  "$w6r $(present "$(wrec "$wp")")"
# The first two lines are the no-argument answer at this moment, read out.
rs_ask "$B" w6-ask0
W6L1="$(rs_line "$W/w6-ask0.out" 1)"; W6L2="$(rs_line "$W/w6-ask0.out" 2)"
rs_eq "HARNESS-121 AC-4 (c): precondition: the no-argument answer in B is running for B's pid, then 120's unreadable-lock line" \
  "$(s_run "$wp" "$(rec_field "$B/.claude/state/run.lock" started)" scripts/gates.sh)|$(s_unread "$QL")" "$W6L1|$W6L2"
rs_ask "$B" w6-ask --all
rs_expect "HARNESS-121 AC-4 (c) --all in B, working without the queue" w6-ask "$W6L1" "$W6L2" "$S_NONE" "$S_PRED"
touch "$B/m/k/release"; wait_bounded "$wp" 60
rmdir "$QL" 2>/dev/null

# ---------------------------------------------------------------------------
describe "HARNESS-121 R-1  a waiter whose run.queued cannot be written still takes its record with it"

# C-1: run_queue_unmark's "no marker" early return must not skip the record.
# B's run.queued is a directory before B queues, so the marker is never
# written and RUN_QUEUE_MARK stays empty; the planted holder's lock is then
# removed, so B takes the queue (the `0)` arm) and starts its work.
new_case
qplant "$LIVE1" "$PLANT_STARTED" scripts/gates.sh "$A"
mkdir -p "$(marker "$B")"
touch "$B/m/k/hold"
rq_run r1p "$B" r1-B scripts/gates.sh
wait_until 60 is_queued "$W/r1-B.err"
if wait_until 5 has_rec "$r1p"; then r1r=seen; else r1r=never-written; fi
r1m="$(if [ -d "$(marker "$B")" ] && [ -z "$(ls -A "$(marker "$B")" 2>/dev/null)" ]; then printf empty-dir; else printf not-empty-dir; fi)"
assert_eq "HARNESS-121 R-1: precondition: B is queued behind the planted holder" 1 \
  "$(count_line "$(q1 scripts/gates.sh)" "$W/r1-B.err")"
assert_eq "HARNESS-121 R-1: while B waits its record is in the queue directory, and its run.queued is still an empty directory (no marker written)" \
  "seen empty-dir" "$r1r $r1m"
rm -f "$QL"
if wait_until 30 is_started "$B"; then r1s=yes; else r1s=no; fi
assert_eq "HARNESS-121 R-1: B's record, seen while it waited, is gone once B takes the queue and starts its work, though no marker was written" \
  "seen yes absent" "$r1r $r1s $(present "$(wrec "$r1p")")"
rm -f "$B/m/k/hold"; touch "$B/m/k/release"; wait_bounded "$r1p" 60
rmdir "$(marker "$B")" 2>/dev/null

# ---------------------------------------------------------------------------
describe "HARNESS-121 AC-5 --all changes nothing, creates nothing, never waits; one argument only"

# A held queue, two live waiters (in A and C) and a dead record (in B).
new_case
rm -rf "$WR"; mkdir -p "$WR/h"
qplant "$WL1" "$PLANT_STARTED" "scripts/selftest.sh ghost" "$WR/h"
lplant "$A" "$WL2" "$PLANT_STARTED" scripts/gates.sh
lplant "$C" "$WL3" "$PLANT_STARTED" scripts/gates.sh
lplant "$B" "$DEAD" "$PLANT_STARTED" scripts/gates.sh
rplant "$WL2"  "$WL2"  "2026-01-02T03:06:10Z" "$A" scripts/gates.sh
rplant "$WL3"  "$WL3"  "2026-01-02T03:06:11Z" "$C" "scripts/selftest.sh --changed"
rplant "$DEAD" "$DEAD" "2026-01-02T03:06:09Z" "$B" scripts/gates.sh
q5="$(snapdir "$Q")"
s5="$(states5)"
rs_ask "$D" w7-same --all
rs_expect "HARNESS-121 AC-5 --all with a held queue, two live waiters and a dead record" w7-same \
  "$(s_idle "$D")" "$HELD_PLANT" \
  "$(s_wait "$WL2" "2026-01-02T03:06:10Z" "$A" scripts/gates.sh)" \
  "$(s_wait "$WL3" "2026-01-02T03:06:11Z" "$C" "scripts/selftest.sh --changed")" "$(s_many 2)" "$S_PRED"
if [ "$(rs_line "$W/w7-same.out" 5)" = "$(s_many 2)" ]; then a5=answered; else a5=not-answered; fi
assert_eq "HARNESS-121 AC-5: it answered, and the queue directory holds exactly the files, byte for byte, it held before" \
  "answered same" "$a5 $(if [ "$q5" = "$(snapdir "$Q")" ]; then printf same; else printf differs; fi)"
assert_eq "HARNESS-121 AC-5: it answered, and every tree's .claude/state holds exactly what it held before" "answered same" \
  "$a5 $(if [ "$s5" = "$(states5)" ]; then printf same; else printf differs; fi)"
assert_eq "HARNESS-121 AC-5: it answered, and the dead record is still there: the reader never sweeps" "answered present" \
  "$a5 $(present "$(wrec "$DEAD")")"

new_case; rm -rf "$W/q-absent"; RQ_DIR="$W/q-absent"
rs_ask "$D" w7-absent --all
RQ_DIR="$Q"
rs_expect "HARNESS-121 AC-5 --all with an absent queue directory" w7-absent \
  "$(s_idle "$D")" "$(s_free "$W/q-absent/run-queue.lock")" "$S_NONE" "$S_PRED"
assert_eq "HARNESS-121 AC-5: it answered, and the queue directory is still absent afterwards" "$S_NONE absent" \
  "$(rs_line "$W/w7-absent.out" 3) $(present "$W/q-absent")"

new_case; RQ_DIR="<unset>"; RQ_NOHOME=1
rs_ask "$D" w7-nohome --all
rq_defaults
rs_expect "HARNESS-121 AC-5 --all with neither HARNESS_RUN_QUEUE_DIR nor HOME: the cannot-be-located line is last" w7-nohome \
  "$(s_idle "$D")" "$S_NOHOME"

usage_case "HARNESS-121 AC-5 --all twice" --all --all
usage_case "HARNESS-121 AC-5 --all and a tree path" --all "$A"
usage_case "HARNESS-121 AC-5 a tree path and --all" "$A" --all
usage_case "HARNESS-121 AC-5 --ALL" --ALL
usage_case "HARNESS-121 AC-5 --all=" --all=
usage_case "HARNESS-121 AC-5 all, without dashes" all

# ---------------------------------------------------------------------------
describe "HARNESS-121 AC-6  the list is named in CLAUDE.md's Running things command block, on a line of its own"

assert_eq "HARNESS-121 AC-6: the Running things command block has one line beginning bash scripts/run-status.sh --all, then a # comment" 1 \
  "$(count_span "bash scripts/run-status.sh --all" '^ +# [^ ]' "$W/rt.fence")"
assert_eq "HARNESS-121 AC-6: it and HARNESS-120's no-argument line are two different lines of that block" 2 \
  "$(awk -v p="bash scripts/run-status.sh" -v q="bash scripts/run-status.sh --all" '
      (index($0, p) == 1 && substr($0, length(p) + 1) ~ /^ +# [^ ]/) ||
      (index($0, q) == 1 && substr($0, length(q) + 1) ~ /^ +# [^ ]/) { n++ } END { print n + 0 }' "$W/rt.fence" 2>/dev/null)"

summary "run-queue"
