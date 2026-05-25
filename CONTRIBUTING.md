# Contributing to gdo

Thank you for considering a contribution to `gdo`.

## Before You Start

Please open an issue before starting substantial work so the direction can be discussed early. This is especially important for API design, driver abstractions, and public documentation changes.

## Scope

The current project focus is narrow on purpose:

- keep the main package under `./gdo`
- prioritize SQLite support
- preserve idiomatic Gleam design
- prefer explicit types and `Result`-based error handling
- avoid introducing multi-database complexity before the SQLite foundation is solid

## Development Setup

From the `gdo` directory:

```sh
gleam test
```

## Contribution Guidelines

- keep all project-facing documentation in English
- keep public APIs small and coherent
- prefer incremental pull requests over broad rewrites
- update tests and examples when behavior changes
- avoid speculative abstractions that are not yet needed by the current implementation

## Pull Requests

Please make sure your pull request:

- targets the `develop` branch
- explains the problem being solved
- describes the approach taken
- includes tests where appropriate
- keeps documentation aligned with the code

## Review Expectations

Changes may be asked to evolve if they introduce:

- API surface that is too early to stabilize
- architecture that is tightly coupled to one runtime in a way that blocks future portability
- features outside the current SQLite-first scope

## Code of Conduct

By participating in this project, you agree to follow the standards described in [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md).
