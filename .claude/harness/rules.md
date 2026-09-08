# Path ownership

Each agent owns a slice of the tree. The phase lock enforces the *phase*
dimension of this automatically; the *role* dimension is honoured by the agents
themselves and checked in CI by `scripts/check-boundaries.sh`.

| Agent | Writes | Never writes |
|---|---|---|
| **Lead PO** | `docs/wiki/**`, `docs/backlog/**`, `.claude/harness/project.conf` | any source or test file |
| **Test Developer** | test paths (see `paths.conf`), the story's `## Test plan` and `## Handoff` | production source, config |
| **Feature Developer** | source and config paths, the story's `## Gate results` | any test file |
| **Lead Designer** | `docs/wiki/design/**`, the story's `## Design notes` | source, tests, config |
| **Mutation Tester** | `docs/wiki/audits/**`, new story files | source, tests, config |

Categories are decided by `.claude/harness/paths.conf`, not by intuition. To see
how a path is classified:

```bash
bash -c '. .claude/hooks/lib.sh; classify "src/app/main.ts"'
```

# Phase permissions

| Phase | May write | Meaning |
|---|---|---|
| any | vendor | installed deps and build output are always writable |
| `PLANNED` | docs, harness | story is being written |
| `RED` | tests, docs, harness | failing tests only; source frozen |
| `GREEN` | source, config, docs, harness | make them pass; tests frozen |
| `GATES` | source, config, docs, harness | fix lint/type/build; tests frozen |
| `REVIEW` | docs, harness | PR is open |
| `SCAFFOLD` | everything | bootstrap/chore stories only |
| `DONE` | docs, harness | closed |

No active story means no restrictions. The lock protects a cycle in flight; it
is not a general permission system.

# Non-negotiables

- A test that has never been observed to fail is not a test. Run it in RED and
  record the failure output in the story's `## Handoff`.
- Do not weaken an assertion, add a `skip`, widen a tolerance, or delete a case
  to reach green. Any of these means going back to RED.
- Do not commit `.claude/state/**`. It is machine-local.
- Agentic scaffolding (`.claude/`, `docs/`, `scripts/`, `.github/`) never ships
  in a production image. Keep `.dockerignore` honest.
