# agentic-dev-harness

A template repository for building software with Claude Code, where the
test-first discipline is enforced by the tooling rather than requested in a
prompt.

Four agents do the work. A product owner interviews you and turns the answers
into a backlog; a test developer writes failing tests from each story; a feature
developer makes them pass without being able to touch the tests; a designer
records the decisions that make the interface implementable. A fifth, optional,
audits whether the tests mean anything.

The harness itself depends on nothing but **git and bash**. The projects it
builds can use any stack.

---

## Requirements

For the harness itself, on any platform:

- **git**
- **bash** — already present on macOS and Linux; on Windows it comes with Git
  for Windows, which Claude Code requires anyway
- **Claude Code**

That is the whole list. No Python, no Node, no package manager. The harness is
plain shell so that it works on a machine that has nothing installed yet.

Your *project* will need a toolchain — a language runtime, a test runner, a
linter. Which one depends on the stack `/plan-product` chooses, so it is not
installed up front. `/setup-environment` works out what is needed, writes it
down in `docs/wiki/environment.md`, and `bash scripts/doctor.sh` verifies it.

## Starting a new project

The same seven steps every time. Nothing here is improvised, and you should not
have to ask how to set a project up.

**1. Get a copy that is its own repository.** Every project must be a separate
repo, so that project work never lands back on the harness.

*Preferred, on GitHub:* mark this repository as a template (Settings, General,
"Template repository"), then use **Use this template, Create a new repository**.
The new repo starts with no shared history and no fork relationship, so there is
no remote pointing back here to push to by accident.

*Without GitHub:*

```bash
git clone https://github.com/<you>/agentic-dev-harness my-project && cd my-project
rm -rf .git && git init && git add -A && git commit -m "harness baseline"
git remote add origin <your new empty repo>
```

Either way, check `git remote -v` before your first push. If it still says
`agentic-dev-harness`, stop and fix it.

Improvements you make to the harness while working on a project do not flow back
automatically. When you find one worth keeping, copy the file into this
repository deliberately.

**2. Check the machine.** `bash scripts/doctor.sh` — at this point it should
report the harness is fine and there is no toolchain configured yet. That is the
expected state before a stack is chosen.

**3. `/create-product`.** An interview. Answer honestly, including "I don't
know" — the Lead PO will push back rather than invent. Produces
`docs/wiki/product-brief.md`. Read it before continuing; everything downstream
inherits its assumptions.

**4. `/plan-product`.** Produces the stack, the architecture, the design
decisions, the epics and the stories — including a `bootstrap` story that will
turn this empty repo into the chosen stack's real layout. Read `stack.md` and
push back now if a choice looks wrong; it is cheap here and expensive later.

**5. `/setup-environment`.** Works out what the chosen stack needs installed,
writes `docs/wiki/environment.md`, and gives you the install commands. It will
not install anything without asking — that changes your machine, not the repo.
Run the commands it gives you, then let it re-verify.

**6. `bash scripts/doctor.sh`.** Must be clean before you continue. Every gate
command's executable has to be on PATH; a bootstrap story built on a missing
tool fails in a confusing way.

**7. `/complete-story <bootstrap-id>`.** Scaffolds the project and fills in
`.claude/harness/project.conf`. After it merges, `bash scripts/gates.sh` should
pass on a real, empty project — and from then on the loop is just
`/complete-story <next-id>`, over and over.

`/status` at any point shows the board, the active story and the last gate
result.

---

## The loop

```
  You                          Agents                        Artefacts

  /create-product   ────────►  Lead PO                ────►  docs/wiki/product-brief.md
  (interview)

  /plan-product     ────────►  Lead PO + Designer     ────►  docs/wiki/{stack,architecture}.md
                                                             docs/wiki/design/**
                                                             docs/backlog/{epics,stories}/**

  /advance-story ID ────────►  Lead PO orchestrates:
  /complete-story ID           ├─ Test Developer      ────►  failing tests            (RED)
                               ├─ Feature Developer   ────►  production code          (GREEN)
                               └─ scripts/gates.sh                                    (GATES)

  Review the PR     ◄────────  branch story/ID-slug + PR
```

A story is one RED→GREEN cycle. `/advance-story` moves it one phase and stops so
you can inspect; `/complete-story` runs the whole cycle and stops only for gate
failures and genuine ambiguity.

---

## Commands

