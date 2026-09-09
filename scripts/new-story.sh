#!/usr/bin/env bash
# Create a story file from the canonical template.
#   bash scripts/new-story.sh WORLD-014 "Hex grid renders at 60fps" [epic-id] [type]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
id="${1:-}"; title="${2:-}"; epic="${3:-}"; type="${4:-feature}"
[ -n "$id" ] && [ -n "$title" ] || { echo 'usage: new-story.sh <ID> "<title>" [epic-id] [feature|fix|chore|bootstrap|spike]' >&2; exit 2; }

slug=$(printf '%s' "$title" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed -e 's/^-//' -e 's/-$//' | cut -c1-40)
slug="${slug%-}"
file="$ROOT/docs/backlog/stories/$id.md"
[ -e "$file" ] && { echo "error: $file already exists" >&2; exit 1; }

cat > "$file" <<EOF
---
id: $id
title: $title
slug: $slug
epic: ${epic:-}
type: $type
status: todo
phase: PLANNED
branch: story/$id-$slug
depends_on: []
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it. -->

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC. -->

- **AC-1** — Given <state>, when <action>, then <observable outcome>.
- **AC-2** — Given <state>, when <action>, then <observable outcome>.

## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

## Handoff: RED -> GREEN

<!-- Filled by the Test Developer at the end of RED. This is the ONLY channel
     to the Feature Developer, whose context is fresh. Must contain:
       * the exact command that runs the new tests
       * the failure output, and why it is the RIGHT failure
       * every file touched
       * anything discovered that changes the approach -->

## Gate results

<!-- Filled during GATES from scripts/gates.sh output. -->

## Gate probes

<!-- REQUIRED if this story adds or changes a gate, its command, or its
     evidence line. Omit the section entirely otherwise.
     A gate that has never been observed to fail is not a gate: break the thing
     it guards, run the gate, paste the failure, revert. One block per gate:
       * what was broken, and where
       * the gate output proving it failed
       * confirmation the probe was reverted -->

## Notes

EOF
printf 'created docs/backlog/stories/%s.md\n' "$id"
printf 'next: bash scripts/phase.sh set %s RED\n' "$id"
