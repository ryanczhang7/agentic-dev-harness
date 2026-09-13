#!/usr/bin/env bash
# Tests for scripts/doctor.sh - specifically the discovery checks, which are
# the answer to a gate whose scope collapsed to nothing without anyone noticing.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

FIX="$(make_project_fixture)"
trap 'rm -rf "$FIX"' EXIT

doctor() { ( cd "$FIX" && bash scripts/doctor.sh 2>&1 ); }

describe "discovery: the runner is asked what it can see"

write_conf "$FIX" <<'EOF'
gate      | unit     | required | . | printf 'Tests  1 passed (1)\n'
evidence  | unit     | Tests +[1-9][0-9]* passed
discovery | platform | . | printf 'src/platform/gl.test.ts\n' | grep -q "src/platform/"
EOF
out="$(doctor)"
assert_contains "a directory the runner can see" "ok       platform     discovered" "$out"

write_conf "$FIX" <<'EOF'
gate      | unit     | required | . | printf 'Tests  1 passed (1)\n'
evidence  | unit     | Tests +[1-9][0-9]* passed
discovery | platform | . | printf 'src/ui/app.test.ts\n' | grep -q "src/platform/"
EOF
out="$(doctor)"
assert_contains "a directory it cannot" "MISSING  platform" "$out"
assert_contains "says what that costs"  "committed and never run" "$out"

describe "discovery: nothing declared is reported, not skipped silently"

write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  1 passed (1)\n'
evidence | unit | Tests +[1-9][0-9]* passed
EOF
out="$(doctor)"
assert_contains "the section still appears" "none declared" "$out"


describe "the harness says which version it is"

# A vendored copy cannot be dated from the outside: it has the consuming
# project's git history, not this one's. Two field reports in a row arrived
# reporting defects that had been fixed upstream for weeks, and neither could
# say which harness it had measured - so every finding had to be re-verified by
# hand before it could be called already-fixed. The stamp is what makes
# "already fixed in 2026-09-11" a comparison instead of an afternoon.
out="$(doctor)"
assert_contains "doctor prints the harness version" "harness ver" "$out"
assert_contains "and it is the one in the file" \
  "$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$REPO_ROOT/.claude/harness/VERSION" | head -1)" "$out"

# Absent, it says so rather than printing an empty field. A blank where a
# version should be reads as "no version", which is the one thing it must not
# be confused with - an unstamped copy is an OLD copy, from before stamping.
mv "$FIX/.claude/harness/VERSION" "$FIX/.claude/harness/VERSION.hidden" 2>/dev/null
out="$(doctor)"
assert_contains "an unstamped copy is named as one" "unstamped" "$out"
mv "$FIX/.claude/harness/VERSION.hidden" "$FIX/.claude/harness/VERSION" 2>/dev/null

# ---------------------------------------------------------------------------
describe "CI is asked whether it runs the harness's own checks"

# The gap this closes. `.github/workflows/**` is PROJECT-owned, so a refresh
# never touches it - correctly, since a project adds its toolchain setup there.
# The consequence nobody accounted for is that the template's workflow and the
# project's diverge from the moment of bootstrap, with nothing comparing them.
#
# It is not hypothetical. A real project's gates.yml ran `gates.sh` but not
# `selftest.sh` and not `gates.sh --audit`, so the harness's own tests had never
# executed in its CI - which is how a re-vendor there went green with two suites
# failing. The project could not have noticed: the suite that would have told it
# is the suite its CI does not run.
#
# doctor is the right home rather than the selftest, for exactly that reason: a
# check that only runs inside the thing that is not running cannot report it.
mkdir -p "$FIX/.github/workflows"
cat > "$FIX/.github/workflows/gates.yml" <<'YML'
name: gates
on: [pull_request]
jobs:
  gates:
    runs-on: ubuntu-latest
    steps:
      - run: pnpm install --frozen-lockfile
      - run: bash scripts/gates.sh
YML
out="$(doctor)"
assert_contains "a workflow that never runs the harness tests is named" "selftest.sh" "$out"
assert_contains "and says what it costs" "never run" "$out"

# The boundaries half too: gates.sh judges the code, check-boundaries.sh judges
# the commit, and CI running only the first is the state that let a story reach
# main with a phase the lock would have refused.
assert_contains "and the commit-level check" "check-boundaries.sh" "$out"

# Satisfied by ANY workflow file, because splitting them across jobs is a
# legitimate layout and this must not dictate one.
cat > "$FIX/.github/workflows/boundaries.yml" <<'YML'
name: boundaries
on: [pull_request]
jobs:
  boundaries:
    runs-on: ubuntu-latest
    steps:
      - run: bash scripts/check-boundaries.sh origin/main
YML
cat > "$FIX/.github/workflows/gates.yml" <<'YML'
name: gates
on: [pull_request]
jobs:
  gates:
    runs-on: ubuntu-latest
    steps:
      - run: pnpm install --frozen-lockfile
      - run: bash scripts/selftest.sh
      - run: bash scripts/gates.sh
YML
out="$(doctor)"
assert_contains "a complete pair reports ok" "ok       ci" "$out"
case "$out" in
  *"never run"*) _bad "and says nothing is missing" "still complaining: $out" ;;
  *) _ok "and says nothing is missing" ;;
esac

# No workflows at all is not a failure - a project may not use CI, and doctor
# must not invent a requirement. It says so and moves on.
rm -rf "$FIX/.github"
out="$(doctor)"
case "$out" in
  *"never run"*) _bad "no workflows is not a complaint" "complained anyway: $out" ;;
  *) _ok "no workflows is not a complaint" ;;
esac
summary "doctor"
