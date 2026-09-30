#!/usr/bin/env bash
# Tests for scripts/plan.sh - which model each phase of a story runs on, and
# which command to drive it with.
#
# Both answers used to be asked of the human every time, which is the condition
# under which they stop being answers and become habits. The model question in
# particular: `rules.md` has said since WORLD-007 that a model choice with no
# recorded verdict is folklore, and the way a choice becomes folklore is that
# nobody writes down why - so the policy lives in a file with a reason per row,
# and the plan is written INTO the story before the phase it applies to.
#
# The policy is not taste. It is the one measurement this repository has:
#   * a partitioned RED brief on the weaker model produced sharper negative
#     controls than the stronger model without one, so RED runs on the weaker
#     model WHEN THE BRIEF EXISTS, and on the stronger one when it does not;
#   * the failure mode of a weaker model in GREEN or GATES is reaching green by
#     weakening a test, which is precisely what this harness exists to prevent,
#     so those never move.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

FIX="$(make_project_fixture)"
trap 'rm -rf "$FIX"' EXIT

plan() { ( cd "$FIX" && bash scripts/plan.sh "$@" 2>&1 ); }

# story_with <id> <type> <phase> <ac-count> ; section bodies on stdin as
# `SECTION:body` lines, so a case says only what it is about.
#
# `TOUCHES:` is the HARNESS-006 frontmatter declaration, and its three states
# are the ones the Contract distinguishes: no line means no `touches:` key at
# all; `TOUCHES:` with nothing after it writes `touches: []`, the line
# new-story.sh emits into every fresh story; `TOUCHES:a, b` writes
# `touches: [a, b]`. The middle one exists so a test can say "empty list" and
# "absent key" as two different fixtures, because PO decision 1 says they must
# be judged the same and only two fixtures can show that.
story_with() {
  local id="$1" type="$2" phase="$3" acs="$4" extra contract="" deferred="" deps="" touches="" has_touches=0
  extra="$(cat)"
  case "$extra" in *CONTRACT:*) contract="$(printf '%s\n' "$extra" | sed -n 's/^CONTRACT://p')" ;; esac
  case "$extra" in *DEFERRED:*) deferred="$(printf '%s\n' "$extra" | sed -n 's/^DEFERRED://p')" ;; esac
  case "$extra" in *DEPENDS:*)  deps="$(printf '%s\n' "$extra" | sed -n 's/^DEPENDS://p')" ;; esac
  case "$extra" in *TOUCHES:*)  has_touches=1; touches="$(printf '%s\n' "$extra" | sed -n 's/^TOUCHES://p')" ;; esac
  mkdir -p "$FIX/docs/backlog/stories"
  {
    printf -- '---\nid: %s\ntitle: Fixture story\nslug: fixture\ntype: %s\nstatus: todo\nphase: %s\nbranch: story/%s-fixture\n' \
      "$id" "$type" "$phase" "$id"
    [ -n "$deps" ] && printf -- 'depends_on: [%s]\n' "$deps"
    [ "$has_touches" = 1 ] && printf -- 'touches: [%s]\n' "$touches"
    printf -- '---\n\n## Acceptance criteria\n\n'
    local i=1
    while [ "$i" -le "$acs" ]; do printf -- '- **AC-%s** - it works.\n' "$i"; i=$((i+1)); done
    printf -- '\n## Contract\n\n'
    [ -n "$contract" ] && printf -- '%s\n' "$contract"
    printf -- '\n## Deferred verifications\n\n'
    [ -n "$deferred" ] && printf -- '%s\n' "$deferred"
    printf -- '\n## Model guidance\n\n## Gate results\n\n## Notes\n'
  } > "$FIX/docs/backlog/stories/$id.md"
}

# A story that is ordinary in every way the rules below care about: a real
# contract, few criteria, nothing deferred, no dependencies.
ordinary() { story_with "${1:-T-1}" "${2:-feature}" "${3:-PLANNED}" 2 <<'EOF'
CONTRACT:`src/core/world.ts` exports `buildWorld(seed: number): World`.
EOF
}

# ---------------------------------------------------------------------------
describe "which model each phase runs on"

ordinary T-1
out="$(plan models T-1)"

# RED is the whole point of the policy, and it is the only row that moves.
assert_contains "RED runs on the weaker model when a brief exists" \
  "RED	test-developer	fable" "$out"

# These two never move, and the reason is the one this harness was built for.
assert_contains "GREEN stays on the stronger model" \
  "GREEN	feature-developer	opus" "$out"
assert_contains "GATES stays on the stronger model" \
  "GATES	feature-developer	opus" "$out"
assert_contains "and the orchestrator does too" \
  "PLANNED	lead-po	opus" "$out"

# Both checks below are loops over the plan's rows, and a loop over nothing
# finds no fault: with no plan at all they reported green while every other
# assertion in this file was red. So the row count is asserted first, and they
# mean something only because it is.
assert_eq "the plan has a row for every dispatching phase" 6 \
  "$(printf '%s\n' "$out" | grep -c '	')"

# A row without a reason is the folklore rules.md warns about, so every row
# carries one and the test refuses a blank.
missing=""
while IFS= read -r line; do
  [ -n "$line" ] || continue
  why="$(printf '%s' "$line" | cut -f4-)"
  case "$why" in ''|' ') missing="$missing $(printf '%s' "$line" | cut -f1)" ;; esac
done <<< "$out"
assert_eq "every phase in the plan says why" "" "$missing"

# THE EXCEPTION, and the reason it exists. The measurement was a partitioned
# RED BRIEF against the stronger model without one - so with no contract to
# hand RED, the thing that was measured is not present and the weaker model is
# not what was tested.
story_with T-2 feature PLANNED 2 <<'EOF'
EOF
out="$(plan models T-2)"
assert_contains "with no contract, RED goes back to the stronger model" \
  "RED	test-developer	opus" "$out"
assert_contains "and says it is the brief that is missing" "contract" "$out"

