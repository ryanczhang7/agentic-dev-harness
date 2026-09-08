# Profile: web-static

Browser projects with little or no build step: canvas and WebGL toys, tools,
prototypes, documentation sites. Chosen when the brief values "open the file and
it runs" over framework leverage.

## Gate commands for project.conf

    gate | format    | optional | . | pnpm exec biome format --check .
    gate | lint      | required | . | pnpm exec biome lint .
    gate | typecheck | required | . | pnpm exec tsc --noEmit --allowJs --checkJs
    gate | unit      | required | . | pnpm exec vitest run --environment jsdom
    gate | coverage  | required | . | pnpm exec vitest run --coverage
    gate | integration | optional | . | pnpm exec playwright test
    gate | build     | required | . | pnpm exec vite build

    task | dev  | - | . | pnpm exec vite
    task | test | - | . | pnpm exec vitest

Even a no-build project benefits from `tsc --checkJs` over JSDoc types: it is
the cheapest type checking that exists, and it needs no compile step.

## Layout

    index.html
    src/                    ES modules, imported directly in dev
    src/**/*.test.js        unit tests
    e2e/                    Playwright specs
    public/                 static assets

## Notes for the bootstrap story

- Keep the module graph importable by both the browser and the test runner:
  real ES modules, no bundler-only syntax in `src/`.
- Canvas and WebGL logic is testable if you separate it: the function that
  decides *what* to draw is pure and unit-testable; the function that calls the
  drawing API is thin and covered by one integration test.
- For anything with rendering output worth pinning, add Playwright screenshot
  comparison as the `integration` gate and commit the baselines.

## Testing notes

Prefer `jsdom` for DOM logic and a real browser through Playwright for anything
involving layout, canvas or input. Do not assert on pixel colours in jsdom - it
does not paint, and a test that passes there proves nothing about the screen.

## Prerequisites

Same as the `node-typescript` profile: Node.js LTS plus pnpm via corepack. See
that profile's Prerequisites section.

Even for a project with no build step, the toolchain is needed for the gates -
the test runner, the type checker and the linter all run on Node.
