#!/usr/bin/env bash
# Defence in depth for CI (and for humans working outside Claude Code).
#
# The phase-guard hook enforces the RED/GREEN lock at write time inside a
# session. This checks the same invariants after the fact, on a diff, where the
# hook was never in the loop - and the invariants the hook cannot see at all,
# because they are about a story file's content over time rather than about
# one write: frozen acceptance criteria, a tool-written gate record that matches
# the code being merged, a filled-in handoff, a scaffold inventory.
#
#   bash scripts/check-boundaries.sh [base-ref]      (default: origin/main)
#
# In GitHub Actions on a pull_request the checkout is a detached merge commit,
# so `git rev-parse --abbrev-ref HEAD` is "HEAD" and names no story. The story
# is identified from GITHUB_HEAD_REF there, and the gate tree hash is recomputed
# at PR_HEAD_SHA (set by the workflow) rather than at the merge commit, whose
# tree includes whatever moved on the base branch since.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
BASE="${1:-origin/main}"
export CLAUDE_PROJECT_DIR="$ROOT"
. "$ROOT/.claude/hooks/lib.sh"

fail=0
note() { printf '  %s\n' "$1"; }
problem() { printf 'FAIL  %s\n' "$1"; fail=1; }
ok() { printf 'ok    %s\n' "$1"; }

# section <file|-> <heading-prefix>   Body of "## <heading-prefix>..." up to the
# next "## ". "-" reads stdin, so `git show ref:path | section - ...` works.
section() {
  awk -v h="## $2" 'index($0, h) == 1 { on=1; next } on && /^## / { exit } on { print }' "$1"
}

# strip_comments   stdin with every HTML comment removed. The story template is
# mostly comments, so "did anybody write anything here" and "is there evidence
# in here" are both questions about what is left after they go.
strip_comments() {
  awk '{ s = s $0 "\n" }
       END {
         while ((i = index(s, "<!--")) > 0) {
           r = substr(s, i); j = index(r, "-->")
           if (j == 0) { s = substr(s, 1, i - 1); break }
           s = substr(s, 1, i - 1) substr(r, j + 3)
         }
         printf "%s", s
       }'
}

# has_content   True if stdin holds anything besides whitespace and HTML
# comments - i.e. somebody wrote something beyond the template.
#
# ONE awk, not `strip_comments | grep -q`. That pipeline had an awk which buffers
# the whole input and writes it in a single printf at END, feeding a grep which
# exits at its FIRST match: the writer died of SIGPIPE, `set -uo pipefail`
# promoted 141 to the pipeline's status, and the predicate returned FALSE for a
# section that plainly had content. Measured here at 1,000 and 50,000 bytes
# passing, 200,000 and 1,500,000 failing - and the threshold is a race on the
# pipe buffer rather than a constant, so the reporting project saw the same shape
# pass on Windows and fail on ubuntu-latest.
#
# It failed CLOSED, which is the better direction, and it refused good PRs from
# exactly the stories that had written the most.
#
# THE PIPE GOES, NOT `pipefail`. Dropping pipefail would have gone green
# instantly and masked every other instance of the shape in this file - and
# there were two more.
has_content() {
  awk '{ s = s $0 "\n" }
       END {
         while ((i = index(s, "<!--")) > 0) {
           r = substr(s, i); j = index(r, "-->")
           if (j == 0) { s = substr(s, 1, i - 1); break }
           s = substr(s, 1, i - 1) substr(r, j + 3)
         }
         exit (s ~ /[^[:space:]]/) ? 0 : 1
       }'
}

# has_pasted_output   True if stdin contains a fenced or indented block, which
# is what a pasted command output looks like in a story file. It cannot tell
# real output from prose in a fence, and does not try: it separates "here is
# what happened" from "trust me, it happened", which is the distinction the
# non-negotiables are actually about.
# has_waiver   True if stdin, comments removed, says the word "waived". The
# third instance of the same pipeline, and the one that would have been missed
# by fixing only the two named helpers - `printf | strip_comments | grep -qiE`,
# with the same buffering writer and the same early-exiting reader.
has_waiver() {
  awk '{ s = s $0 "\n" }
       END {
         while ((i = index(s, "<!--")) > 0) {
           r = substr(s, i); j = index(r, "-->")
           if (j == 0) { s = substr(s, 1, i - 1); break }
           s = substr(s, 1, i - 1) substr(r, j + 3)
         }
         exit (tolower(s) ~ /(^|[^a-z])waived([^a-z]|$)/) ? 0 : 1
       }'
}

# has_owner   True if stdin, comments removed, declares `Owner: <PHASE>`. The
# FOURTH instance of the pipeline, and the one that makes the case for removing
# the pipe rather than `pipefail`: it is not one of the named helpers, so fixing
# only those would have left a large ## Deferred verifications refused for
# naming no owner while naming one in its first line.
has_owner() {
  awk '{ s = s $0 "\n" }
       END {
         while ((i = index(s, "<!--")) > 0) {
           r = substr(s, i); j = index(r, "-->")
           if (j == 0) { s = substr(s, 1, i - 1); break }
           s = substr(s, 1, i - 1) substr(r, j + 3)
         }
         exit (tolower(s) ~ /(^|[^a-z])owner[^a-z]*:?[^a-z]*(red|green|gates|review|done)([^a-z]|$)/) ? 0 : 1
       }'
}