# THE STORY THE LOCK DOES NOT COVER, reported from the field and confirmed
# here: `.claude/tests/*.test.sh`, `scripts/*` and `.claude/hooks/*` all
# classify as `harness`, and `harness` is writable in EVERY phase. So for a
# story that maintains the harness itself, RED may write the mechanism and
# GREEN may rewrite the frozen tests, and nothing complains - the consuming
# project measured `gates.sh --fast` at 13/13 with identical counts across a
# GREEN that added a script, a config file and 25 assertions.
#
# That changes what the RED row is resting on. Elsewhere the contract is an AID
# to the model and the lock is the enforcement; here the contract IS the
# enforcement, the only one there is. A weaker model is a different proposition
# against a safety net than against nothing, so RED stays on the stronger model
# when every path the contract names is one the lock will not freeze.
story_with T-4 feature PLANNED 2 <<'EOF'
CONTRACT:`scripts/plan.sh` gains a `write` subcommand; `.claude/tests/plan.test.sh` pins it.
EOF
out="$(plan models T-4)"
assert_contains "a story the lock cannot police keeps RED on the stronger model" \
  "RED	test-developer	opus" "$out"
assert_contains "and says the lock is what is missing" "lock" "$out"

# THE CONTROL, and the reason this is not just "mentions a script". One source
# path is enough for the lock to bite, and without this assertion the rule
# above would push every story that touches a helper onto the stronger model.
story_with T-5 feature PLANNED 2 <<'EOF'
CONTRACT:`src/core/world.ts` exports `buildWorld`; `scripts/task.sh` gains a `seed` target.
EOF
out="$(plan models T-5)"
assert_contains "but one source path is enough for the lock to bite" \
  "RED	test-developer	fable" "$out"

# A CONTRACT TOO BIG TO READ IS STILL A CONTRACT. `has_content` here was lifted
# from check-boundaries.sh when this script was written, and the defect came with
# it: `strip_comments | grep -q` has an awk that buffers to END feeding a grep
# that exits at the first match, so the writer dies of SIGPIPE and `pipefail`
# turns 141 into "no content". Measured: 50,000 bytes exit 0, 200,000 exit 141.
#
# The consequence here is quieter than a refused PR and worse for it. A thorough
# contract - the kind the RED row exists to reward - reads as ABSENT, the
# no-contract exception fires, and the plan silently moves RED to the stronger
# model. Nothing fails; the story just runs on a model nobody chose, for a reason
# nobody can see.
#
# The body is STREAMED into the file rather than held in a shell variable and
# passed through `awk -v`: a megabyte on a command line stalls indefinitely here,
# which is a fact about this fixture rather than about the defect.
{
  printf -- '---\nid: T-6\ntitle: Fixture story\nslug: fixture\ntype: feature\nstatus: todo\nphase: PLANNED\nbranch: story/T-6-fixture\n---\n\n'
  printf -- '## Acceptance criteria\n\n- **AC-1** - it works.\n\n## Contract\n\n'
  yes '`src/core/world.ts` exports buildWorld(seed: number): World.' | head -c 1572864
  printf -- '\n\n## Deferred verifications\n\n## Model guidance\n\n## Gate results\n\n## Notes\n'
} > "$FIX/docs/backlog/stories/T-6.md"
out="$(plan models T-6)"
assert_contains "a 1.5 MiB contract still counts as a contract" \
  "RED	test-developer	fable" "$out"

# Bootstrap writes source, tests and config in one indivisible derivation under
# SCAFFOLD, with no failing test to anchor it.
story_with T-3 bootstrap PLANNED 2 <<'EOF'
CONTRACT:the stack, the runner, and the scaffold.
EOF
out="$(plan models T-3)"
assert_contains "a bootstrap story keeps RED on the stronger model" \
  "RED	test-developer	opus" "$out"

# Derived, not listed: every phase that dispatches an agent has a row. A phase
# added to phases.conf with no model row is a phase whose model is decided by
# whatever the session happens to be set to, which is the state this replaces.
unplanned=""
for ph in $(awk -F'|' '!/^#|^[[:space:]]*$/ { gsub(/ /,"",$1); print $1 }' "$FIX/.claude/harness/phases.conf"); do
  case "$ph" in IDLE|DONE) continue ;; esac
  # awk over a here-string, not `printf | grep -q`. `grep -q` leaves at its
  # first match, the printf behind it dies of SIGPIPE, and pipefail promotes 141
  # to the status this `||` reads - so a phase that HAS a row is recorded as
  # unplanned. -F'\t' with NF > 1 is exactly the old `^PHASE<tab>` anchor: $1 is
  # everything before the first tab, and NF > 1 is what says a tab was there.
  # WORLD-086 R-1.
  awk -F'\t' 'BEGIN { n = ARGV[1]; ARGV[1] = "" } $1 == n && NF > 1 { h = 1 } END { exit !h }' \
    "$ph" <<<"$out" || unplanned="$unplanned $ph"
done
assert_eq "every dispatching phase has a model" "" "$unplanned"

# A model nobody can dispatch is a typo that surfaces as a silent fallback.
bad=""
while IFS= read -r line; do
  [ -n "$line" ] || continue
  m="$(printf '%s' "$line" | cut -f3)"
  case "$m" in opus|fable|sonnet|haiku) ;; *) bad="$bad $m" ;; esac
done <<< "$out"
assert_eq "and names a model that can actually be dispatched" "" "$bad"

# ---------------------------------------------------------------------------
describe "which command to drive the story with"

# The ordinary case, and the one the request is about: nothing here needs a
# human between phases.
ordinary T-10
out="$(plan next T-10)"
assert_contains "an ordinary story runs end to end" "complete-story" "$out"
assert_contains "and says why" "T-10" "$out"

# Mid-flight is not a recommendation about the whole cycle; it is the next
# phase, and the answer is never complete-story.
ordinary T-11 feature GREEN
out="$(plan next T-11)"
assert_contains "a story already in flight advances one phase" "advance-story" "$out"
assert_contains "and names the phase it would move to" "GATES" "$out"

