#!/usr/bin/env bash
# scripts/run-status.sh - is this tree's harness run running, or queued, and
# behind what? And, with --all, which runs wait in the machine-wide queue?
# (HARNESS-120, HARNESS-121)
#
#   bash scripts/run-status.sh
#   bash scripts/run-status.sh --all
#
# A full gates.sh or selftest.sh, and every selftest.sh --changed, waits in the
# machine-wide queue (scripts/run-queue.sh) for any other such run on the
# machine. From outside, a run that waits there looks exactly like one that
# hangs. This answers which, for the tree whose copy is run - its root is this
# script's own, never $PWD and never CLAUDE_PROJECT_DIR; to ask about another
# worktree, run that worktree's copy.
#
# It prints the tree's state, then one line for the machine-wide queue:
#
#   idle      no .claude/state/run.lock, or one whose pid is not running (or
#             records none), which the next run reclaims
#   running   run.lock's pid is alive, and is not waiting in the queue
#   queued    run.lock's pid is alive AND .claude/state/run.queued records that
#             same pid: three lines - since when, behind what, and that this is
#             waiting, not hanging
#
# THE MARKER, <root>/.claude/state/run.queued, is written by run_queue_acquire
# when a run starts waiting, and removed when it takes the queue or exits. It
# is believed only for the live pid run.lock records, so one left behind by a
# waiter killed outright (SIGKILL) reads as what run.lock alone says. A marker
# that could not be written is not reported, and that run reads `running`.
#
# --all prints those lines unchanged, then one `waiting` line per believed
# waiter record (<queue dir>/run-queue.waiter.<n>, run-queue.sh's THE WAITER
# LIST) in ascending order of since, ties in ascending numeric pid, then a
# count line, then a line saying that a tree on an older release waits without
# appearing. Nothing follows a queue that cannot be located. A record is
# believed only when all five hold, with P its pid and R its root:
#
#   1. its name is run-queue.waiter.<n>, <n> all digits (a .tmp is never read)
#   2. P is numeric and equals <n>
#   3. P is alive
#   4. P is not the pid the queue lock records, when that one is alive
#   5. R/.claude/state/run.lock is a file whose pid is P
#
# The list is not the order of service: whichever waiter polls first after the
# holder ends starts next. A killed waiter whose pid has been recycled, in a
# tree that has not run since, is listed until the next waiter sweeps.
#
# The queue lock is found by run_queue_dir, the one rule run_queue_acquire
# uses, whatever HARNESS_RUN_QUEUE says: off is about joining, and this joins
# nothing. "Alive" is kill -0, with run-queue.sh's limits.
#
# Reads only: writes nothing, creates nothing (not the queue directory),
# removes nothing (not a dead record), takes no lock, never sleeps. Everything
# goes to stdout, exit 0; any argument list other than exactly --all is a
# usage error, exit 2. Bash 3.2, awk and coreutils only.

ALL=0
if [ "$#" -eq 1 ] && [ "$1" = --all ]; then
  ALL=1
elif [ "$#" -gt 0 ]; then
  printf 'usage: bash scripts/run-status.sh [--all]\n' >&2
  exit 2
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
if [ ! -f "$HERE/run-queue.sh" ] || ! . "$HERE/run-queue.sh"; then
  printf 'run-status: scripts/run-queue.sh is missing; cannot answer.\n' >&2
  exit 1
fi

LOCK="$ROOT/.claude/state/run.lock"
MARK="$ROOT/.claude/state/run.queued"

QLOCK=""
if QDIR="$(run_queue_dir)"; then QLOCK="$QDIR/run-queue.lock"; fi
QPID=""
if [ -n "$QLOCK" ] && [ -e "$QLOCK" ]; then QPID="$(run_queue_pid "$QLOCK")"; fi

# --- the tree ---------------------------------------------------------------
if [ ! -e "$LOCK" ]; then
  printf 'run-status: idle: no harness run holds %s.\n' "$ROOT"
