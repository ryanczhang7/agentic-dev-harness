# Configuring gates for a project

`.claude/harness/project.conf` is the only place the harness learns how to build
and test this project. Format, one entry per line:

    <kind> | <id> | <required|optional> | <cwd> | <command>

`kind` is `gate` or `task`. `cwd` is relative to the repository root. An empty
command marks the gate unconfigured.

## Rules

- **Pin the runner, not the shell alias.** `pnpm exec vitest run` rather than
  `npm test`, so the gate does not change meaning when someone edits a script.
- **Make it non-interactive and non-watching.** Gates run in CI. A watcher hangs
  the pipeline.
- **Put the threshold in the command.** The coverage gate should fail on its
  own: `--cov-fail-under=100`, `--coverage.thresholds.100`, and so on. Do not
  rely on a human reading the number.
- **One command per gate.** If you need two, they are two gates.
- **Keep `cwd` honest** for monorepos - one gate per workspace is clearer than
  one command that loops.

## Multiple workspaces

For a project with a backend and a frontend, prefer distinct ids:

    gate | unit-api | required | backend  | uv run pytest
    gate | unit-web | required | frontend | pnpm exec vitest run

The stable name is the id, so stories and agents can refer to "the unit-web
gate" without knowing the command.

## Tasks

`task` entries are for commands humans and agents run outside the gates:
`install`, `dev`, `test`, and anything else worth not re-deriving. Anything an
agent would otherwise have to remember belongs here - the next agent starts with
an empty context and will trust this file.

## Flipping the flag

`BOOTSTRAPPED=no` at the top makes unconfigured required gates warnings rather
than failures, so the very first story can run before the stack exists. The
bootstrap story sets it to `yes`. Never set it back.