# Bootstrap is the one type that writes production code with no failing test
# in front of it. Look between the phases.
story_with T-12 bootstrap PLANNED 2 <<'EOF'
CONTRACT:the stack and the runner.
EOF
out="$(plan next T-12)"
assert_contains "a bootstrap story is driven one phase at a time" "advance-story" "$out"

# A deferred verification names a control and the phase that must run it, so
# something has to stop in that phase and look.
story_with T-13 feature PLANNED 2 <<'EOF'
CONTRACT:`src/core/world.ts` exports `buildWorld`.
DEFERRED:- AC-2's negative control cannot run until the renderer exists. Owner: GREEN
EOF
out="$(plan next T-13)"
assert_contains "so is one carrying a deferred verification" "advance-story" "$out"
assert_contains "and the reason names it" "Deferred" "$out"

# Size is the crudest signal and the last one consulted, which is why it is a
# threshold rather than a judgement.
story_with T-14 feature PLANNED 9 <<'EOF'
CONTRACT:`src/core/world.ts` exports `buildWorld`.
EOF
out="$(plan next T-14)"
assert_contains "and one with many criteria" "advance-story" "$out"

# A story whose dependency is not DONE cannot be driven by either command, and
# saying `complete-story` here sends somebody into a refusal from phase.sh.
ordinary T-20 feature DONE
story_with T-21 feature PLANNED 2 <<'EOF'
CONTRACT:`src/core/world.ts` exports `buildWorld`.
DEPENDS:T-22
EOF
story_with T-22 feature GREEN 2 <<'EOF'
CONTRACT:something else.
EOF
out="$(plan next T-21)"
assert_contains "a blocked story recommends neither" "blocked" "$out"
assert_contains "and names the dependency that blocks it" "T-22" "$out"

# The same story once its dependency lands.
story_with T-22 feature DONE 2 <<'EOF'
CONTRACT:something else.
EOF
out="$(plan next T-21)"
assert_contains "and stops being blocked when the dependency is DONE" "complete-story" "$out"

# DONE is not a recommendation to do anything.
ordinary T-30 feature DONE
out="$(plan next T-30)"
case "$out" in
  *advance-story*|*complete-story*) _bad "a DONE story recommends no command" "it recommended one: $out" ;;
  *) _ok "a DONE story recommends no command" ;;
esac

# ---------------------------------------------------------------------------
describe "the plan is written into the story, not left to be looked up"

# `## Gate results` is written by gates.sh and never by hand, for a reason that
# applies here too: a section a person retypes is a section that drifts from
# what the tool would say. The plan goes in at the END of PLANNED, because it
# depends on the contract - writing it at creation time would bake in the
# no-contract exception before anybody had a chance to write one.
ordinary T-40
plan write T-40 >/dev/null
body="$(awk '/^## Model guidance/{on=1;next} on&&/^## /{exit} on{print}' "$FIX/docs/backlog/stories/T-40.md")"
assert_contains "the section carries the plan" "RED" "$body"
assert_contains "with the model for each phase" "fable" "$body"
assert_contains "and the reason, not just the name" "negative controls" "$body"
# It is a PLAN. rules.md wants the resolved model recorded, and a section that
# looked like a record would quietly satisfy a rule it does not satisfy.
assert_contains "and says it is a plan, not a record" "resolved" "$body"

# Nothing else in the story moves.
assert_contains "the criteria are untouched" "**AC-1**" "$(cat "$FIX/docs/backlog/stories/T-40.md")"
assert_contains "and so is the contract" "buildWorld" "$(cat "$FIX/docs/backlog/stories/T-40.md")"

# Writing twice is writing once: the orchestrator re-runs this after amending
# the contract, and a section that grew a second copy each time would be worse
# than no section.
plan write T-40 >/dev/null
assert_eq "writing it again replaces rather than appends" 1 \
  "$(grep -c '^| RED ' "$FIX/docs/backlog/stories/T-40.md")"


# ---------------------------------------------------------------------------
describe "conflicts: which startable stories would fight over the same file"

# WHAT THIS IS FOR. Running two stories at once needs two things to be true:
# neither is blocked, and they do not write the same files. `depends_on` already
# answers the first - `plan.sh next` returns `blocked` and the board shows it.
# Nothing answered the second, so two ready stories could both be started and
# the collision found at merge.
#
# The declared paths already exist: `## Contract` names the modules a story
# touches, and contract_unenforced has been reading them since release 23 to
# decide the RED model. This intersects them instead of re-deriving them.

rm -rf "$FIX/docs/backlog/stories"; mkdir -p "$FIX/docs/backlog/stories"
story_with A feature PLANNED 1 <<'EOF'
CONTRACT:`src/core/world.ts` exports buildWorld(seed: number): World.
EOF
story_with B feature PLANNED 1 <<'EOF'
CONTRACT:`src/ui/panel.tsx` exports Panel().
EOF
out="$(plan conflicts)"
assert_contains "two stories touching different files are reported clear" \
  "A + B" "$out"
case "$out" in
  *CONFLICT*) _bad "and not as a conflict" "reported a conflict: $out" ;;
  *) _ok "and not as a conflict" ;;
esac

# The case it exists for.
rm -rf "$FIX/docs/backlog/stories"; mkdir -p "$FIX/docs/backlog/stories"
story_with A feature PLANNED 1 <<'EOF'
CONTRACT:`src/core/world.ts` exports buildWorld(seed: number): World.
EOF
story_with B feature RED 1 <<'EOF'
CONTRACT:`src/core/world.ts` gains clampLatitude(deg: number): number.
EOF
out="$(plan conflicts)"
assert_contains "two stories declaring the same path are named as a conflict" \
  "CONFLICT" "$out"
assert_contains "and the shared path is named, so it can be checked" \
  "src/core/world.ts" "$out"
assert_eq "and it exits non-zero when there is one" "1" "$( ( cd "$FIX" && bash scripts/plan.sh conflicts >/dev/null 2>&1 ); printf '%s' "$?" )"

