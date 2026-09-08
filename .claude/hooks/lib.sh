#!/usr/bin/env bash
# Shared helpers for the harness hooks.
#
# Design rules:
#   * Zero dependencies beyond bash + coreutils (no jq, no python, no node).
#   * Fail OPEN. A bug in a hook must never wedge the session: on any internal
#     error we allow the action. Correctness is defended in depth by the gates
#     and by CI; the hook exists to catch the honest mistake, not the attacker.

HARNESS_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
HARNESS_DIR="$HARNESS_ROOT/.claude/harness"
STATE_FILE="$HARNESS_ROOT/.claude/state/current-story.env"
GATE_STAMP="$HARNESS_ROOT/.claude/state/last-gate-run"

# --- JSON -------------------------------------------------------------------

# json_get_string <key>   reads $HOOK_INPUT, prints the first string value for
# <key> anywhere in the document. Handles backslash escapes.
json_get_string() {
  JKEY="$1" printf '%s' "$HOOK_INPUT" | JKEY="$1" awk '
    { s = s $0 "\n" }
    END {
      key = ENVIRON["JKEY"]
      pat = "\"" key "\"[ \t\r\n]*:[ \t\r\n]*\""
      if (match(s, pat) == 0) exit 1
      i = RSTART + RLENGTH
      out = ""
      while (i <= length(s)) {
        c = substr(s, i, 1)
        if (c == "\\") {
          n = substr(s, i + 1, 1)
          if (n == "n")      out = out "\n"
          else if (n == "t") out = out "\t"
          else if (n == "r") out = out "\r"
          else if (n == "u") { out = out " "; i += 4 }
          else               out = out n
          i += 2
          continue
        }
        if (c == "\"") break
        out = out c
        i++
      }
      printf "%s", out
    }'
}

# json_is_true <key>   exit 0 if "key": true appears in $HOOK_INPUT
json_is_true() {
  printf '%s' "$HOOK_INPUT" | grep -qE "\"$1\"[[:space:]]*:[[:space:]]*true"
}


# --- Paths ------------------------------------------------------------------

# glob_to_regex <glob>   ** spans path segments, * stays within one.
# Implemented as a character scan: sed bracket expressions are a minefield here
# (POSIX treats "[." and "[]" as collating-symbol openers).
glob_to_regex() {
  printf '%s' "$1" | awk '{
    s = $0; out = ""; i = 1; n = length(s)
    while (i <= n) {
      c = substr(s, i, 1)
      if (c == "*") {
        if (substr(s, i, 3) == "**/") { out = out "(.*/)?"; i += 3; continue }
        if (substr(s, i, 2) == "**")  { out = out ".*";     i += 2; continue }
        out = out "[^/]*"; i++; continue
      }
      if (c == "?") { out = out "[^/]"; i++; continue }
      if (index(".^$+(){}|[]\\", c) > 0) { out = out "\\" c; i++; continue }
      out = out c; i++
    }
    printf "%s", out
  }'
}

# to_rel <path>   Repo-relative, forward slashes. Empty output means "outside
# this repository", and therefore not the harness's business.
to_rel() {
  local p root lp lr base
  p=$(printf '%s' "$1" | tr '\134' '/')
  root=$(printf '%s' "$HARNESS_ROOT" | tr '\134' '/')
  root="${root%/}"
  lp="${p,,}"
  lr="${root,,}"

  if [[ "$lp" == "$lr"/* ]]; then
    printf '%s' "${p:${#root}+1}"
    return
  fi

  # Absolute path elsewhere on disk (scratchpad, /tmp, another checkout).
  if [[ "$p" == /* || "$p" == ?:/* ]]; then
    # Tolerate C:/ vs /c/ drive spellings by matching the repo folder name.
    base="${root##*/}"
    if [[ "$lp" == */"${base,,}"/* ]]; then
      printf '%s' "${p#*/$base/}"
      return
    fi
    printf '%s' ""
    return
  fi

  printf '%s' "${p#./}"
}

# classify <relpath>   -> harness | docs | test | config | source
classify() {
  local rel="$1" line cat glob re
  [ -z "$rel" ] && { printf 'outside'; return; }
  while IFS= read -r line; do
    line="${line%%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    case "$line" in *'|'*) ;; *) continue ;; esac
    cat="${line%%|*}"
    glob="${line#*|}"
    cat="$(printf '%s' "$cat" | tr -d '[:space:]')"
    glob="$(printf '%s' "$glob" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$cat" ] && continue
    [ -z "$glob" ] && continue
    re="$(glob_to_regex "$glob")"
    if printf '%s' "$rel" | grep -qiE "^$re$"; then
      printf '%s' "$cat"
      return
    fi
  done < "$HARNESS_DIR/paths.conf"
  printf 'source'
}

# --- Story state ------------------------------------------------------------

# load_state   sets STORY_ID, STORY_SLUG, PHASE, STORY_TYPE, BRANCH.
# PHASE is IDLE when no story is active.
load_state() {
  STORY_ID=""; STORY_SLUG=""; PHASE="IDLE"; STORY_TYPE=""; BRANCH=""
  [ -f "$STATE_FILE" ] || return 0
  local line k v
  while IFS= read -r line; do
    line="${line%%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    k="${line%%=*}"; v="${line#*=}"
    v="${v%\"}"; v="${v#\"}"
    case "$k" in
      STORY_ID)   STORY_ID="$v" ;;
      STORY_SLUG) STORY_SLUG="$v" ;;
      PHASE)      PHASE="$v" ;;
      STORY_TYPE) STORY_TYPE="$v" ;;
      BRANCH)     BRANCH="$v" ;;
    esac
  done < "$STATE_FILE"
  [ -z "$PHASE" ] && PHASE="IDLE"
  return 0
}

# phase_allows <category>   exit 0 if the current PHASE may write <category>
phase_allows() {
  local want="$1" line ph cats
  [ "$want" = "outside" ] && return 0
  while IFS= read -r line; do
    line="${line%%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    ph="$(printf '%s' "${line%%|*}" | tr -d '[:space:]')"
    [ "$ph" = "$PHASE" ] || continue
    cats="${line#*|}"; cats="${cats%%|*}"
    cats="$(printf '%s' "$cats" | tr -d '[:space:]')"
    case ",$cats," in *",$want,"*) return 0 ;; esac
    return 1
  done < "$HARNESS_DIR/phases.conf"
  # Unknown phase: don't block.
  return 0
}

phase_message() {
  local line ph msg
  while IFS= read -r line; do
    line="${line%%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    ph="$(printf '%s' "${line%%|*}" | tr -d '[:space:]')"
    [ "$ph" = "$PHASE" ] || continue
    msg="${line#*|}"; msg="${msg#*|}"
    printf '%s' "$(printf '%s' "$msg" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    return
  done < "$HARNESS_DIR/phases.conf"
}

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$(json_escape "$1")"
  exit 0
}

# json_escape <string>   Pure bash. Deliberately contains no backslash literals:
# the escape character is built with printf, which keeps this readable and
# immune to quoting accidents across shells and editors.
json_escape() {
  local s="$1" BS DQ
  BS=$(printf '\134')
  DQ='"'
  s="${s//$BS/$BS$BS}"
  s="${s//$DQ/$BS$DQ}"
  s="${s//$'\r'/}"
  s="${s//$'\n'/${BS}n}"
  s="${s//$'\t'/${BS}t}"
  printf '%s' "$s"
}
