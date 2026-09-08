---
description: Move one story forward by exactly one phase
argument-hint: <story-id>
allowed-tools: Bash(bash scripts/phase.sh:*), Bash(bash scripts/gates.sh:*), Bash(git:*), Read, Grep, Glob, Edit, Write, Task
---

Story: $1

Current harness state:
!`bash scripts/phase.sh show`

Act as the **lead-po** orchestrator and advance this story by **one phase only**,
then stop and report. The user chose this command over `/complete-story`
because they want to inspect the result before the next phase runs.

Read `docs/backlog/stories/$1.md` first. Then, based on its current phase:

**PLANNED → RED.** Confirm the acceptance criteria are testable; fix them with
the user if they are not. Create and switch to the story's branch
(`story/<id>-<slug>`) if it does not exist. Set the phase, then dispatch the
**test-developer** subagent with the story path, the criteria restated in full,
the relevant constraints from `docs/wiki/`, and the exact test command from
`.claude/harness/project.conf`. When it returns, verify: read the test files it
wrote and run the tests yourself. Confirm they fail, and fail for the right
reason. If they pass, or fail on an unrelated error, send it back.

**RED → GREEN.** Check the `## Handoff: RED -> GREEN` section is filled in; if
it is not, the RED phase is not finished. Set the phase, then dispatch the
**feature-developer** subagent with the story path, the handoff, and the test
command. When it returns, run the tests yourself.

**GREEN → GATES.** Set the phase and run `bash scripts/gates.sh`. On failure,
dispatch the **feature-developer** to fix it, unless the failure means a test is
wrong — in which case move the story back to RED, record why in the story file,
and tell the user.

**GATES → REVIEW.** Only when every required gate passes. Commit with a message
that names the story and what it does, push the branch, and open a PR whose body
links the story file and lists the acceptance criteria with the test that covers
each. Set the phase to REVIEW.

**REVIEW → DONE.** Only once the PR is merged. Set the phase to DONE, clear the
lock with `bash scripts/phase.sh clear`, and report what the next story is.

Rules for you as orchestrator:

- Change phase only with `bash scripts/phase.sh set $1 <PHASE>`.
- Verify every subagent claim against the filesystem and a real command run. A
  report of success is a claim.
- Keep the story file current as you go — it is the only thing the next agent
  will see.
- Stop and ask the user on any product ambiguity. Do not invent scope.

Finish by reporting: the phase you moved from and to, what changed, the real
command output that justifies it, and the exact command to run next.