# A STORY THAT DECLARES NOTHING CANNOT BE JUDGED, and must not read as clear.
# This is the real-tree case: all five stories in this repository's own backlog
# are PLANNED with an empty Contract, because the contract is written before
# RED. A guard that called that "no conflicts" would be answering a question it
# had no information about - the same failure as refresh-harness.sh reporting
# LOCAL from a source with no history.
rm -rf "$FIX/docs/backlog/stories"; mkdir -p "$FIX/docs/backlog/stories"
story_with A feature PLANNED 1 <<'EOF'
CONTRACT:`src/core/world.ts` exports buildWorld(seed: number): World.
EOF
story_with B feature PLANNED 1 </dev/null
out="$(plan conflicts)"
assert_contains "a story declaring no paths is reported as unjudgeable" \
  "UNKNOWN" "$out"
# ANCHORED ON THE ROW'S STATUS COLUMN, not on the absence of the word "clear"
# anywhere in the output. Written the floating way first, it matched the footer
# sentence "UNKNOWN is not clear:" - the line that exists to say the opposite -
# and reported the code broken. rules.md: prefer a needle whose negation is not
# also a match.
assert_eq "and never as clear" "UNKNOWN" \
  "$(awk '$2 == "A" && $3 == "+" && $4 == "B" { print $1; exit }' <<<"$out")"

# Blocked and DONE stories are not candidates: one cannot start, the other is
# finished. Without this the report is noise proportional to backlog size.
rm -rf "$FIX/docs/backlog/stories"; mkdir -p "$FIX/docs/backlog/stories"
story_with A feature PLANNED 1 <<'EOF'
CONTRACT:`src/core/world.ts` exports buildWorld(seed: number): World.
EOF
story_with B feature PLANNED 1 <<'EOF'
DEPENDS:A
CONTRACT:`src/core/world.ts` also changes buildWorld.
EOF
out="$(plan conflicts)"
case "$out" in
  *CONFLICT*) _bad "a blocked story is not a conflict candidate" "reported anyway: $out" ;;
  *) _ok "a blocked story is not a conflict candidate" ;;
esac

# ---------------------------------------------------------------------------
describe "conflicts: a story declares the files it touches in frontmatter (HARNESS-006)"

# WHY THE DECLARATION MOVES. The block above reads `## Contract`, and a Contract
# is written at the end of PLANNED - after the backlog has been cut. So at the
# moment the planner decides which stories can run together, every pair is
# UNKNOWN: ten of ten on this repository's own backlog at release 45. The check
# was honest and useless. `touches:` is the same fact stated when the story is
# AUTHORED, read by frontmatter_list - the reader depends_on already uses - and
# cmd_conflicts takes a story's paths from it first, falling back to the
# Contract only when it is absent or empty.
#
# EVERY ROW ASSERTION BELOW READS THE STATUS COLUMN of the named pair, never a
# floating substring: `clear` also appears in the footer sentence that exists
# to say UNKNOWN is NOT clear, and `DRIFT` could one day appear in prose.

# row_status <a> <b>   The first column of the pair's row, or nothing.
row_status() { awk -v a="$1" -v b="$2" '$2 == a && $3 == "+" && $4 == b { print $1; exit }' <<<"$out"; }
# drift_for <id>   Every DRIFT line for the story - first column exactly DRIFT,
# second the id - so a test can say "names this path" and "names no other".
drift_for()  { awk -v id="$1" '$1 == "DRIFT" && $2 == id { print }' <<<"$out"; }
# conflicts_rc   The exit status of the command, which is a claim of its own.
conflicts_rc() { ( cd "$FIX" && bash scripts/plan.sh conflicts >/dev/null 2>&1 ); printf '%s' "$?"; }
fresh() { rm -rf "$FIX/docs/backlog/stories"; mkdir -p "$FIX/docs/backlog/stories"; }

# --- AC-1: touches: is what the story is judged on --------------------------
#
# A's Contract names the very file B touches; A's `touches:` does not. Judged
# on `touches:`, the pair is clear. Judged on the Contract - today's code - or
# on the UNION of the two, it is a CONFLICT on src/ui/panel.tsx. The row can
# only read `clear` if the frontmatter took precedence.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts
CONTRACT:`src/ui/panel.tsx` gains a slot.
EOF
story_with B feature PLANNED 1 <<'EOF'
TOUCHES:src/ui/panel.tsx
EOF
out="$(plan conflicts)"
assert_eq "a story with touches: is judged on those paths, not on its Contract" \
  "clear" "$(row_status A B)"

# The reverse: the same two stories with the Contract left alone and A's
# `touches:` moved onto B's file. Only the frontmatter changed, and the verdict
# flips. Without this the assertion above is also satisfied by "ignore both".
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:src/ui/panel.tsx
CONTRACT:`src/core/world.ts` gains a slot.
EOF
story_with B feature PLANNED 1 <<'EOF'
TOUCHES:src/ui/panel.tsx
EOF
out="$(plan conflicts)"
assert_eq "and changing only touches: changes the verdict" \
  "CONFLICT" "$(row_status A B)"

# THE CONTROL, PO decision 1. `touches: []` is what new-story.sh writes into
# every fresh story, so its meaning decides what a whole new backlog reports.
# It declares NOTHING: the story falls through to its Contract exactly as if
# the key were absent. Two fixtures, because two wrong readings exist and each
# passes one of them:
#   * "empty means touches no file" -> clear against everything. Refused by the
#     first case, where A's Contract collides with B and the row must say so.
#   * "empty means stop, declare nothing, do not consult the Contract" ->
#     UNKNOWN in the first case. Also refused by it.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:
CONTRACT:`src/core/world.ts` gains a slot.
EOF
story_with B feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts
EOF
out="$(plan conflicts)"
assert_eq "touches: [] falls through to the Contract, like an absent key" \
  "CONFLICT" "$(row_status A B)"

