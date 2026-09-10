#!/usr/bin/env bash
# Do the deny rules in .claude/settings.json still match what the state
# directory actually holds?
#
# `.claude/state/` used to be denied wholesale - `Write(./.claude/state/**)` -
# which was right about the two files that carry evidence and wrong about
# everything else in there. It also covered the two TRACKED documents, so the
# README describing the directory could not be edited by the tools it describes,
# and it covered tool exhaust, so a leftover `mutations/*.bak` - which the
# harness itself treats as a "the restore failed, go and look" signal - could not
# be cleaned up after being acted on.
#
# The rules are now per file, which is more accurate and less durable: a state
# file added later gets no protection until somebody remembers a line, and that
# is a worse failure than the one the narrowing fixed. So it is not left to
# discipline. `.claude/state/README.md` carries a `Hand-editable` column and this
# suite checks the two against each other in BOTH directions.
#
# The checks are a function over a (settings, README) PAIR rather than statements
# about the live files, for one reason: the live files are the only ones a suite
# like this is tempted to assert against, and then every assertion in it passes on
# its first run and forever, whether or not it checks anything. Mutating the real
# settings.json to earn them is not an option either - the runtime reads
# permissions and hooks live, so a suite that edits them mid-run is changing the
# rules it is running under. So `problems` takes a pair, the real pair must produce
# none, and each way of getting it wrong is a fixture that must produce a specific
# one.
#
# Verified separately by probe, since the rules are enforced by the runtime and
# not by anything in this repository: a file-specific `Write(...)`/`Edit(...)`
# deny blocks a Bash append and a Bash `rm` of that exact path, not merely the
# Write and Edit tools. The narrowing gave up nothing on the two files that matter.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

TAB="$(printf '\t')"

# The tools a `no` row must be denied to. Add one here and every `no` row needs a
# matching rule; that is the point, so this list is short and each entry is a
# decision.
#
#   Write, Edit    the two that exist in every build and can write any file.
#   MultiEdit      BELONGS HERE, and is missing because no rule names it yet.
#                  It can edit arbitrary text files where it exists, and the
#                  phase lock is no fallback: paths.conf classifies
#                  `.claude/state/**` as `harness` (first matching rule,
#                  `.claude/**`) and phases.conf lets every phase write
#                  `harness`, so settings.json is the ONLY protection these two
#                  files have. It could not be probed on this build - MultiEdit
#                  does not exist here - but settings.json's own PreToolUse
#                  matcher lists it, so the harness already expects builds that
#                  have it. Once the four rules exist, add MultiEdit to this
#                  string and the suite starts enforcing them.
#   NotebookEdit   deliberately absent. It refuses anything that is not a
#                  `.ipynb` before any permission check runs (probed), and
#                  nothing under .claude/state/ is a notebook - phase.sh,
#                  gates.sh, mutate.sh and the guard all write plain text. A rule
#                  for it would be dead weight, and a rule nobody can justify is
#                  one somebody widens back to a glob.
TOOLS="Write Edit"

# rows <readme>   "<path><TAB><yes|no>" per table row.
rows() {
  awk -F'|' '
    /^[[:space:]]*\|/ {
      p = $2; e = $(NF - 1)
      gsub(/^[ \t`]+|[ \t`]+$/, "", p)
      gsub(/^[ \t]+|[ \t]+$/, "", e)
      if (p == "" || p ~ /^-+$/ || tolower(p) == "file") next
      print p "\t" tolower(e)
    }' "$1"
}

