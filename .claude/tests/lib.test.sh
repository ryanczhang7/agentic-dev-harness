#!/usr/bin/env bash
# Unit tests for .claude/hooks/lib.sh - the path classifier and the shell-quote
# masker the phase guard is built on.
#
# phase-guard.test.sh drives the hook end to end; this covers the pieces
# directly, so that a failure says which one broke.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

FIX="$(make_fixture)"
trap 'rm -rf "$FIX"' EXIT

export CLAUDE_PROJECT_DIR="$FIX"
. "$REPO_ROOT/.claude/hooks/lib.sh"

# ---------------------------------------------------------------------------
describe "classify: paths.conf rules"

for case in \
  "src/main.ts=source" \
  "src/deep/nested/thing.ts=source" \
  "tests/main.test.ts=test" \
  "src/main.test.ts=test" \
  "docs/backlog/stories/T-1.md=docs" \
  "README.md=docs" \
  ".claude/hooks/lib.sh=harness" \
  ".claude/tests/lib.test.sh=harness" \
  "scripts/gates.sh=harness" \
  ".github/workflows/gates.yml=harness" \
  "CLAUDE.md=harness" \
  ".gitignore=harness" \
  "package.json=config" \
  "tsconfig.json=config" \
  "vite.config.ts=config" \
  "vitest.config.ts=test" \
  "node_modules/left-pad/index.js=vendor" \
  "node_modules=vendor" \
  "dist/bundle.js=vendor" \
  ; do
  assert_eq "classify ${case%%=*}" "${case#*=}" "$(classify "${case%%=*}")"
done

assert_eq "classify of nothing is outside" "outside" "$(classify "")"

# ---------------------------------------------------------------------------
describe "classify: git decides what is generated"

# In the fixture's .gitignore, matched by no paths.conf rule.
assert_eq "an ignored directory"        "ignored" "$(classify ".vitest")"
assert_eq "a file inside one"           "ignored" "$(classify ".vitest/screenshot.png")"
assert_eq "an ignored report directory" "ignored" "$(classify "playwright-report")"

# Tracked, so authored, whatever any rule says.
assert_eq "a tracked source file" "source" "$(classify "src/main.ts")"

# Not ignored and not matched: the conservative default.
assert_eq "an unknown new path" "source" "$(classify "src/brand-new.ts")"

# ---------------------------------------------------------------------------
describe "to_rel"

assert_eq "a relative path"        "src/main.ts" "$(to_rel "src/main.ts")"
assert_eq "a dot-relative path"    "src/main.ts" "$(to_rel "./src/main.ts")"
assert_eq "an absolute path"       "src/main.ts" "$(to_rel "$FIX/src/main.ts")"
assert_eq "a backslash path"       "src/main.ts" "$(to_rel "$(printf '%s' "$FIX" | tr '/' '\134')\\src\\main.ts")"
assert_eq "somewhere else on disk" ""            "$(to_rel "/somewhere/else/main.ts")"

# ---------------------------------------------------------------------------
describe "mask_shell_quotes: operators inside quotes stop being operators"

mask() { printf '%s' "$1" | mask_shell_quotes; }
roundtrip() { printf '%s' "$1" | mask_shell_quotes | unmask_shell_quotes; }

# What the masker is for: no operator survives inside a quoted span.
has_operator() { printf '%s' "$1" | grep -qE '[|&;<>]'; }

for cmd in \
  "sed -i 's|a|b|' f.txt" \
  "awk '/A -> B/' f.txt" \
  "grep -oE 'x>y' f.txt" \
  'git commit -m "fix: a > b"' \
  'echo "a && b; c"' \
  'git commit -m "$(printf "%s\n%s" "GATES -> REVIEW" "set the phase first")"' \
  ; do
  masked="$(mask "$cmd")"
  # Everything after the first quote is data; only the command word and the
  # options before it may still hold punctuation, and they hold none here.
  if has_operator "${masked#*[\'\"]}"; then
    _bad "masks operators in: $cmd" "still operator-bearing: $masked"
  else
    _ok "masks operators in: $cmd"
  fi
  assert_eq "round trip: $cmd" "$cmd" "$(roundtrip "$cmd")"