# One awk, for the reason spelled out on has_content above.
has_pasted_output() {
  awk '{ s = s $0 "\n" }
       END {
         while ((i = index(s, "<!--")) > 0) {
           r = substr(s, i); j = index(r, "-->")
           if (j == 0) { s = substr(s, 1, i - 1); break }
           s = substr(s, 1, i - 1) substr(r, j + 3)
         }
         n = split(s, lines, "\n")
         for (k = 1; k <= n; k++)
           if (lines[k] ~ /^[[:space:]]*(```|~~~)/ || lines[k] ~ /^    [^[:space:]]/) exit 0
         exit 1
       }'
}

# story_field <file|-> <key>   A frontmatter value.
story_field() { frontmatter_value "$1" "$2"; }   # lib.sh

# --- 1. Story files are well formed ----------------------------------------
story_fail_start=$fail
for f in docs/backlog/stories/*.md; do
  [ -e "$f" ] || continue
  base=$(basename "$f" .md)
  awk 'NR == 1 { ok = ($0 ~ /^---/); exit } END { exit !ok }' "$f" || { problem "$f: missing YAML frontmatter"; continue; }
  for key in id title type status phase; do
    grep -qE "^$key:" "$f" || problem "$f: frontmatter missing '$key'"
  done
  fid=$(story_field "$f" id)
  [ "$fid" = "$base" ] || problem "$f: frontmatter id '$fid' does not match filename '$base'"
  ph=$(story_field "$f" phase)
  grep -qE "^[[:space:]]*$ph[[:space:]]*\|" .claude/harness/phases.conf \
    || problem "$f: unknown phase '$ph'"
  grep -q '^## Acceptance criteria' "$f" || problem "$f: no '## Acceptance criteria' section"
done
[ "$fail" -eq "$story_fail_start" ] && ok "story files validated"

# --- 2. Runtime state must never be committed -------------------------------
if git ls-files --error-unmatch .claude/state/current-story.env >/dev/null 2>&1; then
  problem ".claude/state/current-story.env is tracked; it is machine-local state"
else
  # The `ok` used to sit outside this `if`, so the one repository this rule
  # exists for - the one that HAS committed the file - was told both things in
  # the same run: the refusal, and a line saying its state was not tracked.
  ok "harness state not tracked"
fi

# --- 3. The diff, and the story it belongs to --------------------------------
if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  note "base ref '$BASE' not available; skipped diff checks"
  exit $fail
fi

changed=$(git diff --name-only "$BASE"...HEAD 2>/dev/null || true)
classified=$(printf '%s\n' "$changed" | classify_stdin)
src_files=$(printf '%s\n' "$classified" | awk -F'\t' '$1 == "source" { print $2 }')
src=$(printf '%s\n' "$src_files" | grep -c '[^[:space:]]')
tst=$(printf '%s\n' "$classified" | awk -F'\t' '$1 == "test"' | grep -c '[^[:space:]]')

br="${GITHUB_HEAD_REF:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"

# Which story is this? Every check from 3b onward is gated behind the answer, so
# getting it wrong is not a missing check - it is eight of them passing in
# silence.
#
# The old answer parsed the branch name for `story/<ID>`. That works only while
# every branch is named the way new-story.sh defaults to naming it, and a real
# project's bug and chore stories were not: `bug/world-storage-megabyte-timeout`
# and `chore/tauri-capability-acl-guard` carry no story id anywhere, so `sid`
# came back empty and this script exited before checking the phase, the frozen
# criteria, the gate record or the handoff. The job went green in four seconds.
#
# Loosening the pattern cannot fix that - there is no id in the name to find. So
# the lookup is inverted: ask which story CLAIMS this branch. That datum already
# exists in every story's frontmatter and `phase.sh` already refuses to start a
# story whose `branch:` is not the checkout, so it is the authoritative side of
# the relationship rather than a convention.
sid=$(printf '%s' "$br" | sed -nE 's|^story/([A-Za-z0-9]+-[0-9]+).*|\1|p')
if [ -n "$sid" ] && [ ! -f "docs/backlog/stories/$sid.md" ]; then sid=""; fi
if [ -z "$sid" ] && [ -n "$br" ]; then
  claimants=""
  for f in docs/backlog/stories/*.md; do
    [ -e "$f" ] || continue
    [ "$(story_field "$f" branch)" = "$br" ] || continue
    claimants="$claimants $(basename "$f" .md)"
  done
  set -- $claimants
  case $# in
    0) ;;
    1) sid="$1" ;;
    # Silently taking the first would be the same defect wearing a smaller
    # costume: a wrong answer that looks like an answer.
    *) problem "branch '$br' is claimed by more than one story ($*). One branch, one story: fix the frontmatter of whichever is wrong." ;;
  esac
fi
sfile="docs/backlog/stories/$sid.md"
story_type=""; ph=""
if [ -n "$sid" ] && [ -f "$sfile" ]; then
  story_type=$(story_field "$sfile" type)
  ph=$(story_field "$sfile" phase)
fi

# 3a. Production code arrives with tests - or, under SCAFFOLD, with an inventory
if [ "$src" -gt 0 ] && [ "$tst" -eq 0 ]; then
  case "$story_type" in
    bootstrap|chore|spike)
      note "$src source file(s) without tests - allowed for a '$story_type' story, so the inventory must account for them"
      inv="$(section "$sfile" "Scaffold inventory")"
      if ! printf '%s\n' "$inv" | has_content; then
        problem "story $sid: source changed without tests, and ## Scaffold inventory is empty. Name every production file written and the test that covers it."
      else
        missing=""
        while IFS= read -r p; do
          [ -z "$p" ] && continue
          awk 'BEGIN{n=ARGV[1];ARGV[1]=""} index($0,n){h=1} END{exit !h}' "$p" <<< "$inv" || missing="$missing $p"
        done <<< "$src_files"
        if [ -n "$missing" ]; then
          problem "story $sid: changed source file(s) not named in ## Scaffold inventory:$missing"
        else
          ok "every changed source file is named in ## Scaffold inventory"
        fi
      fi ;;
    *) problem "$src source file(s) changed with no test changes. Production code ships with the test that demanded it." ;;
  esac
else
  ok "source changes accompanied by test changes ($src source, $tst test)"
fi

# 3a-bis. An upstream harness change bumps the version stamp
#
# A vendored copy cannot be dated from the outside - it carries the consuming
# project's git history, not this one's - so `.claude/harness/VERSION` is the
# only thing that can answer "which harness is this". A stamp somebody has to
# remember to bump is wrong exactly when it matters, so CI asks.
#
# The scoping is the careful part, and it is two conditions rather than one.
# This must never fire in a project BUILT on the harness, where .claude/ is
# edited routinely - project.conf, paths.conf, .gitignore - by people who are
# not upstream and have no version to stamp. So: only on a branch that is not a
# story branch (downstream work always is; an upstream harness round never is),
# and only while the repo is unbootstrapped (every real project sets
# BOOTSTRAPPED=yes; the template never does).
if [ -z "$sid" ] && ! grep -qE '^BOOTSTRAPPED=yes' .claude/harness/project.conf 2>/dev/null; then
  touched_harness=$(printf '%s\n' "$changed" | grep -cE '^(\.claude/|scripts/|\.github/)' || true)
  if [ "${touched_harness:-0}" -gt 0 ]; then
    if git cat-file -e "$BASE:.claude/harness/VERSION" 2>/dev/null \
       && [ "$(git show "$BASE:.claude/harness/VERSION" 2>/dev/null)" = "$(cat .claude/harness/VERSION 2>/dev/null)" ]; then
      problem "this changes the harness ($touched_harness file(s) under .claude/, scripts/ or .github/) and does not bump .claude/harness/VERSION. A vendored copy has no other way to tell how old it is, and two field reports have already been spent re-verifying defects that were fixed upstream."
    else
      ok "harness version bumped alongside the change"
    fi
  fi
fi

if [ -z "$sid" ]; then
  # Not an error: a harness PR, or a branch whose story does not exist yet.
  # But it is said out loud, because eight skipped checks and eight passing
  # ones look identical in a job summary - which is how six stories' worth of
  # PRs went unverified without anyone noticing.
  note "no story claims branch '$br'; the story checks below did not run"
  exit $fail
fi
if [ ! -f "$sfile" ]; then
  problem "branch '$br' names story $sid but $sfile does not exist"
  exit $fail
fi

# 3b. A PR is opened from REVIEW or DONE
case "$ph" in
  REVIEW|DONE) ok "story $sid is in $ph" ;;
  *) problem "story $sid is in phase '$ph'; a PR should be opened from REVIEW or DONE" ;;
esac

# 3c. The branch is the story's branch
fb=$(story_field "$sfile" branch)
if [ -n "$fb" ] && [ "$fb" != "$br" ]; then
  problem "story $sid: frontmatter says branch '$fb' but this is '$br'"
else
  ok "branch matches the story's frontmatter"
fi

# 3d. Acceptance criteria are frozen once a story leaves PLANNED (law 6): any
#     difference from the state committed immediately before the FIRST commit
#     that left PLANNED - else the base branch - needs an ## Amendments entry.
#     criteria_baseline decides which state that is, from the branch's history.
#
# criteria_baseline <story-file>   Prints one line, `<kind> <rev>`:
#   planned <sha>   the last committed PLANNED state on the branch
#   first <sha>     new in the PR and first committed outside PLANNED
#   base <BASE>     the base copy: the branch never committed it at PLANNED,
#                   or it had already left PLANNED on the base
#   unwalked <BASE> no merge base (depth-1 clone, unrelated history); compare
#                   with the base itself, as before
#   open -          no state has left PLANNED; nothing is frozen yet
#   none -          nothing to compare with
# The states, oldest first, are the base copy, every commit of BASE..HEAD that
# holds the file (not --first-parent: in CI HEAD is a merge whose first parent
# is the base), and the working tree. Nothing after the first non-PLANNED state
# is read, so a later return to PLANNED cannot move the baseline. Each copy is
# read into a variable and fed by here-string: `git show | section -` was a
# pipeline into an early-exiting awk (see has_content above).
criteria_baseline() {
  local f="$1" txt cph rev prev_kind="" prev_rev="" have_base=0
  git cat-file -e "$BASE:$f" 2>/dev/null && have_base=1
  if ! git merge-base "$BASE" HEAD >/dev/null 2>&1; then
    if [ "$have_base" = 1 ]; then printf 'unwalked %s\n' "$BASE"; else printf 'none -\n'; fi
    return 0
  fi
  if [ "$have_base" = 1 ]; then
    txt="$(git show "$BASE:$f" 2>/dev/null)"
    cph="$(frontmatter_value - phase <<< "$txt")"; cph="${cph//[[:space:]]/}"
    if [ "$cph" != PLANNED ]; then printf 'base %s\n' "$BASE"; return 0; fi
    prev_kind=base; prev_rev="$BASE"
  fi
  for rev in $(git rev-list --reverse --topo-order "$BASE"..HEAD 2>/dev/null); do
    txt="$(git show "$rev:$f" 2>/dev/null)" || continue
    cph="$(frontmatter_value - phase <<< "$txt")"; cph="${cph//[[:space:]]/}"
    if [ "$cph" != PLANNED ]; then
      case "$prev_kind" in
        "")   printf 'first %s\n' "$rev" ;;
        base) printf 'base %s\n' "$BASE" ;;
        *)    printf 'planned %s\n' "$prev_rev" ;;
      esac
      return 0
    fi
    prev_kind=planned; prev_rev="$rev"
  done
  cph="$(frontmatter_value "$f" phase)"; cph="${cph//[[:space:]]/}"
  if [ "$cph" = PLANNED ]; then printf 'open -\n'; return 0; fi
  case "$prev_kind" in
    "")   printf 'none -\n' ;;
    base) printf 'base %s\n' "$BASE" ;;
    *)    printf 'planned %s\n' "$prev_rev" ;;
  esac
}
crit_base="$(criteria_baseline "$sfile")"
crit_kind="${crit_base%% *}"; crit_rev="${crit_base#* }"
crit_label=""; crit_txt=""
case "$crit_kind" in
  unwalked)
    note "no merge base with $BASE, so the branch's history cannot be walked; criteria compared with $BASE itself"
    crit_kind=base ;;
esac
case "$crit_kind" in
  planned) crit_label="the last committed PLANNED state (${crit_rev:0:7})" ;;
  first)   crit_label="the first commit that left PLANNED (${crit_rev:0:7})" ;;
  base)    crit_label="$BASE"; crit_rev="$BASE" ;;
esac
if [ "$crit_kind" = open ]; then
  note "story $sid has not left PLANNED in any committed state; its criteria are not frozen yet"
elif [ -n "$crit_label" ] && git cat-file -e "$crit_rev:$sfile" 2>/dev/null; then
  crit_txt="$(git show "$crit_rev:$sfile" 2>/dev/null)"
  before="$(section - "Acceptance criteria" <<< "$crit_txt")"
  before="$(sed 's/[[:space:]]*$//' <<< "$before")"
  after=$(section "$sfile" "Acceptance criteria" | sed 's/[[:space:]]*$//')
  if [ "$before" = "$after" ]; then
    ok "acceptance criteria unchanged since $crit_label"
  elif section "$sfile" "Amendments" | has_content; then
    ok "acceptance criteria changed, with an ## Amendments entry"
  else
    problem "story $sid: ## Acceptance criteria differ from $crit_label with no ## Amendments entry. Criteria are frozen once a story leaves PLANNED, against the last state committed while it was PLANNED (else the base branch); record which AC changed, what it said, what it says now, who approved it and why."
  fi
else
  note "story file is new in this PR; nothing to freeze the criteria against"
fi

# 3e. The gate record was written by gates.sh and matches the code being merged
bgates=""
case "$ph:$story_type" in
  REVIEW:spike|DONE:spike) note "spike story; gate record not required" ;;
  REVIEW:*|DONE:*)
    gr="$(section "$sfile" "Gate results")"
    if ! awk 'BEGIN{n=ARGV[1];ARGV[1]=""} index($0,n){h=1} END{exit !h}' "$GATE_MARKER" <<< "$gr"; then
      problem "story $sid: ## Gate results was not written by scripts/gates.sh. Run 'bash scripts/gates.sh' - it records its own result; a pasted summary is not evidence."
    else
      res=$(printf '%s\n' "$gr" | sed -nE 's/^[[:space:]]*result:[[:space:]]*//p' | head -1)
      case "$res" in
        pass*) ok "recorded gate result: $res" ;;
        blocked*)
          # The third state. BLOCKED means the environment would not let a
          # required gate start, so it has no verdict at all - and a story
          # cannot get one from the machine that refused it. The loop's answer
          # is CI, a different machine under a different policy: REVIEW with
          # the gate pending CI, DONE only once CI has run it. Refusing this
          # outright, as "must start with pass" did, refused the one path
          # /advance-story prescribes.
          #
          # The evidence has to be on ONE LINE with the gate id on it, because
          # the alternative - looking for the words anywhere in the story - is
          # satisfied by a story that mentions CI about something else.
          # `## Gate results` is excluded implicitly: gates.sh writes the BLOCKED
          # line there and nothing else, and it carries neither phrase.
          ok "recorded gate result: $res"
          bgates=$(printf '%s\n' "$gr" | sed -nE 's/^[[:space:]]*BLOCKED[[:space:]]+([^ (]+).*/\1/p' | sort -u)
          if [ -z "$bgates" ]; then
            problem "story $sid: the record says blocked but no BLOCKED line names a gate. Re-run 'bash scripts/gates.sh'."
          fi
          for g in $bgates; do
            if [ "$ph" = "REVIEW" ]; then
              if grep -qiE "$g.*pending CI|pending CI.*$g" "$sfile"; then
                ok "blocked gate '$g' is recorded as pending CI"
              else
                problem "story $sid: gate '$g' was BLOCKED - the environment would not launch it - and nothing in the story says so. Record the PO decision on one line naming the gate and 'pending CI': which gate, the log line quoted, and what makes this the environment rather than the code. See /advance-story, GATES."
              fi
            else
              if grep -qiE "$g.*https?://|https?://.*$g" "$sfile"; then
                ok "blocked gate '$g' was verified on CI"
              else
                problem "story $sid: gate '$g' was BLOCKED locally and has not been verified on CI, so this story is not DONE. Quote the PR's CI run for it in the story - one line carrying the gate id and the run URL - or re-run the gates somewhere they are not blocked."
              fi
            fi
          done ;;
        *) problem "story $sid: recorded gate result is '$res'" ;;
      esac
      rec=$(printf '%s\n' "$gr" | sed -nE 's/^[[:space:]]*tree:[[:space:]]*([0-9a-f]+).*/\1/p' | head -1)
      if [ -n "${PR_HEAD_SHA:-}" ]; then
        now=$(gate_tree_hash_of "$PR_HEAD_SHA"); where="commit ${PR_HEAD_SHA:0:7}"
      else
        now=$(gate_tree_hash); where="the working tree"
      fi
      if [ -n "$rec" ] && [ "$rec" = "$now" ]; then
        ok "gate record matches $where (tree $rec)"
      else
        problem "story $sid: gates were recorded against tree '${rec:-none}' but $where is '$now'. Source, test or config changed after the last full gate run; run 'bash scripts/gates.sh' again and commit the result."
      fi
    fi ;;
esac

# 3e-i. A gate the story escalated must appear in the record as having passed.
#
# gates.sh enforces this while it runs; this catches the record written before
# the escalation was added, where the gate is optional again by the time
# anyone looks - and the record that was never written at all.
#
# Outside the case above on both axes: every story type, spike included (the
# spike exemption is about the RECORD; a spike that names a gate in
# required_gates has claimed something needs checking), and outside the marker
# test's else, so a story with no ## Gate results is told WHICH gate it did not
# run.
#
# A gate is only BLOCKED because it is required, so one 3e judged BLOCKED is
# deferred to 3e's pending-CI and CI-run checks (HARNESS-071); bgates is set only
# by 3e's blocked arm, so a spike's BLOCKED gate is still owed a PASS here.
case "$ph" in
  REVIEW|DONE)
    gr="$(section "$sfile" "Gate results")"
    for g in $(frontmatter_list "$sfile" required_gates); do
      if grep -qx -- "$g" <<< "$bgates"; then
        ok "story-required gate '$g' was BLOCKED; judged as pending CI above"
      elif awk 'BEGIN{r=ARGV[1];ARGV[1]=""} $0~r{h=1} END{exit !h}' "^[[:space:]]*PASS[[:space:]]+$g( |\(|$)" <<< "$gr"; then
        ok "story-required gate '$g' passed in the recorded run"
      else
        problem "story $sid: frontmatter requires gate '$g', but the recorded run has no PASS for it. Run 'bash scripts/gates.sh' again."
      fi
    done ;;
esac

# 3f. The handoff was actually written
case "$story_type" in
  feature|fix)
    if section "$sfile" "Handoff" | has_content; then
      ok "## Handoff is filled in"
    else
      problem "story $sid: ## Handoff is empty. It is the only channel to the next agent; RED is not finished without it."
    fi ;;
esac


# 3g. A corrected test was observed to fail too
#
# The first non-negotiable is a property of an ASSERTION, not of a phase: a
# test that has never been seen to fail is not a test. An ordinary RED
# discharges it as a side effect, because the implementation does not exist
# yet. A test corrected on a RETURN cannot: the implementation is right there,
# so the corrected assertion passes on its first execution and passes forever,
# and it could assert nothing at all without anything noticing.
#
# That is why a return to RED has to leave evidence behind - the red from a
# deliberate, reverted mutation, or a before/after measurement where the defect
# was cost. Prose describing either is not either. The same rule already
# applies to ## Gate probes, and for the same reason.
for sec in Regressions "Gate probes"; do
  body="$(section "$sfile" "$sec")"
  printf '%s\n' "$body" | has_content || continue
  if printf '%s\n' "$body" | has_pasted_output; then
    ok "## $sec carries pasted output"
  else
    problem "story $sid: ## $sec describes something without showing it. What counts as showing it is the shape, not the words: a line beginning with three backticks or three tildes (a fence), or a line indented by exactly four spaces - a tab does not count, nor does inline code in backticks, nor anything inside an HTML comment. Paste the output as such a block - the failure a reverted mutation produced, or the before/after measurement taken under the gate command. A test corrected while the implementation exists has never been observed to fail, and a description of red is not red."
  fi
done


# 3h. A deferred verification is discharged, or waived in writing
#
# Some verifications provably cannot run in the phase that wants them. RED
# cannot mutate an encoder to prove a round-trip property discriminates when
# the encoder is what the story is about to build; the honest move is to name
# the control at PLANNED, say which phase owns it, and run it there. That
# pattern worked - and then somebody noticed the commitment was prose, and
# prose does not fail a build. The story that ran its deferred control ran it
# because it had written the promise into its own report twice.
#
# So the block has two obligations, and each is one line of grep: it names the
# phase that owns the entry, and by the time a PR exists it carries either the
# output of having run it or an explicit waiver. A waiver is a decision the
# next person can argue with; silence is not.
dv="$(section "$sfile" "Deferred verifications")"
if printf '%s\n' "$dv" | has_content; then
  # `Owner: <PHASE>`, declared - not a phase word loose in the prose. The first
  # version grepped the whole block for any phase name, and the story template
  # asks the author to write "why the phase that wants it cannot run it", so the
  # very sentence the template prompts ("RED cannot run this") satisfied the
  # check with no owner named. A check that its own boilerplate discharges is
  # not a check.
  if printf '%s\n' "$dv" | has_owner; then
    ok "## Deferred verifications names the phase that owns each entry"
  else
    problem "story $sid: ## Deferred verifications does not declare an owner. Write 'Owner: GATES' (or RED, GREEN, REVIEW) beside what it verifies. A phase merely NAMED in the prose is not an owner - the template asks you to say why the phase that wants it cannot run it, so 'RED cannot run this' would otherwise discharge this check while naming nobody."
  fi
  if printf '%s\n' "$dv" | has_pasted_output; then
    ok "## Deferred verifications carries its result"
  elif printf '%s\n' "$dv" | has_waiver; then
    ok "## Deferred verifications carries an explicit waiver"
  else
    problem "story $sid: ## Deferred verifications has no result and no waiver. The phase that owned it has passed and nothing says what happened. What counts as a result is the shape, not the words: a line beginning with three backticks or three tildes (a fence), or a line indented by exactly four spaces - a tab does not count, nor does inline code in backticks, nor anything inside an HTML comment. Paste the output as such a block - what was mutated and what failed - or write WAIVED with the reason. This is the control that makes a threshold or a round trip mean anything; skipping it silently is the failure it was filed against."
  fi
fi


# 3i. A RED commit may declare a test dependency, and nothing else
#
# RED owns the manifest now, because a failing test routinely needs a test-only
# dependency - a temp-directory crate, an async pytest plugin, a snapshot
# matcher - and every ecosystem declares that in the same file as the production
# dependencies. Frozen as `config`, RED could not say what its tests needed
# while GREEN could add anything at all: the phase forbidden from writing
# production code was the only one that could not declare a test dependency.
#
# That permission is only safe if something reads what RED actually wrote.
# Otherwise "RED may edit the manifest" means "RED may add a production
# dependency", and the phase that may not write production code gets to pull
# production code in from a registry instead. The lock cannot do this - it sees
# a path, never a diff - so the commit does.
#
# It has to be per-COMMIT, not on the branch diff. By the time a PR exists the
# story says REVIEW, and the merged diff cannot say which phase added which
# line; only the story file as committed alongside each change can.
#
# The comparison is whole-file rather than hunk-parsing: take each side of the
# commit, delete the dev-dependency block, and require what is left to be
# identical. A diff-hunk reader has to understand context lines and section
# boundaries; this only has to find one block.
manifest_strip_dev() { # <path> ; content on stdin
  case "$(basename "$1")" in
    *.toml)
      # A section runs until the next header. Dev sections are Cargo's
      # dev-dependencies (including target-specific ones), PEP 735 dependency
      # groups, and poetry's dev/test groups. project.optional-dependencies is
      # deliberately NOT here: extras can be production extras, and the safe
      # error is a refusal RED can escalate, never a permission nobody checks.
      awk '
        /^[[:space:]]*\[/ {
          h = $0
          sub(/^[[:space:]]*\[+/, "", h); sub(/\][[:space:]]*$/, "", h); sub(/\]$/, "", h)
          gsub(/["'"'"']/, "", h)
          indev = (h ~ /(^|\.)dev-dependencies$/) ||
                  (h == "dependency-groups") || (h ~ /^dependency-groups\./) ||
                  (h ~ /^tool\.poetry\.group\.(dev|test)[^.]*\.dependencies$/)
          if (indev) next
        }
        !indev { print }
      ' ;;
    *.json)
      # Brace depth from the key, so a nested object inside devDependencies
      # cannot end the block early.
      awk '
        !skip && /"devDependencies"[[:space:]]*:/ {
          rest = substr($0, index($0, ":"))
          o = gsub(/\{/, "{", rest); c = gsub(/\}/, "}", rest)
          depth = o - c
          if (depth > 0) skip = 1
          next
        }
        skip {
          o = gsub(/\{/, "{"); c = gsub(/\}/, "}")
          depth += o - c
          if (depth <= 0) skip = 0
          next
        }
        { print }
      ' ;;
    *)
      # A manifest whose format nobody taught this. Say so rather than compare
      # raw text and report a mystery - and never pass it silently.
      printf '__UNPARSEABLE__\n' ;;
  esac
}

