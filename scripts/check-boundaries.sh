#!/usr/bin/env bash
# Defence in depth for CI (and for humans working outside Claude Code).
#
# The phase-guard hook enforces the RED/GREEN lock at write time inside a
# session. This checks the same invariants after the fact, on a diff, where
# the hook was never in the loop.
#
#   bash scripts/check-boundaries.sh [base-ref]      (default: origin/main)

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
BASE="${1:-origin/main}"
fail=0
note() { printf '  %s\n' "$1"; }
problem() { printf 'FAIL  %s\n' "$1"; fail=1; }
ok() { printf 'ok    %s\n' "$1"; }

# --- 1. Story files are well formed ----------------------------------------
story_fail_start=$fail
for f in docs/backlog/stories/*.md; do
  [ -e "$f" ] || continue
  base=$(basename "$f" .md)
  head -1 "$f" | grep -q '^---' || { problem "$f: missing YAML frontmatter"; continue; }
  for key in id title type status phase; do
    grep -qE "^$key:" "$f" || problem "$f: frontmatter missing '$key'"
  done
  fid=$(grep -E '^id:' "$f" | head -1 | sed -E 's/^id:[[:space:]]*//')
  [ "$fid" = "$base" ] || problem "$f: frontmatter id '$fid' does not match filename '$base'"
  ph=$(grep -E '^phase:' "$f" | head -1 | sed -E 's/^phase:[[:space:]]*//')
  grep -qE "^[[:space:]]*$ph[[:space:]]*\|" .claude/harness/phases.conf \
    || problem "$f: unknown phase '$ph'"
  grep -q '^## Acceptance criteria' "$f" || problem "$f: no '## Acceptance criteria' section"
done
[ "$fail" -eq "$story_fail_start" ] && ok "story files validated"

# --- 2. Runtime state must never be committed -------------------------------
if git ls-files --error-unmatch .claude/state/current-story.env >/dev/null 2>&1; then
  problem ".claude/state/current-story.env is tracked; it is machine-local state"
fi
ok "harness state not tracked"

# --- 3. Production code arrives with tests ----------------------------------
if git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  changed=$(git diff --name-only "$BASE"...HEAD 2>/dev/null || true)
  src=0; tst=0
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    cat=$(CLAUDE_PROJECT_DIR="$ROOT" bash -c '. .claude/hooks/lib.sh; classify "$1"' _ "$p")
    case "$cat" in
      source) src=$((src+1)) ;;
      test)   tst=$((tst+1)) ;;
    esac
  done <<< "$changed"

  story_type=""
  br=$(git rev-parse --abbrev-ref HEAD)
  sid=$(printf '%s' "$br" | sed -nE 's|^story/([A-Za-z0-9]+-[0-9]+).*|\1|p')
  [ -n "$sid" ] && [ -f "docs/backlog/stories/$sid.md" ] && \
    story_type=$(grep -E '^type:' "docs/backlog/stories/$sid.md" | head -1 | sed -E 's/^type:[[:space:]]*//')

  if [ "$src" -gt 0 ] && [ "$tst" -eq 0 ]; then
    case "$story_type" in
      bootstrap|chore|spike) note "$src source file(s) without tests — allowed for a '$story_type' story" ;;
      *) problem "$src source file(s) changed with no test changes. Production code ships with the test that demanded it." ;;
    esac
  else
    ok "source changes accompanied by test changes ($src source, $tst test)"
  fi

  if [ -n "$sid" ]; then
    ph=$(grep -E '^phase:' "docs/backlog/stories/$sid.md" | head -1 | sed -E 's/^phase:[[:space:]]*//')
    case "$ph" in
      REVIEW|DONE) ok "story $sid is in $ph" ;;
      *) problem "story $sid is in phase '$ph'; a PR should be opened from REVIEW or DONE" ;;
    esac
  fi
else
  note "base ref '$BASE' not available; skipped diff checks"
fi

exit $fail
