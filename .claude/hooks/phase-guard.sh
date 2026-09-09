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
    # Quoted spans, heredoc bodies and backslash escapes are DATA, not shell
    # syntax. Masking them first is what stops a sed script's `|` or an arrow
    # inside an awk program from being read as an operator; see lib.sh. The
    # extractors below run against the masked text, and each candidate is
    # unmasked again before it is classified.
    MASKED="$(printf '%s' "$CMD" | mask_shell_quotes)"
    # Candidate write targets. Deliberately conservative: we only look at
    # constructs that unambiguously name a destination file.
    CANDIDATES="$(
      {
        printf '%s\n' "$MASKED" | grep -oE '>>?[[:space:]]*[^|&;><[:space:]]+'      | sed -E 's/^>>?[[:space:]]*//'
        printf '%s\n' "$MASKED" | grep -oE '\btee\b([[:space:]]+-a)?[[:space:]]+[^|&;><[:space:]]+' | awk '{print $NF}'
        printf '%s\n' "$MASKED" | grep -oE '\bsed\b[^|&;]*-i[^|&;]*'                | awk '{print $NF}'
        printf '%s\n' "$MASKED" | grep -oE '\b(cp|mv)\b[[:space:]]+[^|&;]+'         | awk '{print $NF}'
        printf '%s\n' "$MASKED" | grep -oE '\b(rm|touch)\b[[:space:]]+[^|&;]+'      | tr ' ' '\n' | grep -vE '^(rm|touch|-.*)$'
      } 2>/dev/null | tr -d '"'"'" | grep -vE '^\s*$|^-|\$|\*|^/dev/' | sort -u
    )"
    while IFS= read -r target; do
      [ -z "$target" ] && continue
      target="$(printf '%s' "$target" | unmask_shell_quotes)"
      # A restored candidate spanning a newline is not a filename; a guard that
      # cannot say what it is looking at does not block. Fail open, as ever.
      case "$target" in *$'\n'*) continue ;; esac
      check_path "$target"
    done <<< "$CANDIDATES"
    ;;
esac

exit 0
