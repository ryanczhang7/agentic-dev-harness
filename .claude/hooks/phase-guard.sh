#!/usr/bin/env bash
# PreToolUse hook: enforce the RED -> GREEN phase lock.
#
# While a story is active, this refuses writes that would violate the current
# phase — production code during RED, test edits during GREEN. When no story is
# active it does nothing at all.
#
# It inspects Write/Edit/MultiEdit/NotebookEdit targets directly, and Bash
# commands heuristically (redirects, tee, sed -i, cp/mv, rm, touch), because an
# agent that cannot use Edit will happily reach for `cat > file`.

set -uo pipefail
HOOK_INPUT="$(cat)"
# shellcheck source=lib.sh
# No ERR trap: without set -e bash already continues past failures, so the
# hook degrades to "allow" on any internal problem, which is what we want.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2>/dev/null || exit 0


load_state
[ "$PHASE" = "IDLE" ] && exit 0
[ -f "$HARNESS_DIR/paths.conf" ] || exit 0

TOOL="$(json_get_string tool_name || true)"

check_path() {
  local raw="$1" rel cat
  [ -z "$raw" ] && return 0
  rel="$(to_rel "$raw")"
  [ -z "$rel" ] && return 0
  cat="$(classify "$rel")"
  if ! phase_allows "$cat"; then
    deny "BLOCKED by the harness phase lock.

  story:    ${STORY_ID:-unknown}
  phase:    $PHASE
  path:     $rel
  category: $cat

$(phase_message)

If this write is genuinely correct, change the phase deliberately rather than
working around the lock:  bash scripts/phase.sh set ${STORY_ID:-<id>} <PHASE>"
  fi
  return 0
}

case "$TOOL" in
  Write|Edit|MultiEdit|NotebookEdit)
    check_path "$(json_get_string file_path || true)"
    check_path "$(json_get_string notebook_path || true)"
    ;;
  Bash)
    CMD="$(json_get_string command || true)"
    [ -z "$CMD" ] && exit 0
    # Candidate write targets. Deliberately conservative: we only look at
    # constructs that unambiguously name a destination file.
    CANDIDATES="$(
      {
        printf '%s\n' "$CMD" | grep -oE '>>?[[:space:]]*[^|&;><[:space:]]+'      | sed -E 's/^>>?[[:space:]]*//'
        printf '%s\n' "$CMD" | grep -oE '\btee\b([[:space:]]+-a)?[[:space:]]+[^|&;><[:space:]]+' | awk '{print $NF}'
        printf '%s\n' "$CMD" | grep -oE '\bsed\b[^|&;]*-i[^|&;]*'                | awk '{print $NF}'
        printf '%s\n' "$CMD" | grep -oE '\b(cp|mv)\b[[:space:]]+[^|&;]+'         | awk '{print $NF}'
        printf '%s\n' "$CMD" | grep -oE '\b(rm|touch)\b[[:space:]]+[^|&;]+'      | tr ' ' '\n' | grep -vE '^(rm|touch|-.*)$'
      } 2>/dev/null | tr -d '"'"'" | grep -vE '^\s*$|^-|\$|\*|^/dev/' | sort -u
    )"
    while IFS= read -r target; do
      [ -z "$target" ] && continue
      check_path "$target"
    done <<< "$CANDIDATES"
    ;;
esac

exit 0