# And with no Contract to fall through to, it is UNKNOWN - never clear. This
# is the second reading's other half: `[]` as "touches no file" would make
# every story new-story.sh creates read clear against everything.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:
EOF
story_with B feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts
EOF
out="$(plan conflicts)"
assert_eq "touches: [] with no Contract is UNKNOWN, not clear" \
  "UNKNOWN" "$(row_status A B)"

# --- AC-2: intersecting sets are CONFLICT, disjoint sets are clear -----------
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts, src/ui/panel.tsx
EOF
story_with B feature RED 1 <<'EOF'
TOUCHES:docs/wiki/design.md, src/ui/panel.tsx
EOF
out="$(plan conflicts)"
assert_eq "two stories whose touches: intersect are a CONFLICT" \
  "CONFLICT" "$(row_status A B)"
assert_contains "and the shared path is named on the row" "src/ui/panel.tsx" \
  "$(awk '$2 == "A" && $3 == "+" && $4 == "B" { print; exit }' <<<"$out")"
# Not the unshared ones: a row naming every path either side declares would
# also contain the needle above, and would send the reader to the wrong file.
assert_not_contains "and only the shared path" "src/core/world.ts" \
  "$(awk '$2 == "A" && $3 == "+" && $4 == "B" { print; exit }' <<<"$out")"
assert_eq "and the command exits non-zero" "1" "$(conflicts_rc)"

# The control: same shape, no overlap.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts, src/core/climate.ts
EOF
story_with B feature RED 1 <<'EOF'
TOUCHES:src/ui/panel.tsx, docs/wiki/design.md
EOF
out="$(plan conflicts)"
assert_eq "two stories whose touches: are disjoint are clear" \
  "clear" "$(row_status A B)"
assert_eq "and the command exits 0" "0" "$(conflicts_rc)"

# --- AC-3: touches: plus an EMPTY Contract is judged, not UNKNOWN ------------
#
# The whole point. Both stories here are what a freshly planned backlog looks
# like - a filled `touches:`, a Contract nobody has written - and the pair is
# judged. Today's code reports UNKNOWN for it.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:scripts/plan.sh
EOF
story_with B feature PLANNED 1 <<'EOF'
TOUCHES:scripts/new-story.sh
EOF
out="$(plan conflicts)"
assert_eq "touches: with an empty Contract is judged, not UNKNOWN" \
  "clear" "$(row_status A B)"
assert_contains "and the summary counts no unjudged pair" \
  "0 pair(s) that could not be judged" "$out"
# No Contract means nothing to drift from: drift is judged only when BOTH
# sources are present.
assert_eq "and an empty Contract raises no drift warning" "" "$(drift_for A)$(drift_for B)"

# THE CONTROL. A story with neither `touches:` nor Contract paths still cannot
# be judged, and UNKNOWN is still never spelled `clear`. Absent key, not `[]`:
# the `[]` twin of this case is under AC-1.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts
EOF
story_with B feature PLANNED 1 </dev/null
out="$(plan conflicts)"
assert_eq "a story with neither touches: nor Contract paths is still UNKNOWN" \
  "UNKNOWN" "$(row_status A B)"
# The row's detail used to say "no Contract paths declared yet", which after
# this story is only half the diagnosis and would send a planner to write a
# Contract when one line of frontmatter is the cheaper fix.
assert_contains "and the row says which declaration is missing" "touches" \
  "$(awk '$2 == "A" && $3 == "+" && $4 == "B" { print; exit }' <<<"$out")"
assert_eq "and a Contract-less story with touches: on the other side raises no drift" \
  "" "$(drift_for A)$(drift_for B)"

# --- AC-4: a Contract path absent from touches: is a drift warning -----------
#
# The Contract is the sharper document, written later by someone who has read
# the code. When it names a file the declaration did not, one of the two is
# wrong, and neither should silently overrule the other: the pair is still
# judged on `touches:` (AC-1), and the disagreement is printed.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:scripts/plan.sh
CONTRACT:**Writes:** `scripts/plan.sh`, `scripts/new-story.sh`
CONTRACT:`scripts/plan.sh` gains story_touches; `scripts/new-story.sh` emits the key.
EOF
story_with B feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts
EOF
out="$(plan conflicts)"
assert_eq "a Contract path absent from touches: is one DRIFT line for that story" \
  "1" "$(drift_for A | grep -c .)"
assert_contains "naming the path" "scripts/new-story.sh" "$(drift_for A)"
assert_not_contains "and not the path both documents agree on" "scripts/plan.sh" "$(drift_for A)"
assert_eq "a story whose Contract is empty has nothing to drift from" "" "$(drift_for B)"
# The exact line the Contract specifies, anchored: first column DRIFT, second
# the id, then the path in the wording the reader will grep for.
assert_eq "in the documented wording" "1" \
  "$(grep -c '^DRIFT[[:space:]]\{1,\}A[[:space:]]\{1,\}contract names scripts/new-story.sh, touches: does not$' <<<"$out")"
# It is a WARNING. The exit status is about conflicts, and there is none here.
assert_eq "and drift alone does not change the exit status" "0" "$(conflicts_rc)"
assert_eq "and the pair is still judged on touches:" "clear" "$(row_status A B)"
assert_eq "and the summary line counts it" "1" \
  "$(grep -cx '0 conflict(s), 0 pair(s) that could not be judged, 1 drift warning(s).' <<<"$out")"

# A GLOB IN touches: COVERS THE FILES IT MATCHES. A story declaring a directory
# glob and a Contract naming one file under it has not drifted; the two
# documents agree at different granularities.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:src/ui/*.tsx
CONTRACT:**Writes:** `src/ui/panel.tsx`
CONTRACT:`src/ui/panel.tsx` exports Panel().
EOF
story_with B feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts
EOF
out="$(plan conflicts)"
assert_eq "a Contract path matched by a touches: glob is not drift" "" "$(drift_for A)"

