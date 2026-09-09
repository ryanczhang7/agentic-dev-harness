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

# First line of the block gates.sh writes into a story's ## Gate results.
# check-boundaries.sh looks for it to tell a tool-written record from a pasted
# one.
GATE_MARKER='<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->'

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

# classify_stdin   One repo-relative path per input line -> "<category>\t<path>"
# per output line. Same rules and precedence as classify, but one awk pass
# instead of one process per path; use it for anything beyond a handful.
#
# One process in total: the glob-to-regex conversion is the same character scan
# as glob_to_regex, done inside awk, because spawning it per rule costs seconds
# on Windows. ENVIRON rather than -v for the path: -v processes backslashes.
classify_stdin() {
  PATHS_CONF="$HARNESS_DIR/paths.conf" awk '
    function g2r(s,   out, i, n, c) {
      out = ""; i = 1; n = length(s)
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
      return out
    }
    BEGIN {
      n = 0; conf = ENVIRON["PATHS_CONF"]
      while ((getline line < conf) > 0) {
        sub(/\r$/, "", line)
        if (line ~ /^[[:space:]]*(#|$)/) continue
        if (index(line, "|") == 0) continue
        cat = line; sub(/\|.*/, "", cat); gsub(/[[:space:]]/, "", cat)
        glob = line; sub(/^[^|]*\|/, "", glob)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", glob)
        if (cat == "" || glob == "") continue
        n++; rc[n] = cat; rr[n] = "^" tolower(g2r(glob)) "$"
      }
      close(conf)
    }
    {
      path = $0; sub(/\r$/, "", path); sub(/^\.\//, "", path)
      if (path == "") next
      lp = tolower(path); c = "source"
      for (i = 1; i <= n; i++) if (lp ~ rr[i]) { c = rc[i]; break }
      print c "\t" path
    }'
}

# --- Gate tree hash ---------------------------------------------------------
#
# One id for "the code the gates ran against". gates.sh records it in the
# story's ## Gate results; check-boundaries.sh recomputes it and refuses a PR
# whose recorded gate run does not match the code being merged.
#
# Included: every source, test, config and harness path. Excluded: docs (the
# story file that records the hash cannot be part of it), vendor, ignored
# files, and harness runtime state. Blob ids are of LF-normalised content, so a
# Windows working tree and a Linux checkout of the same content agree.

# Reads "blob\tpath" lines; prints the hash.
_hash_blob_listing() {
  local listing
  listing="$(cat)"
  [ -n "$listing" ] || { printf 'unavailable'; return 1; }
  {
    printf '%s\n' "$listing" | awk -F'\t' '{ print "B\t" $1 "\t" $2 }'
    printf '%s\n' "$listing" | cut -f2- | classify_stdin | awk -F'\t' '{ print "C\t" $1 "\t" $2 }'
  } | awk -F'\t' '
      $1 == "B" { blob[$3] = $2; next }
      $1 == "C" { cat[$3] = $2 }
      END {
        for (p in blob) {
          c = cat[p]
          if (c != "source" && c != "test" && c != "config" && c != "harness") continue
          if (index(p, ".claude/state/") == 1) continue
          print blob[p] "  " p
        }
      }' | LC_ALL=C sort | git hash-object --stdin
}

# gate_tree_hash   The working tree as it is right now, tracked or not.
gate_tree_hash() {
  local idx
  idx="$HARNESS_ROOT/.claude/state/.tree-index.$$"
  mkdir -p "$HARNESS_ROOT/.claude/state"; rm -f "$idx"
  ( cd "$HARNESS_ROOT" \
      && GIT_INDEX_FILE="$idx" git add -A . >/dev/null 2>&1 \
      && GIT_INDEX_FILE="$idx" git ls-files -s ) \
    | awk -F'\t' '{ split($1, a, " "); print a[2] "\t" $2 }' \
    | _hash_blob_listing
  local rc=$?
  rm -f "$idx"
  return $rc
}

# gate_tree_hash_of <commit>   The same hash for a committed tree - what CI
# uses, where the checkout may be a merge commit rather than the PR head.
gate_tree_hash_of() {
  git -C "$HARNESS_ROOT" ls-tree -r "$1" 2>/dev/null \
    | awk -F'\t' '{ split($1, a, " "); if (a[2] == "blob") print a[3] "\t" $2 }' \
    | _hash_blob_listing
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