# Punctuation is not a dependency. Adding a dev block where none existed leaves
# a trailing comma or a blank line behind on one side only, and a check that
# calls that a production change is a check people route around.
manifest_norm() { sed -e 's/[[:space:]]*$//' -e 's/,$//' | grep -v '^[[:space:]]*$' || true; }

red_manifest_problem=0
red_manifest_checked=0
for c in $(git rev-list "$BASE"..HEAD 2>/dev/null); do
  ph_at="$(git show "$c:$sfile" 2>/dev/null | sed -nE 's/^phase:[[:space:]]*//p' | head -1 | tr -d '[:space:]')"
  [ "$ph_at" = "RED" ] || continue
  for f in $(git diff-tree --no-commit-id --name-only -r "$c" 2>/dev/null); do
    [ "$(classify "$f")" = "manifest" ] || continue
    # A lockfile has no dev/production split to read, so nothing here can verify
    # one. It is permitted unchecked, and that is sound only because the
    # manifest it follows from IS checked: a dependency nobody declared cannot
    # be used by production code.
    case "$(basename "$f")" in
      *.lock|*-lock.json|*lock.yaml|*lock.yml) continue ;;
    esac
    before="$(git show "$c^:$f" 2>/dev/null | manifest_strip_dev "$f" | manifest_norm)"
    after="$(git show "$c:$f"  2>/dev/null | manifest_strip_dev "$f" | manifest_norm)"
    red_manifest_checked=$((red_manifest_checked+1))
    case "$after" in
      *__UNPARSEABLE__*)
        red_manifest_problem=1
        problem "story $sid: commit ${c%${c#???????}} changed '$f' in RED, and this check does not know how to find the test-dependency block in that format. Teach manifest_strip_dev in scripts/check-boundaries.sh, or make the change in GREEN." ;;
      *)
        if [ "$before" != "$after" ]; then
          red_manifest_problem=1
          problem "story $sid: commit ${c%${c#???????}} changed '$f' outside the test-dependency block while the story was in RED. RED may declare what its TESTS need - a dev-dependency, a dependency group - and nothing else; a production dependency is a GREEN change, and so is bumping one. Move it to GREEN, or if the test genuinely needs it, say which block it belongs in."
        fi ;;
    esac
  done