# The control for the glob rule: a glob that does NOT match the Contract's path
# still drifts. Without this, "globs never drift" satisfies the case above.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:src/core/*.ts
CONTRACT:**Writes:** `src/ui/panel.tsx`
CONTRACT:`src/ui/panel.tsx` exports Panel().
EOF
story_with B feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts
EOF
out="$(plan conflicts)"
assert_contains "but a glob that does not match the path is drift" \
  "src/ui/panel.tsx" "$(drift_for A)"

# DRIFT IS PER STORY, NOT PER PAIR. A backlog with one startable story has no
# pair to judge and still has a declaration that can disagree with its
# Contract - this story's own situation at PLANNED, where it was the only
# startable story in its backlog.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:scripts/plan.sh
CONTRACT:**Writes:** `scripts/plan.sh`, `scripts/new-story.sh`
CONTRACT:`scripts/plan.sh` gains story_touches; `scripts/new-story.sh` emits the key.
EOF
out="$(plan conflicts)"
assert_contains "drift is reported even with fewer than two startable stories" \
  "scripts/new-story.sh" "$(drift_for A)"
assert_eq "and still exits 0" "0" "$(conflicts_rc)"

# Drift beside a real conflict: the warning is counted and the conflict still
# decides the exit status. Both numbers on one summary line, so a count that
# overwrote the other would show.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:scripts/plan.sh
CONTRACT:**Writes:** `scripts/plan.sh`, `scripts/new-story.sh`
CONTRACT:`scripts/plan.sh` gains story_touches; `scripts/new-story.sh` emits the key.
EOF
story_with B feature PLANNED 1 <<'EOF'
TOUCHES:scripts/plan.sh
EOF
out="$(plan conflicts)"
assert_eq "drift and a conflict are counted separately" "1" \
  "$(grep -cx '1 conflict(s), 0 pair(s) that could not be judged, 1 drift warning(s).' <<<"$out")"
assert_eq "and the conflict still decides the exit status" "1" "$(conflicts_rc)"

# DRIFT NEEDS BOTH DOCUMENTS. A story with a Contract and no `touches:` has
# nothing for the Contract to drift FROM; printing its whole path list as
# drift would be noise on every story that predates the field. The other
# conjunct - a Contract-less story does not drift - is pinned under AC-3.
fresh
story_with A feature PLANNED 1 <<'EOF'
CONTRACT:**Writes:** `scripts/plan.sh`, `scripts/new-story.sh`
CONTRACT:`scripts/plan.sh` gains story_touches; `scripts/new-story.sh` emits the key.
EOF
story_with B feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts
EOF
out="$(plan conflicts)"
assert_eq "a story with a Contract and no touches: key is not drift" "" "$(drift_for A)"

# A blocked story is not startable, so it is not drift-checked either: the
# report is about what could run now. Same rule the pair table applies.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts
EOF
story_with B feature PLANNED 1 <<'EOF'
DEPENDS:A
TOUCHES:src/ui/panel.tsx
CONTRACT:**Writes:** `src/ui/other.tsx`
CONTRACT:`src/ui/other.tsx` also changes.
EOF
out="$(plan conflicts)"
assert_eq "a blocked story is not drift-checked" "" "$(drift_for B)"

# THE MODEL POLICY DOES NOT MOVE. cmd_models reads the Contract alone to decide
# the RED row - a story with a lock-policed `touches:` and an empty Contract is
# still a story with no brief, and RED stays on the stronger model.
fresh
story_with A feature PLANNED 2 <<'EOF'
TOUCHES:src/core/world.ts
EOF
out="$(plan models A)"
assert_contains "touches: does not stand in for the Contract in the model plan" \
  "RED	test-developer	opus" "$out"

# ---------------------------------------------------------------------------
describe "drift reads what a Contract writes (HARNESS-016)"

# WHY. HARNESS-006's DRIFT line compared `touches:` with every path-shaped token
# in the Contract's prose, and on this repository's own backlog it fired 15
# times and was wrong 15 times: files a story only READS (a helper it calls, a
# script it cites), bare basenames of files `touches:` lists in full, directory
# prefixes, and tokens that are not paths at all (`AC-1..AC`). A warning that is
# always false teaches its reader to skip it.
#
# PO decision 1: the Contract says what it writes on a column-0 `**Writes:**`
# line, the backticked tokens on it, unioned across lines. DRIFT compares THAT
# with `touches:` and is silent when there is no such line. The prose extractor
# survives only as the fallback for `conflicts` and the model plan, minus four
# drop rules for tokens that are not paths.
#
# NEEDLES. Every DRIFT assertion here is a whole-line compare against the exact
# text cmd_conflicts prints (`printf '%-9s %-13s %s'`), or an exact count of
# such lines - never a floating `DRIFT`, which the summary's `drift warning(s)`
# also satisfies.

# drift_line <id> <path>   The one DRIFT line the Contract specifies, exactly.
drift_line() { printf '%-9s %-13s %s' DRIFT "$1" "contract names $2, touches: does not"; }
# red_model <id>   The model column of the RED row of `plan.sh models`, and
# nothing else: `fable` and `opus` are compared whole, not found in a line.
# No `exit` in the awk: it reads to the end, so the writer never meets a closed
# pipe (WORLD-086's house rule).
red_model() { plan models "$1" | awk -F'\t' '$1 == "RED" { print $3 }'; }
# pair_row <a> <b>   The pair's whole row, for field-level checks of the detail.
pair_row() { awk -v a="$1" -v b="$2" '$2 == a && $3 == "+" && $4 == b { print; exit }' <<<"$out"; }

# --- AC-1: read-only mentions are not drift ----------------------------------
#
# A writes two files and `touches:` lists both. Its prose also names a helper it
# calls, a script it cites, a rule it follows, and the bare basename of a file
# `touches:` lists in full. Today every one of those is a DRIFT line.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:scripts/plan.sh, .claude/tests/plan.test.sh
CONTRACT:**Writes:** `scripts/plan.sh`, `.claude/tests/plan.test.sh`
CONTRACT:`plan.sh` calls `frontmatter_list` the way `scripts/phase.sh` does;
CONTRACT:no change to `scripts/check-boundaries.sh`. See `.claude/harness/rules.md`.
EOF
story_with B feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts
EOF
out="$(plan conflicts)"
assert_eq "files a Contract only reads or cites are not drift when touches: covers every file it writes" \
  "" "$(drift_for A)"