# problems <settings> <readme>   One line per disagreement; silence means they
# agree. Every check in this suite is this function on some pair.
problems() {
  local settings="$1" readme="$2" r path editable tool rule has d row denied
  r="$(rows "$readme")"
  [ -n "$r" ] || { printf 'no parseable table in %s\n' "$readme"; return 0; }

  # 1. Every row answers the question. A blank cell is a state file added
  #    without anybody deciding whether hand edits to it are a problem.
  while IFS="$TAB" read -r path editable; do
    [ -n "$path" ] || continue
    case "$editable" in
      yes|no) ;;
      *) printf "%s: hand-editable says '%s'; it must say yes or no\n" "$path" "$editable" ;;
    esac
  done <<< "$r"

  # 2. Forwards: a `no` row is denied for every tool in $TOOLS, a `yes` row for
  #    none of them.
  while IFS="$TAB" read -r path editable; do
    [ -n "$path" ] || continue
    for tool in $TOOLS; do
      rule="\"$tool(./.claude/state/$path)\""
      if grep -qF -- "$rule" "$settings"; then has=1; else has=0; fi
      if [ "$editable" = "no" ] && [ "$has" = 0 ]; then
        printf '%s: not hand-editable, but settings.json has no %s\n' "$path" "$rule"
      elif [ "$editable" = "yes" ] && [ "$has" = 1 ]; then
        printf '%s: hand-editable, but settings.json denies it with %s\n' "$path" "$rule"
      fi
    done
  done <<< "$r"

  # 3. Backwards, and this is the one that catches a re-widened glob: a rule
  #    naming `**`, or a path the README never mentions, is a rule whose reason
  #    has been lost. That is how the directory came to be denied wholesale.
  # The tool alternation is built from $TOOLS rather than written out, so that
  # adding a tool to that list also makes this direction see its rules. Written
  # out, a `MultiEdit(...)` rule for an undocumented path would slip past here
  # while the forwards check was busy demanding it.
  local alt
  alt="$(printf '%s' "$TOOLS" | tr ' ' '|')"
  denied="$(grep -oE "\"($alt)\\(\\./\\.claude/state/[^)]*\\)\"" "$settings" \
    | sed -E 's/^"[A-Za-z]+\(\.\/\.claude\/state\///; s/\)"$//' | sort -u)"
  [ -n "$denied" ] || printf 'settings.json denies nothing under .claude/state/\n'
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    row="$(printf '%s\n' "$r" | awk -F'\t' -v p="$d" '$1 == p { print $2; exit }')"
    case "$row" in
      no) ;;
      yes) printf "denied path '%s' is listed as hand-editable\n" "$d" ;;
      *)   printf "denied path '%s' is not in the README table\n" "$d" ;;
    esac
  done <<< "$denied"
  return 0
}

SETTINGS="$REPO_ROOT/.claude/settings.json"
README="$REPO_ROOT/.claude/state/README.md"

# ---------------------------------------------------------------------------
describe "the shipped pair agrees with itself"

assert_eq "no disagreements" "" "$(problems "$SETTINGS" "$README")"

# ---------------------------------------------------------------------------
describe "the two files that carry evidence stay denied"

# Stated independently of the README, so that widening the column and the rules
# together still fails. current-story.env is written by phase.sh alongside the
# story frontmatter, and the guarantee that those cannot drift holds only while
# nothing else writes it. last-gate-run is what the Stop hook reads to decide
# whether a phase's gate obligation was met, so hand-writing RESULT=pass into it
# forges exactly what law 3 exists to prevent.
for f in current-story.env last-gate-run; do
  for tool in $TOOLS; do
    if grep -qF -- "\"$tool(./.claude/state/$f)\"" "$SETTINGS"; then
      _ok "$tool(./.claude/state/$f) is denied"
    else
      _bad "$tool(./.claude/state/$f) is denied" "it is not in settings.json"
    fi
  done
done

# ---------------------------------------------------------------------------
describe "each way of getting it wrong produces its own complaint"

FIX="$(make_fixture)"
trap 'rm -rf "$FIX"' EXIT

# The baseline pair: small, correct, and the thing each case below breaks by one
# edit. Written out rather than copied from the repo so that a case says exactly
# what it is testing.
good_settings() {
  cat > "$FIX/settings.json" <<'EOF'
{ "permissions": { "deny": [
  "Write(./.claude/state/current-story.env)",
  "Edit(./.claude/state/current-story.env)",
  "Write(./.claude/state/last-gate-run)",
  "Edit(./.claude/state/last-gate-run)"
] } }
EOF
}
good_readme() {
  cat > "$FIX/README.md" <<'EOF'
| File | Written by | Read by | Hand-editable |
|---|---|---|---|
| `current-story.env` | `scripts/phase.sh` | the phase guard | no |
| `last-gate-run` | `scripts/gates.sh` | the stop hook | no |
| `gate-logs/*.log` | `scripts/gates.sh` | you, when a gate fails | yes |
EOF
}
p() { problems "$FIX/settings.json" "$FIX/README.md"; }

good_settings; good_readme
assert_eq "the baseline pair agrees" "" "$(p)"

# A state file added, with nobody deciding what it is.
good_settings; good_readme
printf -- '| `new-thing` | `scripts/x.sh` | somebody | |\n' >> "$FIX/README.md"
assert_contains "an unanswered column" "new-thing: hand-editable says ''" "$(p)"

