#!/usr/bin/env bash
# Run the project's quality gates as declared in .claude/harness/project.conf.
#
#   bash scripts/gates.sh              run every gate
#   bash scripts/gates.sh --list       show what is configured
#   bash scripts/gates.sh --gate unit  run one gate
#   bash scripts/gates.sh --required   required gates only
#   bash scripts/gates.sh --audit      check the manifest itself, run nothing
#
# The gate NAMES are stable across every project ("the coverage gate"); the
# COMMANDS behind them are per-stack. That indirection is what lets the same
# agents drive a Python service, a TypeScript app or a Godot game.
#
# Exit 0 is not proof that a gate did any work: a test runner that discovers no
# tests, or a linter pointed at an empty directory, exits 0 with nothing to say.
# `evidence` lines assert that work was OBSERVED, not that it succeeded - see
# the quality-gates skill.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$ROOT/.claude/harness/project.conf"
LOGDIR="$ROOT/.claude/state/gate-logs"
STAMP="$ROOT/.claude/state/last-gate-run"

[ -f "$CONF" ] || { printf 'error: missing %s\n' "$CONF" >&2; exit 1; }
mkdir -p "$LOGDIR"

BOOTSTRAPPED="$(grep -E '^BOOTSTRAPPED=' "$CONF" | head -1 | cut -d= -f2- | tr -d '[:space:]')"
[ -z "$BOOTSTRAPPED" ] && BOOTSTRAPPED=no

ONLY=""; REQUIRED_ONLY=0; LIST=0; AUDIT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --list) LIST=1 ;;
    --gate) shift; ONLY="${1:-}" ;;
    --required) REQUIRED_ONLY=1 ;;
    --audit) AUDIT=1 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

TAB=$(printf '\t')
ESC=$(printf '\033')

# --- evidence table ---------------------------------------------------------
# Read every `evidence` line up front, so that --gate <id> still finds its own.
# Stored as "<id><TAB><regex>" lines; no associative arrays, for bash 3.2.
EVIDENCE=""
while IFS= read -r line; do
  line="${line%%$'\r'}"
  case "$(trim "$line")" in ''|'#'*) continue ;; esac
  case "$line" in *'|'*) ;; *) continue ;; esac
  [ "$(trim "$(printf '%s' "$line" | cut -d'|' -f1)")" = "evidence" ] || continue
  eid=$(trim "$(printf '%s' "$line" | cut -d'|' -f2)")
  # -f3- so that a regex containing `|` (alternation) survives the split.
  ere=$(trim "$(printf '%s' "$line" | cut -d'|' -f3-)")
  [ -n "$eid" ] || continue
  EVIDENCE="$EVIDENCE$eid$TAB$ere
"
done < "$CONF"

# Echo the regex for a gate id, or "-" if liveness was deliberately declared
# unassertable. Returns 1 when the gate has no evidence line at all.
# Exact string comparison, never a regex match: a gate id containing `.` or `*`
# must not silently adopt a different gate's line. The here-string keeps the
# loop in this shell so `return` works.
evidence_lookup() {
  local eid ere
  while IFS="$TAB" read -r eid ere; do
    if [ "$eid" = "$1" ]; then printf '%s' "$ere"; return 0; fi
  done <<< "$EVIDENCE"
  return 1
}

# A gate's log as the regex should see it: no ANSI colour, no CR.
clean_log() {
  sed -e "s/${ESC}\[[0-9;]*[a-zA-Z]//g" -e 's/\r$//' "$1"
}

fails=0; unconfigured=0; ran=0; noevidence=0
results=""

