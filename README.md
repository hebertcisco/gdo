# gdo

[![test](https://github.com/hebertcisco/gdo/actions/workflows/test.yml/badge.svg)](https://github.com/hebertcisco/gdo/actions/workflows/test.yml)

`gdo` is a typed database access library for Gleam.

It provides a small, functional API for:

- opening SQLite connections
- executing prepared statements
- reading rows through typed decoders
- running explicit transactions
- handling failures through structured errors

## Features

- idiomatic Gleam API
- `Result`-based error handling
- positional and named parameters
- prepared statement workflow
- explicit transaction control
- typed row decoding helpers
- structured connection, query, transaction, and decode errors

## Installation

```sh
gleam add gdo
```

## Quick Start

```gleam
import gdo
import gdo/connection
import gdo/decode
import gdo/error.{type Error}
import gdo/result
import gdo/value.{Int, Positional, String}
import gleam/option.{None, Some}

pub fn main() -> Result(Nil, Error) {
  use db <- result.try(gdo.open_sqlite("file:app.sqlite"))

  use _ <- result.try(
    connection.exec(
      db,
      "create table if not exists users (id integer primary key, name text not null)",
      [],
    ),
  )

  use insert_result <- result.try(
    connection.exec(db, "insert into users (id, name) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("Ana")),
    ]),
  )

  let last_id = result.last_insert_id(insert_result)
  let _ = last_id

  use maybe_row <- result.try(
    connection.query_one(db, "select id, name from users where id = ?", [
      Positional(Int(1)),
    ]),
  )

  case maybe_row {
    Some(current_row) -> {
      let decoder =
        decode.map2(
          decode.column_at(0, using: decode.int()),
          decode.column_at(1, using: decode.string()),
          with: fn(id, name) { #(id, name) },
        )

      let assert Ok(#(id, name)) = decode.decode(current_row, using: decoder)
      let _ = #(id, name)
      connection.close(db)
    }

    None -> connection.close(db)
  }
}
```

## Connection Workflow

Use `gdo.open_sqlite` for the common path, or `connection.open` with
`connection.sqlite` when you want to build the configuration explicitly.

```gleam
import gdo
import gdo/connection

pub fn open_database() {
  let assert Ok(db) = gdo.open_sqlite("file:app.sqlite")
  assert connection.in_transaction(db) == False
}
```

For one-shot calls there are root helpers:

- `gdo.exec_sqlite`
- `gdo.query_one_sqlite`
- `gdo.query_all_sqlite`

These helpers open a SQLite connection for the operation and return the typed
result directly.

## Statement Workflow

Prepare statements when you want to reuse SQL, validate placeholder style once,
or keep execution and reading separate.

```gleam
import gdo
import gdo/connection
import gdo/statement
import gdo/value.{Named, String}

pub fn find_user_by_email() {
  let assert Ok(db) = gdo.open_sqlite("file:app.sqlite")
  let assert Ok(stmt) =
    connection.prepare(db, "select id, email from users where email = :email")

  let assert Ok(Some(current_row)) =
    statement.query_one(stmt, [Named("email", String("ana@example.com"))])

  let _ = current_row
}
```

`gdo` supports:

- positional placeholders: `?`
- named placeholders: `:name`

Mixing placeholder styles in the same statement is rejected during preparation.

## Transaction Workflow

Transactions are explicit and keep the connection immutable from the caller's
point of view.

```gleam
import gdo
import gdo/connection
import gdo/value.{Int, Positional, String}

pub fn create_user() {
  let assert Ok(db) = gdo.open_sqlite("file:app.sqlite")
  let assert Ok(db) = connection.begin(db)

  let assert Ok(_) =
    connection.exec(db, "insert into users (id, name) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("Ana")),
    ])

  let assert Ok(db) = connection.commit(db)
  let _ = db
}
```

Use `connection.rollback` when the unit of work should be discarded.

## Row Decoding

Rows can be inspected directly with `row.get` and `row.get_at`, or decoded into
application values with `gdo/decode`.

```gleam
import gdo/decode

pub fn user_decoder() {
  decode.map2(
    decode.column_at(0, using: decode.int()),
    decode.column_at(1, using: decode.string()),
    with: fn(id, name) { User(id:, name:) },
  )
}

pub type User {
  User(id: Int, name: String)
}
```

Available decoders include:

- `decode.int`
- `decode.float`
- `decode.bool`
- `decode.string`
- `decode.bytes`
- `decode.nullable`
- `decode.map`
- `decode.map2`
- `decode.map3`

## Error Model

`gdo` keeps failures inside the public `Error` type:

- `ConnectionError`
- `QueryError`
- `TransactionError`
- `DecodeError`
- `UnsupportedFeature`
- `InvalidConfiguration`

Helpers in `gdo/error` expose the common fields:

- `error.message`
- `error.code`
- `error.sqlstate`

Typical handling looks like this:

```gleam
import gdo
import gdo/error

pub fn run_query() {
  case gdo.open_sqlite("file:app.sqlite") {
    Ok(_) -> Nil
    Error(err) -> {
      let _message = error.message(err)
      let _code = error.code(err)
      let _sqlstate = error.sqlstate(err)
      Nil
    }
  }
}
```

## SQLite Notes

Current SQLite support includes:

- real connection open and close
- prepared statement execution
- reads through `query_one` and `query_all`
- transaction operations
- `last_insert_id`
- driver error mapping into `gdo/error`

Current SQLite limitation:

- result rows are most reliable through positional access and
  `decode.column_at`. The current SQLite path does not yet expose real column
  names from backend metadata, so rows returned from queries use synthetic
  column names internally.

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](./CONTRIBUTING.md),
[CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md), and [SECURITY.md](./SECURITY.md)
before opening a pull request.

## License

This project is licensed under the Apache License 2.0. See [LICENSE](./LICENSE).

## Development

From the `gdo` directory:

```sh
gleam test
gleam format --check src test
```