done

describe "mask_shell_quotes: structure outside quotes is preserved"

for cmd in \
  'echo hi > out.txt' \
  'cat a.txt | tee b.txt' \
  'rm -rf dist && mkdir dist' \
  'sed -i "s/a/b/" f.txt' \
  ; do
  assert_eq "round trip: $cmd" "$cmd" "$(roundtrip "$cmd")"
done

assert_contains "an unquoted redirect survives masking" ">" "$(mask 'echo hi > out.txt')"
assert_contains "an unquoted pipe survives masking"     "|" "$(mask 'cat a | tee b')"

describe "mask_shell_quotes: heredocs and escapes"

hd="$(mask "$(printf 'cat > notes.md <<%sEOF%s\nrun: cat > src/main.ts\nEOF\n' "'" "'")")"
assert_contains "the real redirect survives" "> notes.md" "$hd"
if printf '%s' "$hd" | grep -q '> src/main.ts'; then
  _bad "a heredoc body is masked" "the body's redirect survived: $hd"
else
  _ok "a heredoc body is masked"
fi

assert_eq "an escaped operator is masked" "0" \
  "$(mask 'echo a \> b' | grep -cE '>')"

# ---------------------------------------------------------------------------
describe "gate_tree_hash: covers what the gates judge, and only that"

# The hash is the identity of "the code the gates ran against". A change to a
# file no gate reads must not move it, or every prompt edit after the last run
# forces a re-run before the PR is acceptable - and it does have to move on a
# change to anything a gate does read, or the record proves nothing.
HARNESS_ROOT="$FIX"
mkdir -p "$FIX/.claude/commands" "$FIX/.claude/hooks"
printf '# advance\n' > "$FIX/.claude/commands/advance-story.md"
printf 'x() { :; }\n' > "$FIX/.claude/hooks/lib.sh"
h0="$(gate_tree_hash)"
printf '# advance, reworded\n' > "$FIX/.claude/commands/advance-story.md"
assert_eq "a command prompt does not move the hash" "$h0" "$(gate_tree_hash)"
printf '# a wiki page\n' > "$FIX/docs/notes.md"
assert_eq "a docs file does not move the hash"      "$h0" "$(gate_tree_hash)"
printf 'y() { :; }\n' > "$FIX/.claude/hooks/lib.sh"
h1="$(gate_tree_hash)"
if [ "$h1" = "$h0" ]; then _bad "a hook moves the hash" "unchanged: $h0"; else _ok "a hook moves the hash"; fi
printf 'export const x = 2\n' > "$FIX/src/main.ts"
h2="$(gate_tree_hash)"
if [ "$h2" = "$h1" ]; then _bad "source moves the hash" "unchanged: $h1"; else _ok "source moves the hash"; fi

# ---------------------------------------------------------------------------
describe "path_is_implausible: a failed parse is inconclusive, not a violation"

# The tokens on the left were all reported as the `path:` of a real denial, on
# commands that wrote nothing. None of them is a path; the guard declines to
# judge them rather than treating its own parse failure as evidence.
for t in '=' '[^' '--' '>' '' '`mktemp`' '$TMPDIR/x' 'a(b)'; do
  if path_is_implausible "$t"; then _ok "implausible: '$t'"
  else _bad "implausible: '$t'" "the guard believed this was a path"; fi
done

# The other half of the rule, and the one that keeps it honest: everything a
# real project actually names must still be judged. A bracketed route segment
# is a real path in more than one framework.
for t in 'src/main.ts' 'src/app/[id]/page.tsx' 'src/my file.ts' '.gitignore' \
         'a' 'docs/wiki/architecture.md' 'src/a-b_c.2.ts'; do
  if path_is_implausible "$t"; then _bad "plausible: '$t'" "the guard refused to judge a real path"
  else _ok "plausible: '$t'"; fi
done

summary "lib"
