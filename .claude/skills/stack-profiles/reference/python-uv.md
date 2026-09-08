# Profile: python-uv

Python 3.12+ managed by `uv`. Suits services, CLIs, data and ML work.

## Gate commands for project.conf

    gate | format    | optional | . | uv run ruff format --check .
    gate | lint      | required | . | uv run ruff check .
    gate | typecheck | required | . | uv run mypy src
    gate | unit      | required | . | uv run pytest -q
    gate | coverage  | required | . | uv run pytest --cov=src --cov-report=term-missing --cov-fail-under=100
    gate | build     | required | . | uv build
    gate | mutation  | optional | . | uv run mutmut run

    task | install | - | . | uv sync --all-extras
    task | dev     | - | . | uv run <entry point>
    task | test    | - | . | uv run pytest -q

Use `pyright` instead of `mypy` where the project leans on modern typing;
`ruff format` replaces `black`.

## Layout

    src/<package>/          production code
    tests/                  mirrors src/, test_*.py
    pyproject.toml          deps, tool config, pinned versions
    uv.lock                 committed

## paths.conf additions

Defaults already cover `tests/**`, `test_*.py` and `conftest.py`. Add nothing
unless you put tests beside the code, in which case add `src/**/test_*.py` to
the `test` section.

## Notes for the bootstrap story

- `uv init`, then pin every dependency in `pyproject.toml`; commit `uv.lock`.
- Configure `ruff`, `mypy` and `pytest` in `pyproject.toml`, not in scattered
  dotfiles - one place the next agent will find.
- Set `--cov-fail-under` in the gate command rather than in config, so the
  threshold is visible where it is enforced.
- For a service, add `httpx` and `pytest-asyncio` and prove one real request in
  the example test rather than a `test_imports` placeholder.
- Dockerfile: builder stage runs `uv sync --frozen --no-dev`, runtime stage is
  `python:3.12-slim` with only `src/` and the virtualenv.

## Testing notes

`pytest` fixtures over setup methods. `pytest.mark.parametrize` for the
zero/one/many and boundary cases. `hypothesis` where an invariant is easier to
state than the examples that check it. `freezegun` or an injected clock rather
than sleeping.

## Prerequisites

`uv` is the only thing you install globally; it manages Python itself.

    # Windows
    winget install --id astral-sh.uv
    # macOS / Linux
    curl -LsSf https://astral.sh/uv/install.sh | sh

Then, inside the project:

    uv python install 3.12
    uv sync --all-extras

Verify: `uv --version`, then `uv run python --version` prints 3.12.x.

**Windows note.** If `python` opens the Microsoft Store, that is the App
Execution Alias stub, not an interpreter. Ignore it - `uv run` does not use it.
Turn the aliases off under Settings, Apps, Advanced app settings, App execution
aliases if it gets in the way.

Optional: `uv tool install mutmut` for the mutation gate.
