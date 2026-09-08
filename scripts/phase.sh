#!/usr/bin/env bash
# Story phase control. The one supported way to move a story through the
# RED -> GREEN -> GATES cycle. Writes both the machine state the hooks read and
# the human-readable frontmatter in the story file, so the two cannot drift.
#
#   bash scripts/phase.sh show
#   bash scripts/phase.sh set  WORLD-014 RED
#   bash scripts/phase.sh clear
#   bash scripts/phase.sh board

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/.claude/state/current-story.env"
STORIES="$ROOT/docs/backlog/stories"
PHASES="$ROOT/.claude/harness/phases.conf"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

valid_phase() {
  grep -qE "^[[:space:]]*$1[[:space:]]*\|" "$PHASES"
}

status_for_phase() {
  case "$1" in
    PLANNED)            printf 'todo' ;;
    RED|GREEN|GATES|SCAFFOLD) printf 'in-progress' ;;
    REVIEW)             printf 'in-review' ;;
    DONE)               printf 'done' ;;
    *)                  printf 'todo' ;;
  esac
}

frontmatter() { # <file> <key>
  awk -v k="$2" '
    NR==1 && $0 ~ /^---/ { inf=1; next }
    inf && /^---/ { exit }
    inf { if (index($0, k ":") == 1) { sub(/^[^:]*:[[:space:]]*/, ""); print; exit } }
  ' "$1"
}

set_frontmatter() { # <file> <key> <value>
  local f="$1" k="$2" v="$3"
  if grep -qE "^$k:" "$f"; then
    sed -i -E "0,/^$k:.*/s||$k: $v|" "$f"
  else
    sed -i "0,/^---$/!{0,/^---$/s|^---$|$k: $v\n---|}" "$f"
  fi
}

cmd_show() {
  if [ ! -f "$STATE" ]; then
    printf 'No active story. The phase lock is off.\n'
    return 0
  fi
  printf 'Active story\n------------\n'
  sed -e 's/^/  /' "$STATE"
  local id phase
  id=$(grep -E '^STORY_ID=' "$STATE" | cut -d= -f2-)
  phase=$(grep -E '^PHASE=' "$STATE" | cut -d= -f2-)
  printf '\nWrites allowed in %s:\n  %s\n' "$phase" \
    "$(grep -E "^[[:space:]]*$phase[[:space:]]*\|" "$PHASES" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')"
  [ -f "$STORIES/$id.md" ] && printf '\nStory: docs/backlog/stories/%s.md\n' "$id"
}

cmd_board() {
  printf '%-14s %-12s %-10s %s\n' ID PHASE STATUS TITLE
  printf '%-14s %-12s %-10s %s\n' -------------- ------------ ---------- -----------------------------
  for f in "$STORIES"/*.md; do
    [ -e "$f" ] || continue
    printf '%-14s %-12s %-10s %s\n' \
      "$(frontmatter "$f" id)" "$(frontmatter "$f" phase)" \
      "$(frontmatter "$f" status)" "$(frontmatter "$f" title)"
  done
}

cmd_set() {
  local id="${1:-}" phase="${2:-}"
  [ -n "$id" ] && [ -n "$phase" ] || die "usage: phase.sh set <story-id> <PHASE>"
  phase="$(printf '%s' "$phase" | tr 'a-z' 'A-Z')"
  valid_phase "$phase" || die "unknown phase '$phase'. Known: $(awk -F'|' '!/^#|^$/{gsub(/ /,"",$1); printf "%s ", $1}' "$PHASES")"

  local file="$STORIES/$id.md"
  [ -f "$file" ] || die "no story file at docs/backlog/stories/$id.md — create it first (scripts/new-story.sh)"

  local slug type branch
  slug="$(frontmatter "$file" slug)"
  [ -z "$slug" ] && slug="$(frontmatter "$file" title | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed -e 's/^-//' -e 's/-$//' | cut -c1-40)"
  type="$(frontmatter "$file" type)"; [ -z "$type" ] && type="feature"
  branch="$(frontmatter "$file" branch)"; [ -z "$branch" ] && branch="story/$id-$slug"

  mkdir -p "$(dirname "$STATE")"
  cat > "$STATE" <<EOF
# Written by scripts/phase.sh — do not edit by hand.
STORY_ID=$id
STORY_SLUG=$slug
STORY_TYPE=$type
PHASE=$phase
BRANCH=$branch
UPDATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

  set_frontmatter "$file" phase "$phase"
  set_frontmatter "$file" status "$(status_for_phase "$phase")"
  set_frontmatter "$file" branch "$branch"

  printf '%s -> %s\n' "$id" "$phase"
  printf 'writes allowed: %s\n' \
    "$(grep -E "^[[:space:]]*$phase[[:space:]]*\|" "$PHASES" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')"
}

cmd_clear() {
  rm -f "$STATE"
  printf 'Cleared. No active story; the phase lock is off.\n'
}

case "${1:-show}" in
  show)  cmd_show ;;
  board) cmd_board ;;
  set)   shift; cmd_set "$@" ;;
  clear) cmd_clear ;;
  *)     die "usage: phase.sh {show|board|set <id> <PHASE>|clear}" ;;
esac