done
if [ "$red_manifest_checked" -gt 0 ] && [ "$red_manifest_problem" -eq 0 ]; then
  ok "RED touched only test dependencies ($red_manifest_checked manifest change(s))"
fi

# --- 3j. GREEN and GATES add no suppression -----------------------------------
#
# The lock freezes tests in GREEN and GATES, and 3i reads what RED puts in a
# manifest. Nothing read what GREEN and GATES ADD to source, and GATES is the
# phase whose job is making a lint, type or coverage failure go away - the
# cheapest way to do which is one line that silences the tool. rules.md forbids
# that in prose, and prose does not fail a build. So this walks every commit, as
# 3i does, reads the phase the story was committed at alongside it, and refuses
# an ADDED line of a `source` or `config` path that is a suppression directive,
# unless the working-tree story's ## Suppressions declares it.
#
# Which paths count is classify's answer, never a regex here: docs, harness and
# test paths are out by category, so a project that reclassifies a path moves it
# in or out of this rule with no change to this block.
#
# suppression_needles   One `<rule id>|<ERE>` row per directive. Every ERE is
# anchored on the comment opener, and the directive is the first thing after it,
# so a comment that MENTIONS a directive is not one. The opener must begin the
# line or follow whitespace or one of `;,)}` - `(^|[[:space:];,)}])`, spelled
# out in every row - so `foo();// eslint-disable-line` and `x = eval(s)# noqa`
# are caught. hadolint and shellcheck honour only a whole-line comment, so their
# rows anchor to the start of the line instead.
#
# The anchor is a trade, not a free lunch. It keeps a `#` or `//` that follows a
# quote or a `/` from counting, which is what keeps `"# noqa: S307"` and
# `http://x/#noqa:frag` clean - and the same rule misses a real directive glued
# to those characters or to a word. Known misses, each honoured by its tool:
# after a closing quote (`s = "a"# noqa`), after an identifier or a digit
# (`x=1# noqa`, `foo// eslint-disable-line`), after `]`
# (`a[0]// eslint-disable-line`), and after `(` or `{`
# (`fn f(#[allow(unused)] x: u32)`, `{// eslint-disable-line`). A miss is a
# directive this rule does not see, not one it waves through; widen the class
# only with a C-3-style control showing the string and URL cases stay clean.
# The rows are data: a new directive is a new row and nothing else.
#
# The stub-* rows are a different kind: a stub stands in for an implementation,
# and the claim it breaks is "full coverage of the behaviour the story claims",
# not "the tests are frozen". A stub is an expression, not a comment, so it sits
# after `(`, `=`, `>`, `,` or `|` as readily as after whitespace, and its anchor
# is anything but an identifier character or a quote (double, single or
# backtick), spelled out in every stub row - so `foo(todo!())` and
# `_ => todo!()` are caught, and `"todo!()"` and `my_todo!(` are not. The rows read a line, not a token stream, so a COMMENT
# quoting a stub is refused too; that false positive is accepted, and one
# ## Suppressions line clears it. One example line each, verbatim, so a probe
# that widens the category test below has a real line per rule:
#   throw new Error("not implemented")
#   todo!()
#   unimplemented!("later")
#   raise NotImplementedError
#   push_error("not implemented")
#   } catch (e) {}
# stub-throw lets the message carry a prefix inside the quotes, so TypeScript's
# own quick fix, `throw new Error("Method not implemented.")`, is caught, and so
# are `not yet implemented` and `NOT IMPLEMENTED`; `"could not open the file"`
# is not. stub-gd's `false` must end the identifier, so `assert(false_positives
# == 0)` is clean.
# `raise NotImplementedError` has one legitimate use, the abstract method, and
# suppression_hits drops a stub-raise hit whose two previous ADDED lines in the
# same hunk are a `def` and, above it, `@abstractmethod` or `@abc.abstractmethod`.
# A decorator that is context is not in the diff, so it does not excuse the raise.
#
# An empty handler is usually two lines: an opener, and its closer as the very
# next ADDED line in the same hunk. A row reads one line, so that shape is not a
# row; suppression_hits keeps that window itself - see below. The two empty-handler
# rows are the ONE-line shape the window cannot see, `} catch (e) {}` and
# `except: pass`, under the same rule id, so one ## Suppressions line declares
# either; a one-line handler with a body matches neither. The two opener shapes:
#   } catch (e) {
#   except Exception:
# A brace opener must end in `{` and its closer begin with `}`, so `} finally {`
# closes it too; a colon opener's closer is a lone `pass` or `...`. Allman braces
# and `.catch(() => {` are not openers, and `catch (e) { log(e) }` has a body.
# Under --unified=0 an opener that is context never reaches the awk, so a closer
# added under an existing handler is not refused.
#
# The table reaches awk in its input stream, never through `awk -v`: -v
# processes escapes, and gawk turns `\[` into `[` and dies on the bracket.
suppression_needles() {
  cat <<'NEEDLES'
eslint-disable|(^|[[:space:];,)}])(//|/\*)[[:space:]]*eslint-disable([[:space:]]|-next-line|-line|$|\*/)
ts-ignore|(^|[[:space:];,)}])//[[:space:]]*@ts-(ignore|nocheck|expect-error)([^A-Za-z-]|$)
biome-ignore|(^|[[:space:];,)}])(//|/\*)[[:space:]]*biome-ignore[[:space:]]
noqa|(^|[[:space:];,)}])#[[:space:]]*noqa([[:space:]:]|$)
type-ignore|(^|[[:space:];,)}])#[[:space:]]*type:[[:space:]]*ignore([[:space:][]|$)
rust-allow|(^|[[:space:];,)}])#!?\[(allow|expect)\(
gd-warning-ignore|(^|[[:space:];,)}])@warning_ignore\(
coverage-ignore|(^|[[:space:];,)}])(//|/\*)[[:space:]]*(istanbul|c8|v8)[[:space:]]+ignore([[:space:]]|$|\*/)
no-cover|(^|[[:space:];,)}])#[[:space:]]*pragma:[[:space:]]*no[[:space:]]+(cover|branch)([^A-Za-z]|$)
stryker-disable|(^|[[:space:];,)}])(//|/\*|#)[[:space:]]*Stryker[[:space:]]+disable([[:space:]]|$|\*/)
hadolint-ignore|^[[:space:]]*#[[:space:]]*hadolint[[:space:]]+ignore=
shellcheck-disable|^[[:space:]]*#[[:space:]]*shellcheck[[:space:]]+disable=
stub-throw|(^|[^A-Za-z0-9_"'`])throw[[:space:]]+(new[[:space:]]+)?(NotImplementedError[[:space:]]*\(|Error[[:space:]]*\([[:space:]]*["'`][^"'`]*([Nn]ot[[:space:]]*([Yy]et[[:space:]]*)?[Ii]mplemented|NOT[[:space:]]*IMPLEMENTED|TODO|[Uu]nimplemented))
stub-todo|(^|[^A-Za-z0-9_"'`])(todo|unimplemented|unreachable)!\(
stub-raise|(^|[^A-Za-z0-9_"'`])raise[[:space:]]+NotImplementedError([[:space:](]|$)
stub-gd|(^|[^A-Za-z0-9_"'`])(push_error|assert)\([[:space:]]*(false([^A-Za-z0-9_]|$)|"[Nn]ot[[:space:]]+implemented)
empty-handler|(^|[^A-Za-z0-9_"'`])catch([[:space:]]*\([^)]*\))?[[:space:]]*[{][[:space:]]*[}]
empty-handler|^[[:space:]]*except([[:space:]]+[^:]+)?:[[:space:]]*(pass|\.\.\.)[[:space:]]*(#.*)?$
NEEDLES
}

# suppression_hits   stdin: the needle table, a `--8<-- diff` line, then one
# file's `git show --unified=0` diff. Prints `<line no>|<rule id>|<line, trimmed>`
# per rule id an ADDED line matches, in table order; a second row of an id
# already printed for the line prints nothing more. Only lines after the
# first `@@` are hunk lines, so the `+++` header is skipped as a header and an
# added line that happens to begin `++` is still read. The leading `+` is removed
# before matching, or the `^` of every opener anchor would see it.
#
# It also keeps a window over the ADDED lines: the previous one's text (p1), the
# one before it (p2), and, when p1 was a handler opener, its kind (pk), line
# number and trimmed text. A hunk header or a `diff --git` line clears all of
# it, and so does a context line; a `-` line or a `\ No newline` marker does
# not, because neither sits between two added lines of one hunk. An added line
# that is not the armed opener's closer disarms it. So an opener whose very
# next added line is its closer prints `<opener line no>|empty-handler|<opener,
# trimmed>`, once. A row hit on any line of a handler does not stand in for the
# handler. The line is still tested as an opener and as a closer, so
# `except:  # noqa: E722` over `pass` prints both `noqa` and `empty-handler` at
# the opener's line, and `pass  # noqa: SIM105` under `except ValueError:` prints
# `noqa` at its own line and `empty-handler` at the opener's. Every row is
# tested, so a directive never hides what else the line is:
# `} catch {} // eslint-disable-line no-empty` prints `eslint-disable`, then
# `empty-handler`, and `raise NotImplementedError  # pragma: no cover` prints
# `no-cover`, then `stub-raise`, each pair at that line; declaring one does not
# declare the other. A line that reported empty-handler through a row gets no
# second one from the window when it is also an opener, so
# `} catch (A e) {} catch (B e) {` over `}` is refused once. A stub-raise
# hit is dropped when p1 is a `def` and p2 an
# `@abstractmethod` - three adjacent added lines, nothing looser - and only that
# id: the line's other rows are still tested, so `# pragma: no cover` on an
# abstract method's raise is refused as no-cover. The opener
# anchor is the stub rows' anchor; its single quote is built from `%c` because
# this program sits inside a single-quoted shell string.
suppression_hits() {
  awk '
    BEGIN {
      O = "(^|[^A-Za-z0-9_\"" sprintf("%c", 39) "`])"
      bo = O "catch([[:space:]]*\\([^)]*\\))?[[:space:]]*[{][[:space:]]*$"
    }
    function clear() { p1 = ""; p2 = ""; pk = "" }
    !d && $0 == "--8<-- diff" { d = 1; next }
    !d { i = index($0, "|"); if (i) { n++; id[n] = substr($0, 1, i - 1); re[n] = substr($0, i + 1) }; next }
    /^diff --git / { inh = 0; clear(); next }
    /^@@ / { h = $0; sub(/^@@ -[0-9,]+ \+/, "", h); sub(/[^0-9].*$/, "", h); ln = h + 0; inh = 1; clear(); next }
    !inh { next }
    /^\+/ {
      s = substr($0, 2); eh = 0; split("", seen)
      t = s; gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
      for (k = 1; k <= n; k++) {
        if ((id[k] in seen) || s !~ re[k]) continue
        if (id[k] == "stub-raise" && p1 ~ /^[[:space:]]*(async[[:space:]]+)?def[[:space:]]/ && p2 ~ /^[[:space:]]*@(abc\.)?abstractmethod/) continue
        printf "%d|%s|%s\n", ln, id[k], t
        seen[id[k]] = 1
        if (id[k] == "empty-handler") eh = 1
      }
      if (!peh && (pk == "brace" && s ~ /^[[:space:]]*[}]/ || pk == "colon" && s ~ /^[[:space:]]*(pass|\.\.\.)[[:space:]]*(#.*)?$/))
        printf "%d|empty-handler|%s\n", pln, pt
      pk = ""
      if (s ~ bo) pk = "brace"
      else if (s ~ /^[[:space:]]*except([[:space:]]+[^:]+)?:[[:space:]]*(#.*)?$/) pk = "colon"
      if (pk != "") { pln = ln; peh = eh; pt = s; gsub(/^[[:space:]]+|[[:space:]]+$/, "", pt) }
      p2 = p1; p1 = s
      ln++; next
    }
    /^-/ || /^\\/ { next }
    { clear(); ln++ }
  '
}

# suppression_declared <path> <rule id>   stdin: the comment-stripped
# ## Suppressions section. Prints `declared` when one line carries the path, the
# rule id and `approved by`, all case-insensitive; otherwise what the first line
# naming the path is missing; otherwise nothing. A line names the path only as a
# whole token - split on whitespace and backticks, then `,;:()'"` trimmed from
# each end of the token and never from inside it, so `app/(auth)/page.tsx`,
# `'src/a.ts'` and `(src/a.ts)` all count - that comes before any other token
# holding a `/`, so `src/a.ts.bak` and `src/b.ts ... same as src/a.ts` name
# neither `src/a.ts`; the partial-entry answer uses the same rule.
# The rule id counts as `[id]` anywhere, and as a bare word only on a line that
# brackets no id, so `[noqa] ... not eslint-disable` declares only noqa. ARGV,
# not -v, for the same reason as the table.
suppression_declared() {
  awk 'BEGIN { p = tolower(ARGV[1]); r = tolower(ARGV[2]); ARGV[1] = ""; ARGV[2] = "" }
    {
      l = tolower($0)
      nt = split(l, tok, /[[:space:]`]+/); named = 0
      for (j = 1; j <= nt; j++) {
        gsub(/^[,;:()'\''"]+|[,;:()'\''"]+$/, "", tok[j])
        if (tok[j] == p) { named = 1; break }
        if (index(tok[j], "/")) break
      }
      if (!named) next
      hr = index(l, "[" r "]") > 0
      if (!hr && l !~ /\[[a-z-]+\]/) { x = l; while ((i = index(x, r)) > 0) {
        b = (i == 1) ? "" : substr(x, i - 1, 1); a = substr(x, i + length(r), 1)
        if (b !~ /[a-z0-9_-]/ && a !~ /[a-z0-9_-]/) { hr = 1; break }
        x = substr(x, i + length(r)) } }
      ha = index(l, "approved by") > 0
      if (hr && ha) { print "declared"; found = 1; exit }
      if (miss == "") miss = (!hr && !ha) ? "the rule id [" r "] and '\''approved by'\''" : (!hr ? "the rule id [" r "]" : "'\''approved by'\''")
    }
    END { if (!found && miss != "") print miss }' "$1" "$2"
}

sup_table="$(suppression_needles)"
sup_decl="$(section "$sfile" "Suppressions" | strip_comments)"
sup_judged=0
sup_refused=0
sup_declared_seen=""
for c in $(git rev-list "$BASE"..HEAD 2>/dev/null); do
  c7="${c%${c#???????}}"
  # The source and config paths this commit changed; a commit with none has
  # nothing this rule could judge, in any phase.
  sup_paths=""
  for f in $(git diff-tree --no-commit-id --name-only -r "$c" 2>/dev/null); do
    case "$(classify "$f")" in source|config) sup_paths="$sup_paths $f" ;; esac
  done
  [ -n "$sup_paths" ] || continue
  # 3i skips a commit whose story file it cannot read. This one says so: a
  # commit the rule could not judge is never silently counted as clean.
  if ! sup_story="$(git show "$c:$sfile" 2>/dev/null)"; then
    note "commit $c7: story file not readable at this commit; GREEN/GATES additions not judged"
    continue
  fi
  ph_at="$(frontmatter_value - phase <<< "$sup_story")"; ph_at="${ph_at//[[:space:]]/}"
  # The documented GATES -> REVIEW step sets the phase and only then commits, so
  # work done in GATES can land in a commit whose own story says REVIEW. Its
  # first parent's committed phase says which phase the work was done in. A root
  # commit, or a parent with no story file, has no parent phase.
  case "$ph_at" in
    GREEN|GATES) ;;
    *) sup_pph=""
       if sup_pstory="$(git show "$c^:$sfile" 2>/dev/null)"; then
         sup_pph="$(frontmatter_value - phase <<< "$sup_pstory")"; sup_pph="${sup_pph//[[:space:]]/}"
       fi
       case "$sup_pph" in GREEN|GATES) ph_at="$ph_at, after $sup_pph" ;; *) continue ;; esac ;;
  esac
  sup_judged=$((sup_judged+1))
  for f in $sup_paths; do
    if ! sup_diff="$(git show --format= --unified=0 "$c" -- "$f" 2>/dev/null)"; then
      sup_refused=1
      problem "story $sid: commit $c7 ($ph_at) changed '$f', and its diff could not be read, so nothing can say the lines it added are not suppressions."
      continue
    fi
    sup_hits="$(suppression_hits <<< "$sup_table"$'\n'"--8<-- diff"$'\n'"$sup_diff")"
    [ -n "$sup_hits" ] || continue
    while IFS='|' read -r sup_n sup_rid sup_text; do
      [ -n "$sup_n" ] || continue
      sup_state="$(suppression_declared "$f" "$sup_rid" <<< "$sup_decl")"
      if [ "$sup_state" = declared ]; then
        case "$sup_declared_seen" in
          *"|$sup_rid $f|"*) ;;
          *) sup_declared_seen="$sup_declared_seen|$sup_rid $f|"
             ok "suppression [$sup_rid] in '$f' is declared in ## Suppressions" ;;
        esac
        continue
      fi
      sup_refused=1
      sup_more=""
      [ -n "$sup_state" ] && sup_more=" The ## Suppressions line naming '$f' is missing $sup_state."
      problem "story $sid: commit $c7 ($ph_at) added a suppression to '$f' line $sup_n [$sup_rid]: $sup_text. GREEN and GATES may not silence a tool to reach green; if this one is needed, declare it in ## Suppressions - one line carrying the path, the rule id and 'approved by <who>', with the reason - and say why in that line.$sup_more"
    done <<< "$sup_hits"
  done
done
# Only over commits it actually judged, and only when it refused nothing: an ok
# over zero commits is the vacuous pass, and an ok beside a FAIL is two answers.
if [ "$sup_judged" -gt 0 ] && [ "$sup_refused" -eq 0 ]; then
  ok "GREEN/GATES added no suppression ($sup_judged commit(s) judged)"
fi

exit $fail
