#!/usr/bin/env bash
# Run the project's quality gates as declared in .claude/harness/project.conf.
#
#   bash scripts/gates.sh                  run every gate; record the result in the active story
#   bash scripts/gates.sh --story WORLD-3  ... and record it in that story instead
#   bash scripts/gates.sh --list           show what is configured
#   bash scripts/gates.sh --gate unit      run one gate  (not recorded: a partial run is not evidence)
#   bash scripts/gates.sh --required       required gates only  (not recorded)
#   bash scripts/gates.sh --audit          check the manifest itself, run nothing
#
# The gate NAMES are stable across every project ("the coverage gate"); the
# COMMANDS behind them are per-stack. That indirection is what lets the same
# agents drive a Python service, a TypeScript app or a Godot game.
#
# Exit 0 is not proof that a gate did any work: a test runner that discovers no
# tests, or a linter pointed at an empty directory, exits 0 with nothing to say.
# `evidence` lines assert that work was OBSERVED, not that it succeeded.
# `floor` lines go further and assert HOW MUCH: the number the evidence regex
# matched must not fall below a recorded minimum, so a suite that quietly
# shrinks from 47 tests to 3 fails instead of passing faster. `waiver` lines
# name an optional gate that is known to fail, and why, so that WARN in the
# summary always means something changed. All three are described in the
# quality-gates skill.
#
# A full run writes its own summary into the story's ## Gate results, stamped
# with the commit and a hash of the code it ran against. Nobody pastes it.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$ROOT/.claude/harness/project.conf"
LOGDIR="$ROOT/.claude/state/gate-logs"
STAMP="$ROOT/.claude/state/last-gate-run"

export CLAUDE_PROJECT_DIR="$ROOT"
. "$ROOT/.claude/hooks/lib.sh"

[ -f "$CONF" ] || { printf 'error: missing %s\n' "$CONF" >&2; exit 1; }
mkdir -p "$LOGDIR"

BOOTSTRAPPED="$(grep -E '^BOOTSTRAPPED=' "$CONF" | head -1 | cut -d= -f2- | tr -d '[:space:]')"
[ -z "$BOOTSTRAPPED" ] && BOOTSTRAPPED=no

ONLY=""; REQUIRED_ONLY=0; LIST=0; AUDIT=0; STORY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --list) LIST=1 ;;
    --gate) shift; ONLY="${1:-}" ;;
    --required) REQUIRED_ONLY=1 ;;
    --audit) AUDIT=1 ;;
    --story) shift; STORY="${1:-}" ;;
    -h|--help) sed -n '2,23p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

TAB=$(printf '\t')
ESC=$(printf '\033')

# --- evidence, floor and waiver tables ---------------------------------------
# Read up front, so that --gate <id> still finds its own lines. Stored as
# "<id><TAB><value>" lines; no associative arrays, for bash 3.2.
EVIDENCE=""; WAIVERS=""; FLOORS=""
while IFS= read -r line; do
  line="${line%%$'\r'}"
  case "$(trim "$line")" in ''|'#'*) continue ;; esac
  case "$line" in *'|'*) ;; *) continue ;; esac
  kind=$(trim "$(printf '%s' "$line" | cut -d'|' -f1)")
  case "$kind" in evidence|waiver|floor) ;; *) continue ;; esac
  tid=$(trim "$(printf '%s' "$line" | cut -d'|' -f2)")
  # -f3- so that a regex containing `|` (alternation) survives the split.
  tval=$(trim "$(printf '%s' "$line" | cut -d'|' -f3-)")
  [ -n "$tid" ] || continue
  case "$kind" in
    evidence) EVIDENCE="$EVIDENCE$tid$TAB$tval
" ;;
    waiver)   WAIVERS="$WAIVERS$tid$TAB$tval
" ;;
    floor)    FLOORS="$FLOORS$tid$TAB$tval
" ;;
  esac
done < "$CONF"