| Command | Does |
|---|---|
| `/create-product` | Interviews you; writes the product brief |
| `/plan-product` | Brief → stack, architecture, design, epics, stories. Idempotent |
| `/setup-environment` | Works out what the stack needs installed, writes `docs/wiki/environment.md` |
| `/plan-story "<description>"` | Adds one story without re-planning the product |
| `/advance-story <id>` | Moves a story forward exactly one phase |
| `/complete-story <id>` | Drives a story to a PR |
| `/audit-mutations [scope]` | Optional: finds tests that would not notice a bug |
| `/status` | Board, active story, last gate result |

## Agents

| Agent | Writes | Never writes |
|---|---|---|
| Lead PO | `docs/wiki/**`, `docs/backlog/**`, `project.conf` | source, tests |
| Test Developer | test files, the story's test plan and handoff | production code |
| Feature Developer | source and config, the story's gate results | test files |
| Lead Designer | `docs/wiki/design/**`, a story's design notes | code |
| Mutation Tester | `docs/wiki/audits/**`, new stories | code, tests |

The commands dispatch these; you do not normally invoke them directly.

---

## The phase lock

The part that makes this more than a prompt.

`.claude/hooks/phase-guard.sh` runs before every write and refuses the ones that
violate the story's current phase:

- **RED** — tests only. Production code is frozen, so the implementation cannot
  be written "while writing the test".
- **GREEN** — source only. Tests are frozen, so a failing test cannot be softened
  into a passing one.
- **GATES** — source only, for fixing lint, types and build.

It covers `Write`, `Edit` and `MultiEdit`, and inspects shell commands too —
redirects, `tee`, `sed -i`, `cp`, `mv` — because an agent that cannot use Edit
will reach for `cat > file`. When no story is active it is off entirely: the lock
protects a cycle in flight, it is not a general permission system.

```bash
bash scripts/phase.sh show                 # what is active, what may be written
bash scripts/phase.sh board                # every story at a glance
bash scripts/phase.sh set PROJ-014 GREEN   # the only supported way to change phase
```

A `Stop` hook refuses to let a story be called finished while the gates have not
been run since the last code change, or while the last run failed. "Done" is
measured, not asserted.

## Gates

Gate *names* are stable across every project; the *commands* are per-stack and
live in one file, `.claude/harness/project.conf`:

```
gate     | unit     | required | . | uv run pytest -q
evidence | unit     | [1-9][0-9]* passed
gate     | coverage | required | . | uv run pytest --cov=src --cov-fail-under=100
evidence | coverage | TOTAL +[0-9]+ +[0-9]+
task     | dev      | -        | . | uv run uvicorn app:api --reload
```

```bash
bash scripts/gates.sh              # all of them
bash scripts/gates.sh --gate unit  # one
bash scripts/gates.sh --audit      # check the manifest, run nothing
bash scripts/task.sh dev           # run the app
```

The `evidence` lines exist because **exit 0 does not mean a gate did anything**.
`cargo test` at a workspace root tests the root package and skips every member;
`mypy` over a target that resolves empty reports "no issues found in 0 source
files"; a linter aimed at a directory that moved checks nothing. All exit 0, and
a harness that treats exit 0 as proof will report `PASS` forever. After a gate
exits 0 its output must match its regex, or it fails with *ran but produced no
evidence of work*. The regex asserts volume of work, never success — success is
the exit code's job. Gates without an `evidence` line behave exactly as before.

Two more things `gates.sh` does that a plain test runner does not. A `waiver`
line names an optional gate that is known to fail and why, so it reports as
`KNOWN` and `WARN` stays reserved for something that changed. And a full run
writes its own summary into the story's `## Gate results`, stamped with the
commit and a hash of the code it ran against; nobody pastes it, and
`check-boundaries.sh` refuses a PR whose recorded run does not match the code
being merged. That script also freezes acceptance criteria once a story leaves
PLANNED (changes need an `## Amendments` entry), requires a filled-in handoff,
and requires a scaffold story to name every source file it wrote. `phase.sh`
refuses to start a story whose `depends_on` are not DONE or from the wrong
branch.

That indirection is what lets the same agents drive a Python service, a
TypeScript app and a Godot game. `.claude/skills/stack-profiles/` holds command
sets for Python, TypeScript, Rust, Godot and static web, plus a template for
writing a profile for anything else. Lines that have not been run on a real
toolchain are marked `# UNVERIFIED`; the bootstrap story's job is to execute
every one of them and correct what has moved.

Coverage defaults to a 100% threshold, set in the gate command where it is
visible. Mutation testing is available but optional — it is the bar above the
bar, not the daily requirement.

