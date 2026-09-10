#!/usr/bin/env bash
# The Stop hook: does it block a story reported complete on unverified code,
# and does it stay quiet about the gates' own output?
#
# The second question is the one that needed a suite. The hook decides
# staleness from file mtimes, and a gate run writes coverage reports, build
# directories and bundler caches as it goes - so an ad-hoc verification run
# afterwards regenerates them and the hook blocked on `coverage/base.css` with
# a clean `git status`. That punishes the extra verification the rest of the
# harness asks for, which is worse than not having the hook.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

FIX="$(make_fixture)"
trap 'rm -rf "$FIX"' EXIT

STAMP="$FIX/.claude/state/last-gate-run"

# stop [stop_hook_active]   Runs the real hook and echoes the block reason, or
# nothing when the stop was allowed.
stop() {
  local out r
  out="$(printf '{"stop_hook_active":%s}' "${1:-false}" \
    | CLAUDE_PROJECT_DIR="$FIX" bash "$REPO_ROOT/.claude/hooks/gate-reminder.sh" 2>&1)"
  case "$out" in
    *'"decision":"block"'*) ;;
    *) printf ''; return 0 ;;
  esac
  r="${out#*reason\":\"}"
  printf '%s' "${r%%\"*}"
}

assert_blocks() { # <label> <needle>
  local r; r="$(stop)"
  if [ -z "$r" ]; then _bad "blocks: $1" "the stop was allowed"
  else assert_contains "blocks: $1" "$2" "$r"; fi
}

assert_allows() { # <label>
  local r; r="$(stop)"
  if [ -z "$r" ]; then _ok "allows: $1"
  else _bad "allows: $1" "blocked with: $r"; fi
}

# stamp_run <result>   A finished gate run: the whole fixture settles into the
# past and the stamp lands after it, so that anything touched next is
# unambiguously newer. Fixed dates rather than sleeps - mtime granularity is a
# whole second on some filesystems and a suite that races it fails at random.
stamp_run() {
  find "$FIX" -type f -exec touch -d '2020-01-01 00:00:00' {} + 2>/dev/null
  printf 'RESULT=%s\n' "$1" > "$STAMP"
  touch -d '2020-06-01 00:00:00' "$STAMP"
}

# --- the phases it watches ---------------------------------------------------
describe "the hook only watches GREEN and GATES"

stamp_run pass
for ph in PLANNED RED REVIEW DONE; do
  set_phase "$FIX" "$ph"
  touch "$FIX/src/main.ts"
  assert_allows "$ph is not this hook's business"
done

set_phase "$FIX" ""
assert_allows "no active story"

# --- the reasons it blocks ---------------------------------------------------
describe "GREEN and GATES: unverified code does not get to stop"

set_phase "$FIX" GREEN
rm -f "$STAMP"
assert_blocks "the gates have never been run" "has not been run"

stamp_run fail
assert_blocks "the last recorded run failed" "FAILED"

stamp_run pass
touch "$FIX/src/main.ts"
assert_blocks "a source file changed after the run" "src/main.ts"

stamp_run pass
touch "$FIX/tests/main.test.ts"
assert_blocks "a test file changed after the run" "tests/main.test.ts"

stamp_run pass
assert_allows "nothing changed since a passing run"

set_phase "$FIX" GATES
touch "$FIX/src/main.ts"
assert_blocks "GATES is watched too" "src/main.ts"

# --- the gates' own exhaust --------------------------------------------------
describe "generated output is not a code change"

# Every path here is gitignored, and every one of them is written BY a gate
# run: the coverage report, the build directory, the test runner's cache. A
# hook that counts these blocks forever, because running the gates again
# recreates them. `src/generated/` is the case a prune list in the hook cannot
# catch, which is why .gitignore is the authority instead.
printf 'node_modules/\ndist/\n.vitest/\ncoverage/\nsrc/generated/\n' > "$FIX/.gitignore"
git -C "$FIX" add .gitignore >/dev/null 2>&1
set_phase "$FIX" GREEN
stamp_run pass
mkdir -p "$FIX/coverage" "$FIX/dist/assets" "$FIX/.vitest/deps"
printf 'body{}\n'   > "$FIX/coverage/base.css"
printf 'x\n'        > "$FIX/dist/assets/app.js"
printf 'x\n'        > "$FIX/.vitest/deps/chunk.js"
assert_allows "a coverage report, a build directory and a runner cache"

stamp_run pass
mkdir -p "$FIX/src/generated"
printf 'export const x = 1\n' > "$FIX/src/generated/api.ts"
assert_allows "generated output nested inside a source directory"

# The floor: ignoring generated output must not stop it noticing real ones.
touch "$FIX/src/main.ts"
assert_blocks "a real source change alongside generated output" "src/main.ts"

# --- the loop guard ----------------------------------------------------------
describe "the hook never loops on itself"

stamp_run pass
touch "$FIX/src/main.ts"
r="$(stop true)"
assert_eq "stop_hook_active suppresses it" "" "$r"

summary "gate-reminder"