# table_lookup <table> <id>   Echoes the value. Exact string comparison, never
# a regex match: a gate id containing `.` or `*` must not silently adopt a
# different gate's line. Returns 1 when the id has no line.
table_lookup() {
  local eid ere
  while IFS="$TAB" read -r eid ere; do
    if [ "$eid" = "$2" ]; then printf '%s' "$ere"; return 0; fi
  done <<< "$1"
  return 1
}

# A gate's log as the regex should see it: no ANSI colour, no CR.
clean_log() {
  sed -e "s/${ESC}\[[0-9;]*[a-zA-Z]//g" -e 's/\r$//' "$1"
}

# work_count <log> <evidence regex>   How much work the gate was observed doing:
# the first run of digits at or after the start of the first evidence match.
#
# The evidence regex is the measurement, rather than a second regex, because
# there should be one description per gate of what "having done something"
# looks like. The consequence is that a regex which stops mid-number - the
# `[1-9]` in `test result: ok\. [1-9]` - measures a truncated count; widen it
# to cover the whole number if you want a floor on that gate.
work_count() {
  clean_log "$1" \
    | grep -oE -m1 -- "$2.*" 2>/dev/null | head -1 \
    | grep -oE '[0-9]+' 2>/dev/null | head -1
}

# --- recording ----------------------------------------------------------------
# Replace the body of the story's "## Gate results" section with a block this
# script wrote: the marker check-boundaries.sh looks for, the UTC time, the
# commit, the tree hash of the code the gates saw, and the summary. If the
# section is missing (an older story file) it is appended.
record_in_story() { # <story-file> <result-text> <summary-lines>
  local f="$1" res="$2" body="$3" commit dirty tree block
  commit="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || printf 'no commit')"
  dirty=""
  [ -z "$(git -C "$ROOT" status --porcelain -- . ':!docs' 2>/dev/null)" ] || dirty=" (working tree had uncommitted changes)"
  tree="$(gate_tree_hash)"
  block="$(printf '%s\n' \
    "$GATE_MARKER" \
    "" \
    "    run:    $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "    commit: $commit$dirty" \
    "    tree:   $tree" \
    "    result: $res" \
    "" \
    "$(printf '%s\n' "$body" | sed -e '/^[[:space:]]*$/d' -e 's/^/    /')")"
  grep -q '^## Gate results' "$f" || printf '\n## Gate results\n' >> "$f"
  # ENVIRON rather than -v: the block contains regexes with backslashes.
  BLK="$block" awk '
    /^## Gate results/ { print; print ""; print ENVIRON["BLK"]; print ""; skip=1; next }
    skip && /^## / { skip=0 }
    !skip { print }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

# --- gates this story requires of itself ------------------------------------
# `integration` is optional for the repo because it needs a browser, and a busy
# laptop should not block unrelated stories on it. But a story whose central
# claims are only ever checked there - "the canvas draws a non-blank first
# frame" - can pass every required gate while its evidence went unrun. So a
# story may escalate a gate for itself, in its frontmatter:
#
#     required_gates: [integration]
#
# Optional for the repo, binding for the story that depends on it.
if [ -z "$STORY" ]; then load_state; STORY="$STORY_ID"; fi
STORY_FILE="$ROOT/docs/backlog/stories/$STORY.md"
STORY_REQUIRES=""
if [ -n "$STORY" ] && [ -f "$STORY_FILE" ]; then
  STORY_REQUIRES=" $(frontmatter_list "$STORY_FILE" required_gates) "
fi