assert_eq "and the summary counts no drift warning" "1" \
  "$(grep -cx '0 conflict(s), 0 pair(s) that could not be judged, 0 drift warning(s).' <<<"$out")"

# THE CONTROL. The same story with one written file dropped from `touches:`:
# exactly one DRIFT line, and it is that file - not the read-only mentions,
# which would make the count larger, and not the file both documents agree on.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:scripts/plan.sh
CONTRACT:**Writes:** `scripts/plan.sh`, `.claude/tests/plan.test.sh`
CONTRACT:`plan.sh` calls `frontmatter_list` the way `scripts/phase.sh` does;
CONTRACT:no change to `scripts/check-boundaries.sh`. See `.claude/harness/rules.md`.
EOF
story_with B feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts
EOF
out="$(plan conflicts)"
assert_eq "a written file missing from touches: is exactly one DRIFT line, naming that file" \
  "$(drift_line A .claude/tests/plan.test.sh)" "$(drift_for A)"
assert_eq "and the summary counts exactly one" "1" \
  "$(grep -cx '0 conflict(s), 0 pair(s) that could not be judged, 1 drift warning(s).' <<<"$out")"

# NO **Writes:** LINE, NO DRIFT. A story that has not said what it writes has
# nothing for `touches:` to disagree with - its prose is not read for drift at
# all, however path-like. This is the rule that silences the real backlog.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:scripts/plan.sh
CONTRACT:`scripts/plan.sh` gains story_touches; `scripts/new-story.sh` emits the key.
EOF
out="$(plan conflicts)"
assert_eq "a Contract with no **Writes:** line produces no DRIFT line, whatever its prose names" \
  "" "$(drift_for A)"

# MORE THAN ONE **Writes:** LINE, AND THEY UNION. Two lines, `touches:` covers
# only the first: the second line's path is the one drift.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:scripts/plan.sh
CONTRACT:**Writes:** `scripts/plan.sh`
CONTRACT:Then the template.
CONTRACT:**Writes:** `scripts/new-story.sh`
EOF
out="$(plan conflicts)"
assert_eq "every **Writes:** line is read, and they union" \
  "$(drift_line A scripts/new-story.sh)" "$(drift_for A)"

# A **Writes:** INSIDE AN HTML COMMENT IS NOT READ. The template's own example
# lives in one; read without strip_comments, every fresh story would declare it.
# Column 0 on purpose: a reader that grepped lines without stripping comments
# first would see this one.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:scripts/plan.sh
CONTRACT:**Writes:** `scripts/plan.sh`
CONTRACT:<!-- for example:
CONTRACT:**Writes:** `scripts/ghost.sh`
CONTRACT:-->
EOF
out="$(plan conflicts)"
assert_eq "a **Writes:** line inside an HTML comment declares nothing" "" "$(drift_for A)"

# NO BASENAME MATCHING. A **Writes:** entry is a repository-relative path, so a
# bare basename there is itself the disagreement, even when `touches:` lists a
# path ending in it.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:scripts/plan.sh
CONTRACT:**Writes:** `plan.sh`
EOF
out="$(plan conflicts)"
assert_eq "a bare basename on a **Writes:** line is drift, not covered by the full path" \
  "$(drift_line A plan.sh)" "$(drift_for A)"

# --- AC-2: tokens that are not paths -----------------------------------------
#
# Each of the Contract's four drop rules has a token here: `..` (rule 1), a
# trailing `/` (rule 2), a trailing dot-and-digits version (rule 3), and a
# one-character stem with no `/` (rule 4: `e.g`, `i.bak`, `0.139s`).
#
# Drift side: the junk sits in prose beside a **Writes:** line whose second
# path `touches:` omits. The whole DRIFT output must be that one line.
fresh
story_with A feature PLANNED 1 <<'EOF'
TOUCHES:scripts/plan.sh
CONTRACT:**Writes:** `scripts/plan.sh`, `scripts/new-story.sh`
CONTRACT:Covers AC-1..AC-4, e.g. the 1.2 and 4.9 readers under `.claude/skills/stack-profiles/reference/`;
CONTRACT:keeps i.bak and measured 0.139s.
EOF
story_with B feature PLANNED 1 <<'EOF'
TOUCHES:src/core/world.ts
EOF
out="$(plan conflicts)"
assert_eq "non-path tokens and directory prefixes never reach a DRIFT line; the omitted written path does" \
  "$(drift_line A scripts/new-story.sh)" "$(drift_for A)"

# CONFLICT side, on the prose fallback: two stories with no `touches:` and no
# **Writes:** line, whose Contracts share ONLY junk. Today every shared junk
# token is a "shared path" and the pair is a CONFLICT.
fresh
story_with A feature PLANNED 1 <<'EOF'
CONTRACT:`src/core/world.ts` covers AC-1..AC, e.g. the 1.2 reader under `.claude/skills/stack-profiles/reference/`.
CONTRACT:Keeps i.bak; measured 0.139s.
EOF
story_with B feature PLANNED 1 <<'EOF'
CONTRACT:`src/ui/panel.tsx` covers AC-1..AC, e.g. the 1.2 reader under `.claude/skills/stack-profiles/reference/`.
CONTRACT:Keeps i.bak; measured 0.139s.
EOF
out="$(plan conflicts)"
assert_eq "two Contracts sharing only non-path tokens are clear, not a CONFLICT" \
  "clear" "$(row_status A B)"
assert_eq "and the command exits 0" "0" "$(conflicts_rc)"

