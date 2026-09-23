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
  local raw="$1" role="${2:-}" rel cat operand
  [ -z "$raw" ] && return 0
  rel="$(to_rel "$raw")"
  [ -z "$rel" ] && return 0
  cat="$(classify "$rel")"
  if ! phase_allows "$cat"; then
    # The role goes on its own line IMMEDIATELY AFTER path:, never before it
    # and never inside it. `path:` keeps its exact spelling, indent and
    # position because the suite - and anyone reading a denial - anchors on it.
    operand=""
    [ -n "$role" ] && operand="
  operand:  $role"
    deny "BLOCKED by the harness phase lock.

  story:    ${STORY_ID:-unknown}
  phase:    $PHASE
  path:     $rel$operand
  category: $cat

$(phase_message)

If this write is genuinely correct, change the phase deliberately rather than
working around the lock:  bash scripts/phase.sh set ${STORY_ID:-<id>} <PHASE>"
  fi
  return 0
}

# decline <token>   A parse the guard does not believe. It notes the token in
# .claude/state/phase-guard-declined.log and allows the command: a denial
# nobody can act on costs more than the write it might have caught, and the
# note is what turns "the guard is noisy" into a bug report with a token in it.
# Machine-local, like the rest of .claude/state, and never fatal - a hook that
# cannot write its own note still has to let the session continue.
decline() {
  printf 'declined %s in %s: implausible target %s\n' "${STORY_ID:-none}" "$PHASE" "$1" \
    >> "$HARNESS_ROOT/.claude/state/phase-guard-declined.log" 2>/dev/null || true
  return 0
}

# no_candidate <command>   A command that WAS a write and from which no target
# could be parsed. The other half of decline(): that one is a parse the guard
# could not BELIEVE, this one is a target it could not FIND, and one event gets
# exactly one line so the log stays readable.
#
# It exists because an empty candidate list means two different things - "the
# command was never a write" and "it was a write and the parse yielded nothing"
# - and while they were indistinguishable a bypass was invisible: the log was
# empty after a permitted write and empty after a missed one. write_candidates'
# verdict line is what tells them apart. The command is folded onto one line and
# truncated: a transcript nobody reads is the same as no record.
no_candidate() {
  printf 'declined %s in %s: no-candidate write command: %s\n' \
    "${STORY_ID:-none}" "$PHASE" \
    "$(printf '%s' "$1" | tr '\n\r\t' '   ' | cut -c1-200)" \
    >> "$HARNESS_ROOT/.claude/state/phase-guard-declined.log" 2>/dev/null || true
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
    # parser below runs against the masked text, and each candidate is unmasked
    # again before it is classified.
    MASKED="$(printf '%s' "$CMD" | mask_shell_quotes)"
    # Which paths this command would write, ASKED rather than re-derived. The
    # rules live in lib.sh's write_candidates - one parser, one place, the rule
    # rules.md states for classify.sh - so a test that needs this answer can ask
    # for the same one the lock uses. The answer is a verdict line followed by
    # `TARGET` or `TARGET<TAB>ROLE` lines, target first so the filter below can
    # keep anchoring on the path.
    ANSWER="$(write_candidates "$MASKED")"
    VERDICT="${ANSWER%%$'\n'*}"
    CANDIDATES="${ANSWER#*$'\n'}"
    [ "$CANDIDATES" = "$ANSWER" ] && CANDIDATES=""
    # `$` is NOT filtered out here. It was, silently, which made the ONE recipe
    # the harness pushes an agent towards in RED - mutate the production file,
    # watch the corrected test fail, revert - pass unchecked. A candidate whose
    # variable the command text assigns is resolved; one it does not is declined
    # and logged, which is what the guard already does with every other parse it
    # cannot believe. See lib.sh.
    CANDIDATES="$(printf '%s\n' "$CANDIDATES" | grep -vE '^\s*$|^-|\*|^/dev/' | sort -u)"
    # A write command from which NOTHING could be parsed is the case an empty
    # candidate list cannot express on its own, and it is the one worth a trace:
    # before it existed, "the parser found nothing to judge" and "it found
    # candidates and every one was permitted" looked identical from outside.
    # The verdict is what separates them, so this fires when, and only when, the
    # command was a write and the filtered list is empty.
    if [ -z "$CANDIDATES" ]; then
      [ "$VERDICT" = "W" ] && no_candidate "$CMD"
      exit 0
    fi
    ASSIGNMENTS="$(shell_assignments "$MASKED")"
    # The FILE argument of a scripts/mutate.sh invocation, resolved the same way
    # so that `mutate.sh "$F"` is exempt for the same reason `mutate.sh src/a.ts`
    # is. Only that argument: the payload after `--` is judged normally.
    EXEMPT=""
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      EXEMPT="$EXEMPT
$(resolve_vars "$m" "$ASSIGNMENTS")"
    done <<< "$(mutate_targets "$MASKED")"
    # Where the shell will actually be when those targets are written. A
    # relative path means nothing without it: `cd /tmp/scratch && rm -rf
    # gate-logs` names no repo path at all. An unaccountable cwd skips relative
    # candidates rather than blocking them - fail open.
    CWD_PREFIX=""; CWD_KNOWN=1
    CWD_PREFIX="$(command_cwd "$MASKED")" || CWD_KNOWN=0
    while IFS= read -r candidate; do
      [ -z "$candidate" ] && continue
      # The ROLE comes off FIRST - before resolution, before the exemption test
      # and before the plausibility test. $EXEMPT is an exact string compare
      # against the resolved mutate.sh argument, and a role left on the string
      # would silently un-exempt the one diagnostic this harness requires in RED.
      target="${candidate%%$'\t'*}"
      role="${candidate#*$'\t'}"
      [ "$role" = "$candidate" ] && role=""
      # Resolved before it is judged, so that `"$F"` is either a real path or an
      # honest decline. Still masked at this point, so a value carrying a quoted
      # space survives as one token.
      target="$(resolve_vars "$target" "$ASSIGNMENTS")"
      case "
$EXEMPT" in *"
$target"*) continue ;; esac
      # Judged while still masked: a metacharacter that survives to here was
      # leaked by the parse rather than quoted by the author. An implausible
      # token means the parse failed, and a failed parse is inconclusive, not
      # a violation - see path_is_implausible in lib.sh.
      if path_is_implausible "$target"; then decline "$target"; continue; fi
      target="$(printf '%s' "$target" | unmask_shell_quotes)"
      # A restored candidate spanning a newline is not a filename; a guard that
      # cannot say what it is looking at does not block. Fail open, as ever.
      case "$target" in *$'\n'*) continue ;; esac
      # A DIRECTORY operand keeps its trailing slash through normalisation. It
      # is not cosmetic: `mv -t docs/ x` and `mv -t docs x` are different
      # questions for classify - only `docs/` matches the docs rule - so folding
      # them together would answer one of them with the other's category.
      SLASH=""; case "$target" in */) SLASH="/" ;; esac
      if path_is_absolute "$target"; then
        check_path "$target" "$role"
      elif [ "$CWD_KNOWN" = 1 ]; then
        target="$(normalize_rel "${CWD_PREFIX:+$CWD_PREFIX/}$target")" || continue
        [ -n "$target" ] && target="$target$SLASH"
        check_path "$target" "$role"
      fi
    done <<< "$CANDIDATES"
    ;;
esac

exit 0