fails=0; warns=0; known=0; unconfigured=0; ran=0; noevidence=0
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

  # An escalation makes the gate required for everything below, and says so
  # wherever the gate is reported, so nobody has to wonder why `integration`
  # blocked this story and not the last one.
  escalated=""
  case "$STORY_REQUIRES" in
    *" $id "*)
      [ "$req" = "required" ] || escalated=" (required by story $STORY)"
      req=required ;;
  esac

  [ -n "$ONLY" ] && [ "$ONLY" != "$id" ] && continue
  [ "$REQUIRED_ONLY" = 1 ] && [ "$req" != "required" ] && continue

  exp=$(table_lookup "$EVIDENCE" "$id") || exp="<none>"
  waiver=$(table_lookup "$WAIVERS" "$id") || waiver=""
  floor=$(table_lookup "$FLOORS" "$id") || floor=""
  logrel=".claude/state/gate-logs/$id.log"

  if [ "$LIST" = 1 ]; then
    printf '%-12s %-9s %-6s %s\n' "$id" "$req" "$cwd" "${cmd:-<unconfigured>}"
    printf '%-12s %-9s %-6s evidence: %s\n' "" "" "" "$exp"
    [ -n "$floor" ]  && printf '%-12s %-9s %-6s floor:    %s\n' "" "" "" "$floor"
    [ -n "$waiver" ] && printf '%-12s %-9s %-6s waiver:   %s\n' "" "" "" "$waiver"
    [ -n "$escalated" ] && printf '%-12s %-9s %-6s optional for the repo,%s\n' "" "" "" "$escalated"
    continue
  fi

  # A floor is measured out of the evidence match, so it needs one, and it has
  # to be a number. Both are checked before anything runs: a floor that cannot
  # be evaluated would otherwise sit in project.conf looking like protection.
  floor_broken=""
  if [ -n "$floor" ]; then
    case "$floor" in
      ''|*[!0-9]*) floor_broken="floor '$floor' is not a number" ;;
    esac
    if [ -z "$floor_broken" ] && { [ "$exp" = "<none>" ] || [ "$exp" = "-" ]; }; then
      floor_broken="floor needs an evidence regex to measure, and $id has none"
    fi
  fi
  if [ -n "$floor_broken" ]; then
    if [ "$AUDIT" = 1 ]; then
      printf 'FAIL %-12s %s\n' "$id" "$floor_broken"
    else
      results="$results\nFAIL         $id ($floor_broken)"
    fi
    fails=$((fails+1)); continue
  fi

  # A waiver on a required gate is a bypass, not a waiver - including when the
  # story is what made it required.
  if [ -n "$waiver" ] && [ "$req" = "required" ]; then
    if [ "$AUDIT" = 1 ]; then
      printf 'FAIL %-12s has a waiver but is required%s; waivers are for optional gates only\n' "$id" "$escalated"
    else
      results="$results\nFAIL         $id (has a waiver but is required$escalated; waivers are for optional gates only)"
    fi
    fails=$((fails+1)); continue
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
    [ -n "$floor" ]  && printf '     %-12s floor:  %s\n' "" "$floor"
    [ -n "$waiver" ] && printf '     %-12s waiver: %s\n' "" "$waiver"
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

  printf '\n=== gate: %s (%s%s) ===\n%s\n' "$id" "$req" "$escalated" "$cmd"
  log="$LOGDIR/$id.log"
  start=$(date +%s)
  ( cd "$ROOT/$cwd" && eval "$cmd" ) 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  dur=$(( $(date +%s) - start ))
  ran=$((ran+1))

  # Three outcomes. Liveness is only ever consulted for a gate that already
  # exited 0: success is the exit code's job, and this asks the separate
  # question of whether the command had anything to do. A gate that fails keeps
  # failing for its own reason, with its own message.
  outcome=pass; why=""; observed=""
  if [ "$rc" -ne 0 ]; then
    outcome=fail
  elif [ "$exp" != "<none>" ] && [ "$exp" != "-" ] && ! clean_log "$log" | grep -Eq -- "$exp"; then
    outcome=noevidence
    why="ran but produced no evidence of work: expected /$exp/"
  elif [ "$exp" != "<none>" ] && [ "$exp" != "-" ]; then
    # The gate did work. How much, and is that less than it used to be? A suite
    # that shrinks from 47 tests to 3 exits 0 and matches its evidence regex
    # just as happily as one that grew.
    observed="$(work_count "$log" "$exp")"
    if [ -n "$floor" ]; then
      if [ -z "$observed" ]; then
        outcome=noevidence
        why="floor of $floor declared, but no number was found in the evidence match, so the work could not be measured"
      elif [ "$observed" -lt "$floor" ]; then
        outcome=noevidence
        why="did $observed units of work, below the floor of $floor in project.conf"
      fi
    fi
  fi

  case "$outcome" in
    pass)
      seen=""
      [ -n "$observed" ] && seen=", observed $observed"
      [ -n "$observed" ] && [ -n "$floor" ] && seen=", observed $observed, floor $floor"
      if [ -n "$waiver" ]; then
        results="$results\nPASS         $id (${dur}s$seen) -- waiver no longer needed, remove it: $waiver"
      elif [ "$exp" = "<none>" ] && [ "$BOOTSTRAPPED" = "yes" ] && [ "$req" = "required" ]; then
        results="$results\nPASS         $id (${dur}s) -- no evidence line: a vacuous pass would go unnoticed"
        noevidence=$((noevidence+1))
      else
        results="$results\nPASS         $id (${dur}s$seen)"
      fi ;;
    noevidence)
      if [ "$req" = "required" ]; then
        results="$results\nFAIL         $id$escalated (${dur}s, $why) -> $logrel"; fails=$((fails+1))
      elif [ -n "$waiver" ]; then
        results="$results\nKNOWN        $id (${dur}s, $why; $waiver)"; known=$((known+1))
      else
        results="$results\nWARN         $id (${dur}s, $why, optional)"; warns=$((warns+1))
      fi ;;
    fail)
      if [ "$req" = "required" ]; then
        results="$results\nFAIL         $id$escalated (${dur}s, exit $rc) -> $logrel"; fails=$((fails+1))
      elif [ -n "$waiver" ]; then
        results="$results\nKNOWN        $id (${dur}s, exit $rc; $waiver) -> $logrel"; known=$((known+1))
      else
        results="$results\nWARN         $id (${dur}s, exit $rc, optional) -> $logrel"; warns=$((warns+1))
      fi ;;
  esac
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

