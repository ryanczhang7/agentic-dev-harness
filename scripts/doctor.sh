#!/usr/bin/env bash
# Check that this machine can actually run the harness and this project.
#
#   bash scripts/doctor.sh
#
# Two layers:
#   1. The harness itself - needs only git and bash.
#   2. The project - every executable named by a gate or task in
#      .claude/harness/project.conf must be on PATH.
#
# Run it after cloning, after picking a stack, and any time a gate fails with
# "command not found".

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$ROOT/.claude/harness/project.conf"
missing=0
trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

check() { # <executable> <what it is for>
  if command -v "$1" >/dev/null 2>&1; then
    printf '  ok       %-12s %s\n' "$1" "$(command -v "$1")"
  else
    printf '  MISSING  %-12s needed for: %s\n' "$1" "$2"
    missing=$((missing+1))
  fi
}

printf 'Harness prerequisites\n'
check git  "everything"
check bash "the hooks and these scripts"
printf '  ok       %-12s %s\n' "bash ver" "${BASH_VERSION%%(*}"

printf '\nHarness integrity\n'
for f in phase-guard.sh inject-state.sh gate-reminder.sh statusline.sh lib.sh; do
  if [ -f "$ROOT/.claude/hooks/$f" ]; then
    if bash -n "$ROOT/.claude/hooks/$f" 2>/dev/null; then
      printf '  ok       %s\n' ".claude/hooks/$f"
    else
      printf '  BROKEN   %s (syntax error)\n' ".claude/hooks/$f"; missing=$((missing+1))
    fi
  else
    printf '  MISSING  %s\n' ".claude/hooks/$f"; missing=$((missing+1))
  fi
done
for f in paths.conf phases.conf project.conf; do
  [ -f "$ROOT/.claude/harness/$f" ] \
    && printf '  ok       %s\n' ".claude/harness/$f" \
    || { printf '  MISSING  %s\n' ".claude/harness/$f"; missing=$((missing+1)); }
done

printf '\nProject toolchain (from project.conf)\n'
BOOTSTRAPPED="$(grep -E '^BOOTSTRAPPED=' "$CONF" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]')"
seen=""
found_any=0
while IFS= read -r line; do
  case "$(trim "$line")" in ''|'#'*) continue ;; esac
  case "$line" in *'|'*) ;; *) continue ;; esac
  kind=$(trim "$(printf '%s' "$line" | cut -d'|' -f1)")
  case "$kind" in gate|task) ;; *) continue ;; esac
  id=$(trim  "$(printf '%s' "$line" | cut -d'|' -f2)")
  cmd=$(trim "$(printf '%s' "$line" | cut -d'|' -f5-)")
  [ -z "$cmd" ] && continue
  found_any=1
  exe=$(printf '%s' "$cmd" | awk '{print $1}')
  case " $seen " in *" $exe "*) continue ;; esac
  seen="$seen $exe"
  check "$exe" "$kind '$id'"
done < "$CONF"

if [ "$found_any" = 0 ]; then
  printf '  (nothing configured yet)\n'
  printf '\nproject.conf has no commands, so there is no toolchain to check.\n'
  printf 'This is expected before /plan-product has chosen a stack.\n'
  printf 'Next: /create-product, then /plan-product, then /setup-environment.\n'
  exit 0
fi

printf '\n'
printf '\nProject dependencies\n'
# A global toolchain on PATH is not the same as this project's libraries being
# installed. Checked by manifest: if the manifest exists, its install directory
# must too. Only Node and Python are checked - cargo fetches on build, and Godot
# addons are committed with the project.
#
# Limitation: a monorepo with per-workspace node_modules is not detected here.
dep_found=0
dep_check() { # <manifest> <install dir> <label>
  [ -e "$ROOT/$1" ] || return 0
  dep_found=1
  if [ -e "$ROOT/$2" ]; then
    printf '  ok       %-10s %s present\n' "$3" "$2"
  else
    printf '  MISSING  %-10s %s exists but %s/ is not installed\n' "$3" "$1" "$2"
    printf '  %-10s run: bash scripts/task.sh install\n' ""
    missing=$((missing+1))
  fi
}
dep_check package.json      node_modules node
dep_check pyproject.toml    .venv        python
dep_check requirements.txt  .venv        python
[ "$dep_found" = 0 ] && printf '  (no dependency manifests found yet)\n'
printf '
'

if [ "$missing" -gt 0 ]; then
  printf '%d thing(s) missing.\n' "$missing"
  [ -f "$ROOT/docs/wiki/environment.md" ] \
    && printf 'Install instructions for this project: docs/wiki/environment.md\n' \
    || printf 'No docs/wiki/environment.md yet. Run /setup-environment to write one.\n'
  exit 1
fi

printf 'Everything this project needs is installed.'
[ "$BOOTSTRAPPED" = "yes" ] || printf ' (project.conf is not bootstrapped yet.)'
printf '\n'