while IFS= read -r line; do
  line="${line%%$'\r'}"
  case "$(trim "$line")" in ''|'#'*) continue ;; esac
  case "$line" in *'|'*) ;; *) continue ;; esac

  kind=$(trim "$(printf '%s' "$line" | cut -d'|' -f1)")
  [ "$kind" = "gate" ] || continue
  id=$(trim   "$(printf '%s' "$line" | cut -d'|' -f2)")
  req=$(trim  "$(printf '%s' "$line" | cut -d'|' -f3)")
  cwd=$(trim  "$(printf '%s' "$line" | cut -d'|' -f4)")
  cmd=$(trim  "$(printf '%s' "$line" | cut -d'|' -f5-)")
  [ -z "$cwd" ] && cwd="."

  [ -n "$ONLY" ] && [ "$ONLY" != "$id" ] && continue
  [ "$REQUIRED_ONLY" = 1 ] && [ "$req" != "required" ] && continue

  exp=$(evidence_lookup "$id") || exp="<none>"

  if [ "$LIST" = 1 ]; then
    printf '%-12s %-9s %-6s %s\n' "$id" "$req" "$cwd" "${cmd:-<unconfigured>}"
    printf '%-12s %-9s %-6s evidence: %s\n' "" "" "" "$exp"
    continue
  fi

  if [ "$AUDIT" = 1 ]; then
    if [ -z "$cmd" ]; then
      if [ "$req" = "required" ] && [ "$BOOTSTRAPPED" = "yes" ]; then
        printf 'FAIL %-12s no command\n' "$id"; fails=$((fails+1))
      else
        printf 'ok   %-12s (unconfigured)\n' "$id"
      fi
      continue
    fi
    if [ ! -d "$ROOT/$cwd" ]; then
      printf 'FAIL %-12s cwd does not exist: %s\n' "$id" "$cwd"; fails=$((fails+1)); continue
    fi
    if [ "$exp" = "<none>" ]; then
      printf 'WARN %-12s no evidence line; a vacuous pass would go unnoticed\n' "$id"
      noevidence=$((noevidence+1)); continue
    fi
    if [ "$exp" = "-" ]; then
      printf 'ok   %-12s (liveness declared unassertable)\n' "$id"
    else
      printf 'ok   %-12s evidence: %s\n' "$id" "$exp"
    fi
    continue
  fi

  if [ -z "$cmd" ]; then
    if [ "$req" = "required" ] && [ "$BOOTSTRAPPED" = "yes" ]; then
      results="$results\nFAIL         $id (required gate has no command in project.conf)"
      fails=$((fails+1))
    else
      results="$results\nUNCONFIGURED $id"
      unconfigured=$((unconfigured+1))
    fi
    continue
  fi

  printf '\n=== gate: %s (%s) ===\n%s\n' "$id" "$req" "$cmd"
  log="$LOGDIR/$id.log"
  start=$(date +%s)
  ( cd "$ROOT/$cwd" && eval "$cmd" ) 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  dur=$(( $(date +%s) - start ))
  ran=$((ran+1))

  # Liveness: only ever consulted for a gate that already exited 0. Success is
  # the exit code's job; this asks the separate question of whether the command
  # had anything to do. A gate that fails keeps failing for its own reason,
  # with its own message.
  if [ "$rc" -eq 0 ] && [ "$exp" != "<none>" ] && [ "$exp" != "-" ]; then
    if ! clean_log "$log" | grep -Eq -- "$exp"; then
      if [ "$req" = "required" ]; then
        results="$results\nFAIL         $id (${dur}s, ran but produced no evidence of work: expected /$exp/) -> .claude/state/gate-logs/$id.log"
        fails=$((fails+1))
      else
        results="$results\nWARN         $id (${dur}s, ran but produced no evidence of work: expected /$exp/, optional)"
      fi
      continue
    fi
  fi

  if [ "$rc" -eq 0 ]; then
    if [ "$exp" = "<none>" ] && [ "$BOOTSTRAPPED" = "yes" ] && [ "$req" = "required" ]; then
      results="$results\nPASS         $id (${dur}s) -- no evidence line: a vacuous pass would go unnoticed"
      noevidence=$((noevidence+1))
    else
      results="$results\nPASS         $id (${dur}s)"
    fi
  elif [ "$req" = "required" ]; then
    results="$results\nFAIL         $id (${dur}s, exit $rc) -> .claude/state/gate-logs/$id.log"
    fails=$((fails+1))
  else
    results="$results\nWARN         $id (${dur}s, exit $rc, optional) -> .claude/state/gate-logs/$id.log"
  fi
done < "$CONF"

[ "$LIST" = 1 ] && exit 0

if [ "$AUDIT" = 1 ]; then
  if [ "$noevidence" -gt 0 ]; then
    printf '\n%d required gate(s) have no evidence line. Add one per gate:\n' "$noevidence"
    printf '  evidence | <id> | <regex proving the tool did work>\n'
    printf 'Use `evidence | <id> | -` only where no such output exists, and say why in the story.\n'
  fi
  if [ "$fails" -gt 0 ]; then
    printf '\n%d manifest problem(s).\n' "$fails"; exit 1
  fi
  printf '\nManifest audit passed.\n'
  exit 0
fi

printf '\n--- gate summary ---%b\n' "$results"

if [ "$BOOTSTRAPPED" != "yes" ]; then
  printf '\nNote: project.conf is not bootstrapped yet (BOOTSTRAPPED=no), so unconfigured\n'
  printf 'required gates are warnings. The bootstrap story must fill them in and flip the flag.\n'
fi

if [ "$noevidence" -gt 0 ]; then
  printf '\nWarning: %d required gate(s) ran without an evidence line, so a command that\n' "$noevidence"
  printf 'did no work at all would still have been recorded as PASS. Add to project.conf:\n'
  printf '  evidence | <id> | <regex proving the tool did work>\n'
fi

if [ "$fails" -gt 0 ]; then
  printf 'RESULT=fail\nWHEN=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STAMP"
  printf '\n%d required gate(s) failed.\n' "$fails"
  exit 1
fi

printf 'RESULT=pass\nWHEN=%s\nRAN=%d\nUNCONFIGURED=%d\nNOEVIDENCE=%d\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ran" "$unconfigured" "$noevidence" > "$STAMP"
printf '\nAll required gates passed (%d ran, %d unconfigured).\n' "$ran" "$unconfigured"
