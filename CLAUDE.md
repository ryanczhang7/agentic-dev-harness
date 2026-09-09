# Agentic development harness

This repository builds software through a fixed loop driven by specialist
agents. Read this file as the standing rules of the house; it is in context on
every turn, so it stays short.

@.claude/harness/rules.md

## The loop

```
/create-product    → Lead PO interviews the user           → docs/wiki/product-brief.md
/plan-product      → Lead PO + Lead Designer plan          → docs/wiki/{stack,architecture}.md
                                                             docs/backlog/{epics,stories}/*.md
/setup-environment → install the toolchain the stack needs → docs/wiki/environment.md
/advance-story ID  → one phase of the cycle
/complete-story ID → every phase, to done
/audit-mutations   → Mutation Tester (optional, above the bar)
```

A story moves `PLANNED → RED → GREEN → GATES → REVIEW → DONE`. One story is one
RED→GREEN cycle. If a story cannot be finished in one cycle, it is too big —
split it.

## The law

1. **No production code without a failing test that demanded it.** The test is
   written first, is watched to fail, and fails for the right reason.
2. **Tests are frozen during GREEN.** If a test is wrong, go back to RED and say
   so in the story file. Never edit a test to make it pass.
3. **Done means the gates pass.** `bash scripts/gates.sh` — not "should pass",
   not "passes locally in principle". Run it and paste the result. And a gate
   that has never been observed to fail is not a gate: when a story adds or
   changes one, break the thing it guards, watch it fail, record that in
   `## Gate probes`, and revert. Exit 0 only means the tool did not complain,
   and a tool with nothing to do never complains.
4. **Full coverage of the behaviour the story claims.** Coverage of lines is the
   floor, not the goal; every acceptance criterion has a test that fails when
   that criterion is broken.
5. **Never work around the phase lock.** If the lock blocks a write you believe
   is correct, that is a signal to change phase deliberately or to reconsider —
   never to route around it with a different tool.

## Phase lock

`.claude/hooks/phase-guard.sh` refuses writes that violate the current phase. It
covers `Write`/`Edit`/`MultiEdit`/`NotebookEdit` and shell redirects alike. When
no story is active it is off entirely.

```bash
bash scripts/phase.sh show                 # what is active, what may be written
bash scripts/phase.sh board                # every story at a glance
bash scripts/phase.sh set WORLD-014 GREEN  # the only supported way to change phase
```

## Where things live

| Path | Contents |
|---|---|
| `docs/wiki/` | product brief, stack, architecture, design decisions, audits |
| `docs/backlog/epics/` | epics |
| `docs/backlog/stories/` | stories — the unit of work, and the agent handoff medium |
| `.claude/harness/project.conf` | how to lint/test/build **this** project |
| `.claude/harness/paths.conf` | which paths count as test / source / config |
| `.claude/agents/`, `.claude/commands/`, `.claude/skills/` | the harness itself |

## Running things

Never guess a build command. Every project-specific command lives in
`.claude/harness/project.conf`:

```bash
bash scripts/doctor.sh           # is the toolchain installed?
bash scripts/gates.sh            # all gates
bash scripts/gates.sh --gate unit
bash scripts/task.sh dev         # run the app
```

If a command you need is not in `project.conf`, add it there rather than
memorising it — the next agent has a fresh context and will not know.

## Context discipline

Subagents start with empty context. Anything the next agent needs must be
written into the story file before the current phase ends — especially the
`## Handoff` section. "As discussed above" does not survive the boundary.