else
  P="$(run_queue_pid "$LOCK")"
  if [ -z "$P" ]; then
    printf 'run-status: idle: .claude/state/run.lock records no pid; the next run reclaims it.\n'
  elif ! run_queue_alive "$P"; then
    printf 'run-status: idle: .claude/state/run.lock is left over from pid %s, which is no longer running; the next run reclaims it.\n' "$P"
  elif [ -f "$MARK" ] && [ "$(run_queue_pid "$MARK")" = "$P" ]; then
    printf 'run-status: queued: pid %s, waiting since %s: %s\n' \
      "$P" "$(run_queue_field "$MARK" since)" "$(run_queue_field "$LOCK" command)"
    if [ -n "$QPID" ] && [ "$QPID" != "$P" ] && run_queue_alive "$QPID"; then
      printf 'run-status:   behind pid %s, started %s, in %s: %s\n' "$QPID" \
        "$(run_queue_field "$QLOCK" started)" "$(run_queue_field "$QLOCK" root)" "$(run_queue_field "$QLOCK" command)"
    else
      printf 'run-status:   behind nothing at this instant: it takes the queue at its next poll.\n'
    fi
    printf 'run-status: this is waiting, not hanging: it starts by itself when that run ends. Never stop a queued run to requeue it.\n'
  else
    printf 'run-status: running: pid %s, started %s: %s\n' \
      "$P" "$(run_queue_field "$LOCK" started)" "$(run_queue_field "$LOCK" command)"
  fi
fi

# --- the machine-wide queue -------------------------------------------------
if [ -z "$QLOCK" ]; then
  printf 'run-status: machine queue: cannot be located: neither HARNESS_RUN_QUEUE_DIR nor HOME is set.\n'
elif [ ! -e "$QLOCK" ]; then
  printf 'run-status: machine queue: free (%s)\n' "$QLOCK"
elif [ -z "$QPID" ]; then
  printf 'run-status: machine queue: unreadable lock, no pid recorded; the next run that queues reclaims it (%s)\n' "$QLOCK"
elif run_queue_alive "$QPID"; then
  printf 'run-status: machine queue: held by pid %s, started %s, in %s: %s\n' "$QPID" \
    "$(run_queue_field "$QLOCK" started)" "$(run_queue_field "$QLOCK" root)" "$(run_queue_field "$QLOCK" command)"
else
  printf 'run-status: machine queue: stale lock from pid %s, which is no longer running; the next run that queues reclaims it (%s)\n' "$QPID" "$QLOCK"
fi

# --- --all: every run waiting in the machine-wide queue --------------------
[ "$ALL" = 1 ] && [ -n "$QLOCK" ] || exit 0
TAB="$(printf '\t')"
QALIVE=""
if [ -n "$QPID" ] && run_queue_alive "$QPID"; then QALIVE="$QPID"; fi
LIST=""
N=0
for WF in "$QDIR"/run-queue.waiter.*; do
  WN="${WF##*/run-queue.waiter.}"
  case "$WN" in ''|*[!0-9]*) continue ;; esac            # rule 1
  [ -f "$WF" ] || continue
  WP="$(run_queue_field "$WF" pid)"
  [ "$WP" = "$WN" ] || continue                           # rule 2
  run_queue_alive "$WP" || continue                       # rule 3
  [ "$WP" != "$QALIVE" ] || continue                      # rule 4
  WR="$(run_queue_field "$WF" root)"
  [ -n "$WR" ] && [ -f "$WR/.claude/state/run.lock" ] || continue
  [ "$(run_queue_pid "$WR/.claude/state/run.lock")" = "$WP" ] || continue   # rule 5
  WS="$(run_queue_field "$WF" since)"
  # since<TAB>pid<TAB>the line: sorted on the first two, printed from the third.
  LIST="$LIST$WS$TAB$WP${TAB}run-status: waiting: pid $WP, since $WS, in $WR: $(run_queue_field "$WF" command)
"
  N=$((N+1))
done
if [ "$N" -gt 0 ]; then
  printf '%s' "$LIST" | LC_ALL=C sort -t "$TAB" -k1,1 -k2,2n | cut -f3-
fi
case "$N" in
  0) printf 'run-status: nothing is waiting in the machine queue.\n' ;;
  1) printf 'run-status: 1 run is waiting.\n' ;;
  *) printf 'run-status: %s runs are waiting, listed in the order they began to wait. Whichever polls first after the holder ends starts next; that need not be the first listed.\n' "$N" ;;
esac
printf 'run-status: a run in a tree whose harness predates this list waits without appearing in it.\n'
exit 0
