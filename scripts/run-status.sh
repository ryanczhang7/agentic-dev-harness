#!/usr/bin/env bash
# scripts/run-status.sh - is this tree's harness run running, or queued, and
# behind what? (HARNESS-120)
#
#   bash scripts/run-status.sh
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
# The queue lock is found by run_queue_dir, the one rule run_queue_acquire
# uses, whatever HARNESS_RUN_QUEUE says: off is about joining, and this joins
# nothing. "Alive" is kill -0, with run-queue.sh's limits.
#
# Reads only: writes nothing, creates nothing (not the queue directory), takes
# no lock, never sleeps. Everything goes to stdout, exit 0; any argument is a
# usage error, exit 2. Bash 3.2, awk and coreutils only.

if [ "$#" -gt 0 ]; then
  printf 'usage: bash scripts/run-status.sh\n' >&2
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
exit 0