# THE CONTROL: the same two Contracts sharing one real path as well. CONFLICT,
# and the detail is that path ALONE - five fields, the fifth the path - so no
# junk token rode along as a second "shared path".
fresh
story_with A feature PLANNED 1 <<'EOF'
CONTRACT:`src/core/world.ts` covers AC-1..AC, e.g. the 1.2 reader under `.claude/skills/stack-profiles/reference/`.
CONTRACT:Keeps i.bak; measured 0.139s.
EOF
story_with B feature PLANNED 1 <<'EOF'
CONTRACT:`src/ui/panel.tsx` and `src/core/world.ts` cover AC-1..AC, e.g. the 1.2 reader under `.claude/skills/stack-profiles/reference/`.
CONTRACT:Keeps i.bak; measured 0.139s.
EOF
out="$(plan conflicts)"
assert_eq "a real shared path beside the junk is still a CONFLICT naming only that path" \
  "CONFLICT 5 src/core/world.ts" "$(pair_row A B | awk '{ print $1, NF, $5 }')"

# THE OTHER DIRECTION: the drop rules must not eat real basenames. The fallback
# exists for stories that declare nothing better, and dropping `plan.sh` here
# would turn a real CONFLICT into clear with nothing to say so.
fresh
story_with A feature PLANNED 1 <<'EOF'
CONTRACT:`plan.sh` gains a subcommand.
EOF
story_with B feature PLANNED 1 <<'EOF'
CONTRACT:`plan.sh` gains a different subcommand.
EOF
out="$(plan conflicts)"
assert_eq "a bare basename is still a path on the prose fallback" \
  "CONFLICT 5 plan.sh" "$(pair_row A B | awk '{ print $1, NF, $5 }')"

# --- AC-4: no touches:, and the pair is judged on the Contract ---------------
#
# With a **Writes:** line the fallback judges THAT line, not the prose: A only
# READS B's file. Today the prose is read and the pair is a CONFLICT on it.
fresh
story_with A feature PLANNED 1 <<'EOF'
CONTRACT:**Writes:** `src/core/world.ts`
CONTRACT:Reads the layout from `src/ui/panel.tsx`; does not change it.
EOF
story_with B feature PLANNED 1 <<'EOF'
CONTRACT:**Writes:** `src/ui/panel.tsx`
EOF
out="$(plan conflicts)"
assert_eq "with no touches:, a pair is judged on the **Writes:** lines, not on files merely read" \
  "clear" "$(row_status A B)"

# THE CONTROL: B writes A's file. Judged, not UNKNOWN, and a CONFLICT on that
# path alone.
fresh
story_with A feature PLANNED 1 <<'EOF'
CONTRACT:**Writes:** `src/core/world.ts`
CONTRACT:Reads the layout from `src/ui/panel.tsx`; does not change it.
EOF
story_with B feature PLANNED 1 <<'EOF'
CONTRACT:**Writes:** `src/core/world.ts`
EOF
out="$(plan conflicts)"
assert_eq "and two **Writes:** lines naming the same file are a CONFLICT on it" \
  "CONFLICT 5 src/core/world.ts" "$(pair_row A B | awk '{ print $1, NF, $5 }')"

# Without a **Writes:** line the fallback is still the prose, so HARNESS-006's
# pre-touches behaviour holds. (The describe blocks above pin the same thing;
# this one pairs a declared side with an undeclared one.)
fresh
story_with A feature PLANNED 1 <<'EOF'
CONTRACT:**Writes:** `src/core/world.ts`
EOF
story_with B feature PLANNED 1 <<'EOF'
CONTRACT:`src/core/world.ts` gains clampLatitude(deg: number): number.
EOF
out="$(plan conflicts)"
assert_eq "a **Writes:** side and a prose-only side are still judged against each other" \
  "CONFLICT 5 src/core/world.ts" "$(pair_row A B | awk '{ print $1, NF, $5 }')"

# --- AC-3: the RED row follows contract_paths, and moves only where decided --
#
# contract_unenforced reads contract_paths, so it follows the new output. The
# Contract's measurement: zero RED rows move among HARNESS-001..015 (DV-3
# checks the real backlog). These pin the mechanism.
#
# (a) No **Writes:** line: harness paths in full plus a bare `plan.sh`, which
# classifies `source`. Enforced, `fable`, exactly as today - rule 4 does not
# drop a basename with a real stem.
fresh
story_with A feature PLANNED 2 <<'EOF'
CONTRACT:`scripts/plan.sh` gains a subcommand; `.claude/tests/plan.test.sh` pins it; `plan.sh` stays bash.
EOF
assert_eq "a prose-only Contract naming a bare plan.sh keeps RED on the weaker model" \
  "fable" "$(red_model A)"

# (b) The same prose with a **Writes:** line naming only harness paths. The
# declared writes are what the lock would have to freeze, and it freezes none
# of them: the unenforced row, `opus`. This is Amendment A-1's move.
fresh
story_with A feature PLANNED 2 <<'EOF'
CONTRACT:**Writes:** `scripts/plan.sh`, `.claude/tests/plan.test.sh`
CONTRACT:`scripts/plan.sh` gains a subcommand; `.claude/tests/plan.test.sh` pins it; `plan.sh` stays bash.
EOF
assert_eq "a **Writes:** line naming only harness paths puts RED on the stronger model" \
  "opus" "$(red_model A)"

# (b') The prose names a source file the story only reads. The **Writes:** line
# decides, not the prose: still unenforced.
fresh
story_with A feature PLANNED 2 <<'EOF'
CONTRACT:**Writes:** `scripts/plan.sh`, `.claude/tests/plan.test.sh`
CONTRACT:Reads `src/core/world.ts` for its fixture shape; does not change it.
EOF
assert_eq "a source file the prose only reads does not make a harness-only **Writes:** enforced" \
  "opus" "$(red_model A)"

# (c) THE CONTROL: one source path on the **Writes:** line is enough for the
# lock to bite, so RED stays on the weaker model.
fresh
story_with A feature PLANNED 2 <<'EOF'
CONTRACT:**Writes:** `src/core/world.ts`, `scripts/plan.sh`
EOF
assert_eq "a **Writes:** line with one source path keeps RED on the weaker model" \
  "fable" "$(red_model A)"

summary "plan"
