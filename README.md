# gdo

`gdo` is a database access library for Gleam with a typed, functional API.

It provides a small and consistent interface for:

- opening database connections
- preparing and executing statements
- running explicit transactions
- handling database failures with structured errors

## Features

- idiomatic Gleam API design
- explicit types and `Result`-based error handling
- prepared statements
- transaction support
- structured database errors
- a modular architecture for driver implementations

## Installation

```sh
gleam add gdo
```

## Usage

`gdo` is organized around a small set of core modules for connections, statements, rows, values, errors, and transactions.

```gleam
import gdo

pub fn main() {
  let _package = gdo.package_name
  Nil
}
```

## Project Layout

The package is organized around the core concepts of the library:

```text
src/
  gdo.gleam
  gdo/
    connection.gleam
    driver.gleam
    error.gleam
    row.gleam
    statement.gleam
    transaction.gleam
    value.gleam
    driver/
      sqlite.gleam
```

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](./CONTRIBUTING.md), [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md), and [SECURITY.md](./SECURITY.md) before opening a pull request.

## License

This project is licensed under the Apache License 2.0. See [LICENSE](./LICENSE).

## Development

From the `gdo` directory:

```sh
gleam test
```