## Environments, and why there is no Docker

Two layers, and only one is global.

**The toolchain is global** — `uv`, `node` + `pnpm`, `cargo`, the Godot binary.
Installed once on your machine, shared by every project. `/setup-environment`
walks you through it; `bash scripts/doctor.sh` verifies it.

**The libraries are per-project.** Python gets a real `.venv/`, Node gets
`node_modules/`, Rust resolves per project through `Cargo.lock`, Godot addons
are vendored into the repo. A virtualenv is not a special case — it is the shape
every one of these ecosystems already uses, and the harness relies on it rather
than inventing anything.

Gate commands are written to be environment-aware for that reason: `uv run
pytest`, not `pytest`; `pnpm exec vitest`, not `vitest`. There is no "activate
the venv first" step to forget, and an agent cannot accidentally shell out to
your system interpreter and get a meaningless pass.

`doctor.sh` checks both layers — the executables on PATH, and whether this
project's dependencies are actually installed.

**Docker is deliberately not part of this.** The harness must work on a machine
with nothing installed, containers add nothing to the dev loop for a browser or
CLI project, and bind-mount hot reload through a container is slow and fragile
on Windows. Containerisation is a deployment concern, and deployment is yours.

It remains a per-project choice: a project that genuinely needs Postgres, Redis
and three services should have its bootstrap story write a `docker-compose.yml`
and set `task | dev | - | . | docker compose up`. Nothing else changes, because
every command routes through `project.conf`.

**There is no sandbox.** Agents run on your machine with your permissions. The
above is dependency isolation, not a security boundary — use a dev container or
a VM if you want the real thing.

Full detail: `.claude/skills/stack-profiles/reference/environments.md`.

## CI

- **`gates.yml`** runs the gate manifest on every PR. Add your stack's toolchain
  setup step; the harness itself needs nothing.
- **`boundaries.yml`** re-checks the invariants on the diff, where the hook was
  never in the loop: story frontmatter is valid, runtime state is not committed,
  production code did not arrive without tests, and the story is in a phase that
  justifies a PR.
- **`deploy.yml.template`** is deliberately inert. Agents can write deploy
  configuration; they should not run it. You pull that trigger.

## Layout

```
CLAUDE.md                     standing rules, in context every turn
.claude/
  settings.json               hooks, permissions, status line
  commands/                   the slash commands above
  agents/                     the five agent definitions
  skills/                     shared methodology, loaded on demand
    tdd-cycle/                the RED→GREEN discipline
    story-authoring/          story format and sizing
    quality-gates/            what each gate means, how to triage
    stack-profiles/           per-ecosystem command sets
    design-system/            tokens, states, accessibility floor
  hooks/                      phase guard, state injection, gate reminder
  harness/
    project.conf              how to build and test THIS project
    paths.conf                which paths are test / source / config
    phases.conf               which phase may write which category
    rules.md                  path ownership, imported by CLAUDE.md
  state/                      runtime state, gitignored
docs/
  wiki/                       brief, stack, architecture, design, audits
  backlog/{epics,stories}/    the work
scripts/                      doctor, gates, phase, task, new-story, check-boundaries
```

## Notes on the design

**Methodology lives in skills, not in agent files.** The agents are short — a
role and its boundaries. The TDD discipline, story format and gate catalogue are
skills both the test and feature developers load, so there is one source of truth
and the details load only when needed.

**The story file is the protocol.** Subagents have separate context windows, so
handoffs are genuinely lossy. Anything the next agent needs must be written into
the story file before the phase ends — "as discussed above" does not survive the
boundary. This is a constraint worth designing for rather than around: it keeps
the orchestrator's context clean across a long cycle.

**Nothing is scaffolded until the stack is chosen.** There is no hello-world
app. The first story of any project is a `bootstrap` story that creates the real
layout and fills in `project.conf`. A skeleton in the wrong language is worse
than none.

**The harness never ships.** `.claude/`, `docs/` and `scripts/` are development
tooling. Keep them out of production images.

## Adapting it

- Change what counts as a test or config file: `.claude/harness/paths.conf`
- Change what each phase may write: `.claude/harness/phases.conf`
- Loosen the lock to warnings: change `permissionDecision` in
  `.claude/hooks/phase-guard.sh`
- Add a stack: write a profile in `.claude/skills/stack-profiles/reference/`
- Give the designer real eyes: copy `.mcp.json.example` to `.mcp.json`
  (needs Node)
