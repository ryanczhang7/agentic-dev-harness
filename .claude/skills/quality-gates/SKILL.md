---
name: quality-gates
description: What each quality gate means in this harness, how to run them, and how to triage a failure without weakening the tests. Use when a story reaches the GATES phase, when a gate fails, or when configuring gates for a new stack.
---

# Quality gates

The gate names are stable across every project; the commands behind them are
per-stack and live in `.claude/harness/project.conf`. Agents talk about "the
coverage gate"; the manifest knows whether that means `pytest --cov`,
`vitest --coverage` or `cargo llvm-cov`.

    bash scripts/gates.sh              # everything
    bash scripts/gates.sh --list       # what is configured
    bash scripts/gates.sh --gate unit  # one gate
    bash scripts/gates.sh --required   # required only

Failures write their output to `.claude/state/gate-logs/<gate>.log`.

## The gates

| Gate | Required | Answers |
|---|---|---|
| `format` | optional | Is the code formatted to the project standard? |
| `lint` | required | Does it violate the project rules? |
| `typecheck` | required | Do the types hold? |
| `unit` | required | Does the behaviour hold in isolation? |
| `coverage` | required | Is anything shipped unexercised? |
| `integration` | optional | Do the seams hold against real dependencies? |
| `build` | required | Does a production artefact come out? |
| `mutation` | optional | Would the tests notice if the code were wrong? |

A gate marked required with no command configured is a warning before the
bootstrap story lands (`BOOTSTRAPPED=no`) and a hard failure after it. That is
deliberate: an unconfigured gate must never silently look like a passing one.

## Rules for triage

1. Read the actual output before forming a theory. It is in the log file.
2. Fix the cause, not the symptom. A type error that disappears when you widen
   a type to `any` has not been fixed.
3. Never reach green by weakening a test, loosening a lint rule, lowering the
   coverage threshold, or adding a suppression comment - unless the user agrees
   the rule itself is wrong, and it is recorded in the story.
4. If a gate failure means a **test** is wrong, the story returns to RED. Say so
   and record why.

`reference/triage.md` has the per-gate playbook, including what a coverage
failure actually tells you and when a suppression is legitimate.
`reference/configuring.md` covers wiring gates for a new stack.
