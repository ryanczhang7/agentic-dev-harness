# The bootstrap story

Every project's first story. It turns an empty repository into the chosen
stack's real layout, and it is the only story that legitimately writes source
without tests first - which is why it uses the SCAFFOLD phase.

## Acceptance criteria for a bootstrap story

Phrase them as things that must be true of the repository, each verifiable by
running a command:

- **AC-1** - `bash scripts/gates.sh --gate lint` runs the project linter and
  passes on the scaffolded code.
- **AC-2** - `bash scripts/gates.sh --gate unit` runs the test runner, which
  discovers and passes one real example test.
- **AC-3** - `bash scripts/gates.sh --gate coverage` reports coverage and fails
  below the configured threshold.
- **AC-4** - `bash scripts/gates.sh --gate build` produces a runnable artefact.
- **AC-5** - `bash scripts/task.sh dev` starts the application locally.
- **AC-6** - `.claude/harness/project.conf` has a command for every required
  gate, and `BOOTSTRAPPED=yes`.
- **AC-7** - `.claude/harness/paths.conf` classifies this stack's test files as
  `test` and its build configuration as `config`.

## What it must deliver

- the directory layout the stack expects, with a real entry point
- dependency manifests with pinned versions matching `docs/wiki/stack.md`
- the test runner configured, with one example test that genuinely runs
- linter, formatter and type checker configured
- a `.gitignore` for the ecosystem, and `.dockerignore` if containerised - both
  excluding `.claude/`, `docs/` and `scripts/` from production images
- `project.conf` filled in and `BOOTSTRAPPED=yes`

## Verifying it

Do not accept the story on the strength of the files existing. Run every gate
and the dev task yourself. A bootstrap story that lands with a wrong test
command poisons every story after it, because the next agent will trust
`project.conf` without re-deriving it.
