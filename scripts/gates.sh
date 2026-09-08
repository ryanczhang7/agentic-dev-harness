#!/usr/bin/env bash
# Run the project's quality gates as declared in .claude/harness/project.conf.
#
#   bash scripts/gates.sh              run every gate
#   bash scripts/gates.sh --list       show what is configured
#   bash scripts/gates.sh --gate unit  run one gate
#   bash scripts/gates.sh --required   required gates only
#
# The gate NAMES are stable across every project ("the coverage gate"); the
# COMMANDS behind them are per-stack. That indirection is what lets the same
# agents drive a Python service, a TypeScript app or a Godot game.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$ROOT/.claude/harness/project.conf"
LOGDIR="$ROOT/.claude/state/gate-logs"
STAMP="$ROOT/.claude/state/last-gate-run"

[ -f "$CONF" ] || { printf 'error: missing %s\n' "$CONF" >&2; exit 1; }
mkdir -p "$LOGDIR"

BOOTSTRAPPED="$(grep -E '^BOOTSTRAPPED=' "$CONF" | head -1 | cut -d= -f2- | tr -d '[:space:]')"
[ -z "$BOOTSTRAPPED" ] && BOOTSTRAPPED=no

ONLY=""; REQUIRED_ONLY=0; LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --list) LIST=1 ;;
    --gate) shift; ONLY="${1:-}" ;;
    --required) REQUIRED_ONLY=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

fails=0; unconfigured=0; ran=0
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

  if [ "$LIST" = 1 ]; then
    printf '%-12s %-9s %-6s %s\n' "$id" "$req" "$cwd" "${cmd:-<unconfigured>}"
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
  if [ "$rc" -eq 0 ]; then
    results="$results\nPASS         $id (${dur}s)"
  elif [ "$req" = "required" ]; then
    results="$results\nFAIL         $id (${dur}s, exit $rc) -> .claude/state/gate-logs/$id.log"
    fails=$((fails+1))
  else
    results="$results\nWARN         $id (${dur}s, exit $rc, optional) -> .claude/state/gate-logs/$id.log"
  fi
done < "$CONF"

[ "$LIST" = 1 ] && exit 0

printf '\n--- gate summary ---%b\n' "$results"

if [ "$BOOTSTRAPPED" != "yes" ]; then
  printf '\nNote: project.conf is not bootstrapped yet (BOOTSTRAPPED=no), so unconfigured\n'
  printf 'required gates are warnings. The bootstrap story must fill them in and flip the flag.\n'
fi

if [ "$fails" -gt 0 ]; then
  printf 'RESULT=fail\nWHEN=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STAMP"
  printf '\n%d required gate(s) failed.\n' "$fails"
  exit 1
fi

printf 'RESULT=pass\nWHEN=%s\nRAN=%d\nUNCONFIGURED=%d\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ran" "$unconfigured" > "$STAMP"
printf '\nAll required gates passed (%d ran, %d unconfigured).\n' "$ran" "$unconfigured"
