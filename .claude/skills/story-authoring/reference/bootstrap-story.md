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
- **AC-8** - `bash scripts/gates.sh --audit` passes: every required gate has a
  command, an existing `cwd`, and an `evidence` line.
- **AC-9** - Each required gate has been observed to fail. Moving the test
  directory aside makes the `unit` gate fail; putting it back makes it pass.

## What it must deliver

- the directory layout the stack expects, with a real entry point
- dependency manifests with pinned versions matching `docs/wiki/stack.md`
- the test runner configured, with one example test that genuinely runs
- linter, formatter and type checker configured
- a `.gitignore` for the ecosystem, and `.dockerignore` if containerised - both
  excluding `.claude/`, `docs/` and `scripts/` from production images
- `project.conf` filled in, with an `evidence` line per gate, and
  `BOOTSTRAPPED=yes`
- a `## Gate probes` section recording each gate observed failing

## Verifying it

Do not accept the story on the strength of the files existing. Run every gate
and the dev task yourself. A bootstrap story that lands with a wrong test
command poisons every story after it, because the next agent will trust
`project.conf` without re-deriving it.

**Do not trust a gate that passed.** The gate commands arrive from
`docs/wiki/stack.md`, which is researched and unexecuted by construction; this
story is where they are executed for the first time. A gate that passes quickly
and quietly is the thing to be suspicious of, because a command that does no
work exits 0 too. `cargo test` at a workspace root, `mypy` over a target that
resolves empty and a linter aimed at a moved directory all pass while testing
nothing.

So for each required gate, run it, then break what it guards and run it again:

    bash scripts/gates.sh --gate unit     # passes
    mv tests tests.probe && bash scripts/gates.sh --gate unit   # must fail
    mv tests.probe tests

Paste both outputs into `## Gate probes`. That is what turns sixteen researched
command lines into sixteen gates, and it is the only work in this story that
cannot be redone cheaply later.
