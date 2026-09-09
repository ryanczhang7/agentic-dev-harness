# Profile: node-typescript

TypeScript on pnpm. Suits React apps, Node APIs, CLIs, and anything that ships
to a browser through a bundler.

## Gate commands for project.conf

    gate | format    | optional | . | pnpm exec prettier --check .
    gate | lint      | required | . | pnpm exec eslint .
    gate | typecheck | required | . | pnpm exec tsc --noEmit
    gate | unit      | required | . | pnpm exec vitest run
    gate | coverage  | required | . | pnpm exec vitest run --coverage
    gate | integration | optional | . | pnpm exec playwright test
    gate | build     | required | . | pnpm build
    gate | mutation  | optional | . | pnpm exec stryker run

    task | install | - | . | pnpm install --frozen-lockfile
    task | dev     | - | . | pnpm dev
    task | test    | - | . | pnpm exec vitest

Biome can replace both Prettier and ESLint; if you use it, one `lint` gate
covers both and `format` becomes `biome format --check`.

## Evidence of work

See the `evidence` format in `project.conf`; these assert that the tool did
work, not that it succeeded.

    evidence | unit        | Tests +[1-9][0-9]* passed
    evidence | coverage    | Tests +[1-9][0-9]* passed
    evidence | typecheck   | -
    evidence | integration | [1-9][0-9]* passed

    # UNVERIFIED - correct these against your own linter's output.
    evidence | lint        | Checked [1-9][0-9]* files      # biome
    # eslint prints nothing on success; use `--format unix` and count, or `-`.

Verified against vitest 5 and typescript 5 on Windows. Vitest prints
`Tests  2 passed (2)` with ANSI colour and, on Windows, CRLF; `gates.sh` strips
both before matching, so write the regex against the plain text.

`typecheck` is `-` because `tsc` prints nothing on success and there is nothing
honest to match. It does not need liveness cover: `tsc --noEmit` over an empty
`include` fails with `TS18003: No inputs were found`, so its vacuous case is
already loud. `vitest run` with no matching test files is likewise non-zero.
**Never add `--passWithNoTests`** - it converts the safe case into the unsafe
one, which is the whole failure this mechanism exists to catch.

The real trap in this stack is per-directory coverage thresholds. A
`vitest.config.ts` carrying `"src/platform/**": { lines: 100 }` for a directory
that does not exist yet is satisfied vacuously and reports nothing. The
`coverage` evidence line above catches an empty run but not that; check globs
against the tree when you add one.

## Layout

    src/                    production code
    src/**/*.test.ts        co-located unit tests, or tests/ if you prefer
    e2e/                    Playwright specs
    package.json            deps, scripts, pinned versions
    pnpm-lock.yaml          committed
    tsconfig.json           strict: true, no exceptions

## paths.conf additions

Defaults cover `*.test.*`, `*.spec.*`, `__tests__/` and the config files. If you
use `e2e/` for Playwright, add `e2e/**` to the `test` section.

## Notes for the bootstrap story

- Set the coverage thresholds in `vitest.config.ts` (`coverage.thresholds`) so
  the coverage gate fails on its own.
- `strict: true` plus `noUncheckedIndexedAccess` in `tsconfig.json`. Turning
  these on later is a project of its own; turning them on now costs nothing.
- For React, add Testing Library and prove one real user interaction in the
  example test - a render assertion alone is the theatre this harness exists to
  prevent.
- Dockerfile: builder runs `pnpm build`, runtime serves the static bundle from
  `nginx:alpine`, or `node:22-slim` for an API.

## Testing notes

Testing Library queries by role and label, not by test id, so the test fails
when the accessible name breaks. `vi.useFakeTimers()` rather than waiting. Mock
at the network boundary with MSW rather than mocking your own modules.

## Prerequisites

Node.js LTS, then pnpm through corepack (which ships with Node, so there is
nothing else to install globally).

    # Windows
    winget install --id OpenJS.NodeJS.LTS
    # macOS
    brew install node
    # Linux: use nvm, or your distro's nodesource package

    corepack enable
    corepack prepare pnpm@latest --activate

Then, inside the project: `pnpm install --frozen-lockfile`.

Verify: `node --version` prints v22.x or later, `pnpm --version` prints a
version.

Optional: `pnpm exec playwright install --with-deps chromium` downloads the
browser the integration gate drives. It is a few hundred megabytes, so only do
it when you actually add end-to-end tests.