if [ "$warns" -gt 0 ]; then
  printf '\n%d optional gate(s) WARNed. A WARN means something changed since the last run:\n' "$warns"
  printf 'read it. A failure that is known and permanent belongs in a waiver, so that the\n'
  printf 'next WARN is not buried next to it:\n'
  printf '  waiver | <id> | <why this optional gate is expected to fail, and where that is recorded>\n'
fi

if [ "$fails" -gt 0 ]; then
  result="fail ($fails required gate(s) failed)"
  printf 'RESULT=fail\nWHEN=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STAMP"
else
  result="pass ($ran ran, $unconfigured unconfigured, $known known)"
  printf 'RESULT=pass\nWHEN=%s\nRAN=%d\nUNCONFIGURED=%d\nNOEVIDENCE=%d\nKNOWN=%d\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ran" "$unconfigured" "$noevidence" "$known" > "$STAMP"
fi

# --- record -----------------------------------------------------------------
# Only a full run is evidence. `--gate unit` passing says nothing about lint.
if [ -n "$ONLY" ] || [ "$REQUIRED_ONLY" = 1 ]; then
  printf '\n(not recorded in the story: a partial run is not evidence of anything)\n'
else
  if [ -z "$STORY" ]; then
    printf '\n(not recorded: no active story; use --story <id> to record it in one)\n'
  elif [ ! -f "$STORY_FILE" ]; then
    printf '\n(not recorded: no story file at docs/backlog/stories/%s.md)\n' "$STORY"
  else
    record_in_story "$STORY_FILE" "$result" "$(printf '%b' "$results")"
    printf '\nrecorded in docs/backlog/stories/%s.md (## Gate results)\n' "$STORY"
  fi
fi

if [ "$fails" -gt 0 ]; then
  printf '\n%d required gate(s) failed.\n' "$fails"
  exit 1
fi
printf '\nAll required gates passed (%d ran, %d unconfigured, %d known).\n' "$ran" "$unconfigured" "$known"
