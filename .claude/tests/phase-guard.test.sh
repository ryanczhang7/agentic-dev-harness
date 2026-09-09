#!/usr/bin/env bash
# Regression suite for .claude/hooks/phase-guard.sh.
#
# Two halves, and the first is the one that matters:
#
#   * Commands that must NOT be blocked. A lock with false positives teaches
#     the agent that blocks are noise, which is precisely the instinct law 5
#     of CLAUDE.md exists to suppress. Every case here was a real block
#     observed in a real session, or is one quoting away from being one.
#   * Commands that MUST be blocked, asserted on the path the guard reports -
#     not merely on the fact that something was blocked. A guard that refuses
#     `sed -i 's|a|b|' src/main.ts` because it thinks the path is `s` is
#     right by accident and will be wrong the next time.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

FIX="$(make_fixture)"
trap 'rm -rf "$FIX"' EXIT

# ---------------------------------------------------------------------------
describe "RED: quoted arguments are not shell syntax"
set_phase "$FIX" RED

# A sed script whose delimiter is `|`. The command writes .gitignore (harness,
# allowed in RED); the sed script must not be mistaken for the target.
assert_allowed "$FIX" 'sed -i "s|^a/$|a/\nb/|" .gitignore' 'sed -i with | delimiter, writing harness'

# An arrow inside a quoted awk program is not a redirect. This one is a READ:
# the old extractor blocked a pipeline that wrote nothing at all.
assert_allowed "$FIX" "awk '/^## Handoff: RED -> GREEN/,/^## Gate results/' docs/notes.md" 'arrow inside a quoted awk program'

# An operator inside a quoted grep pattern, reading a source file in RED.
assert_allowed "$FIX" "grep -oE 'x>y' src/main.ts" 'operator inside a quoted grep pattern'

# An operator inside a commit message.
assert_allowed "$FIX" 'git commit -m "fix: a > b"' 'operator inside a commit message'

# A heredoc body is data, not shell. The only real target here is docs/notes.md.
assert_allowed "$FIX" 'cat > docs/notes.md <<'"'"'EOF'"'"'
to write it by hand: cat > src/main.ts
EOF' 'heredoc body containing a redirect'

# An escaped operator outside quotes is not an operator either.
assert_allowed "$FIX" 'echo "a \> b" > docs/notes.md' 'escaped redirect inside a string'

# Plain reads.
assert_allowed "$FIX" 'cat src/main.ts' 'reading source'
assert_allowed "$FIX" 'grep -rn "export" src/' 'grepping source'
assert_allowed "$FIX" 'git diff -- src/main.ts' 'diffing source'

# ---------------------------------------------------------------------------
describe "RED: real writes to source are still blocked"

assert_blocked "$FIX" 'echo x > src/main.ts'            src/main.ts 'redirect into source'
assert_blocked "$FIX" 'echo x >> src/main.ts'           src/main.ts 'append into source'
assert_blocked "$FIX" 'echo x | tee src/main.ts'        src/main.ts 'tee into source'
assert_blocked "$FIX" 'cp docs/notes.md src/main.ts'    src/main.ts 'cp onto source'
assert_blocked "$FIX" 'mv docs/notes.md src/main.ts'    src/main.ts 'mv onto source'
assert_blocked "$FIX" 'rm src/main.ts'                  src/main.ts 'rm source'
assert_blocked "$FIX" 'touch src/new.ts'                src/new.ts  'touch new source'

# The one the misparse was hiding: the target is the file, not the sed script.
assert_blocked "$FIX" "sed -i 's|a|b|' src/main.ts"     src/main.ts 'sed -i with | delimiter, writing source'
assert_blocked "$FIX" "sed -i 's/a/b/' src/main.ts"     src/main.ts 'sed -i with / delimiter, writing source'

# A quoted target keeps its spaces instead of being split into fragments.
assert_blocked "$FIX" 'echo x > "src/my file.ts"'       'src/my file.ts' 'quoted target containing a space'

assert_blocked "$FIX" 'echo x > src/main.ts' src/main.ts 'redirect into source (Bash)'
r="$(guard "$FIX" Write file_path src/main.ts)"
assert_contains "Write tool is blocked in RED" "category: source" "$r"
r="$(guard "$FIX" Edit file_path "$FIX/src/main.ts")"
assert_contains "Edit tool is blocked on an absolute path" "category: source" "$r"

# ---------------------------------------------------------------------------
describe "GREEN: tests are frozen, source is not"
set_phase "$FIX" GREEN

assert_allowed "$FIX" 'echo x > src/main.ts' 'writing source in GREEN'
assert_blocked "$FIX" 'echo x > tests/main.test.ts' tests/main.test.ts 'writing a test in GREEN'
r="$(guard "$FIX" Write file_path tests/main.test.ts)"
assert_contains "Write to a test is blocked in GREEN" "category: test" "$r"

# ---------------------------------------------------------------------------
describe "Generated output is not source"
set_phase "$FIX" RED

# Ignored by the fixture's .gitignore, so not authored, so not the lock's
# business - in any phase.
assert_allowed "$FIX" 'rm -rf .vitest'           'rm an ignored tool directory'
assert_allowed "$FIX" 'rm -rf playwright-report' 'rm an ignored report directory'
assert_allowed "$FIX" 'rm -rf node_modules'      'rm a vendor directory'
assert_allowed "$FIX" 'rm -rf dist'              'rm a build directory'

# An ignored path that does not exist yet still classifies from the rules.
assert_allowed "$FIX" 'echo x > .vitest/log.txt' 'writing inside an ignored directory'

# A TRACKED file is never "ignored", even if a rule would otherwise match it:
# git check-ignore consults the index, and so this stays source.
assert_blocked "$FIX" 'echo x > src/main.ts' src/main.ts 'tracked source is still source'

# ---------------------------------------------------------------------------
describe "No active story means no lock"
set_phase "$FIX" ""

assert_allowed "$FIX" 'echo x > src/main.ts' 'writing source with no story'
r="$(guard "$FIX" Write file_path src/main.ts)"
assert_eq "Write tool with no story" "" "$r"

summary "phase-guard"
