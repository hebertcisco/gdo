import gdo/connection
import gdo/error.{type Error}
import gdo/statement

//// Public entrypoint for the `gdo` package.

pub const package_name = "gdo"
pub const version = "0.1.0"

pub fn sqlite(database: String) -> connection.ConnectionConfig {
  connection.sqlite(database)
}

pub fn open_sqlite(
  database: String,
) -> Result(connection.Connection, Error) {
  database
  |> connection.sqlite
  |> connection.open
}

pub fn prepare(sql: String) -> Result(statement.Statement, Error) {
  statement.prepare(sql)
}