# A file declared protected, with no rule behind the declaration. This is the
# drift the per-file rules invite, and the reason this suite exists.
good_settings; good_readme
printf -- '| `secrets.env` | `scripts/x.sh` | the hooks | no |\n' >> "$FIX/README.md"
assert_contains "a no row with no rule" "secrets.env: not hand-editable, but settings.json has no" "$(p)"

# A rule dropped from under a file that still says it is protected.
good_readme
good_settings
awk '!/last-gate-run/ || !/Write/' "$FIX/settings.json" > "$FIX/s.tmp" && mv "$FIX/s.tmp" "$FIX/settings.json"
assert_contains "a dropped rule" 'last-gate-run: not hand-editable, but settings.json has no "Write' "$(p)"

# A rule nobody can explain, on a file the README says is fine to touch.
good_settings; good_readme
printf 's|"Write(./.claude/state/last-gate-run)"|"Write(./.claude/state/gate-logs/*.log)"|' > /dev/null
cat > "$FIX/settings.json" <<'EOF'
{ "permissions": { "deny": [
  "Write(./.claude/state/current-story.env)",
  "Edit(./.claude/state/current-story.env)",
  "Write(./.claude/state/last-gate-run)",
  "Edit(./.claude/state/last-gate-run)",
  "Write(./.claude/state/gate-logs/*.log)"
] } }
EOF
assert_contains "a yes row that is denied anyway" \
  "gate-logs/*.log: hand-editable, but settings.json denies it" "$(p)"

# The glob, back. This is what the narrowing undid, and nothing else in the
# suite would notice it returning: `**` satisfies no row, so it is caught by the
# backwards check rather than the forwards one.
good_readme
cat > "$FIX/settings.json" <<'EOF'
{ "permissions": { "deny": [
  "Write(./.claude/state/current-story.env)",
  "Edit(./.claude/state/current-story.env)",
  "Write(./.claude/state/last-gate-run)",
  "Edit(./.claude/state/last-gate-run)",
  "Write(./.claude/state/**)",
  "Edit(./.claude/state/**)"
] } }
EOF
assert_contains "a re-widened glob" "denied path '**' is not in the README table" "$(p)"

# Nothing protected at all.
good_readme
printf '{ "permissions": { "deny": [ "Read(./.env)" ] } }\n' > "$FIX/settings.json"
out="$(p)"
assert_contains "no protection at all" "denies nothing under .claude/state/" "$out"
assert_contains "and it says which files wanted it" "current-story.env: not hand-editable" "$out"

# A table that is not a table.
good_settings
printf 'There used to be a table here.\n' > "$FIX/README.md"
assert_contains "an unparseable README" "no parseable table" "$(p)"

# $TOOLS is load-bearing, not decoration. This is the migration the header
# describes: the day MultiEdit rules are added, putting the tool in that list is
# what starts enforcing them - and until the rules exist, doing so fails loudly
# rather than quietly passing. Asserted here so the instruction is verified
# instead of aspirational.
good_settings; good_readme
out="$(TOOLS="Write Edit MultiEdit" p)"
assert_contains "adding a tool demands rules for it" \
  'current-story.env: not hand-editable, but settings.json has no "MultiEdit' "$out"
assert_contains "for every protected file" \
  'last-gate-run: not hand-editable, but settings.json has no "MultiEdit' "$out"
assert_eq "and the shipped list does not demand it yet" "" "$(p)"

# And the backwards direction sees the tools in that list too, which is why the
# alternation is built from it. Hardcoded, a rule for an undocumented path under
# a third tool would slip past here while the forwards check demanded it.
good_readme
cat > "$FIX/settings.json" <<'EOF'
{ "permissions": { "deny": [
  "Write(./.claude/state/current-story.env)",
  "Edit(./.claude/state/current-story.env)",
  "MultiEdit(./.claude/state/current-story.env)",
  "Write(./.claude/state/last-gate-run)",
  "Edit(./.claude/state/last-gate-run)",
  "MultiEdit(./.claude/state/last-gate-run)",
  "MultiEdit(./.claude/state/mystery)"
] } }
EOF
assert_contains "an undocumented path under a third tool" \
  "denied path 'mystery' is not in the README table" "$(TOOLS="Write Edit MultiEdit" p)"

summary "settings"
