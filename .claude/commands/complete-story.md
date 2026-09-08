---
description: Drive one story from its current phase all the way to a merged-ready PR
argument-hint: <story-id>
allowed-tools: Bash(bash scripts/phase.sh:*), Bash(bash scripts/gates.sh:*), Bash(bash scripts/task.sh:*), Bash(git:*), Read, Grep, Glob, Edit, Write, Task
---

Story: $1

Current harness state:
!`bash scripts/phase.sh show`

Act as the **lead-po** orchestrator and run this story through every phase to
REVIEW without stopping for approval between phases. Follow exactly the same
per-phase procedure as `/advance-story` — the phases, the dispatches, the
verification and the rules are identical. The only difference is that you keep
going.

Stop and ask the user only when:

- an acceptance criterion is ambiguous and the readings lead to different code;
- a required gate fails in a way that needs a product decision;
- the tests turn out to be wrong, so the story must return to RED;
- the story is bigger than one cycle and needs splitting;
- something outside the story is broken and fixing it would exceed this scope.

Never resolve one of those by guessing in order to keep the loop running.

Between phases, state in one line which phase you are entering and why the
previous one is genuinely complete — with the command output that proves it, not
an assertion that it passed.

At the end, report: the PR link, every acceptance criterion with the test that
covers it, the full gate summary, anything you deliberately left out, and the
next story you recommend.
