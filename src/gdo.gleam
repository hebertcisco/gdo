//// Public entrypoint for the `gdo` package.

import gdo/connection
import gdo/decode
import gdo/error.{type Error}
import gdo/result
import gdo/row
import gdo/statement
import gdo/value.{type Param}
import gleam/option.{type Option}

pub const package_name = "gdo"

pub const version = "0.1.0"

pub fn sqlite(database: String) -> connection.ConnectionConfig {
  connection.sqlite(database)
}

pub fn sqlite_config(database: String) -> connection.ConnectionConfig {
  connection.sqlite_config(database)
}

pub fn mysql(
  host: String,
  port: Int,
  database: String,
  username: String,
  password: String,
) -> connection.ConnectionConfig {
  connection.mysql(host, port, database, username, password)
}

pub fn mysql_config(
  host: String,
  port: Int,
  database: String,
  username: String,
  password: String,
) -> connection.ConnectionConfig {
  connection.mysql_config(host, port, database, username, password)
}

pub fn open_sqlite(database: String) -> Result(connection.Connection, Error) {
  database
  |> connection.sqlite
  |> connection.open
}

pub fn open_mysql(
  host: String,
  port: Int,
  database: String,
  username: String,
  password: String,
) -> Result(connection.Connection, Error) {
  mysql(host, port, database, username, password)
  |> connection.open
}

pub fn prepare(sql: String) -> Result(statement.Statement, Error) {
  statement.prepare(sql)
}

pub fn exec_sqlite(
  database: String,
  sql: String,
  params: List(Param),
) -> Result(result.ExecutionResult, Error) {
  case open_sqlite(database) {
    Ok(connection) -> connection.exec(connection, sql, params)
    Error(error) -> Error(error)
  }
}

pub fn query_one_sqlite(
  database: String,
  sql: String,
  params: List(Param),
) -> Result(Option(row.Row), Error) {
  case open_sqlite(database) {
    Ok(connection) -> connection.query_one(connection, sql, params)
    Error(error) -> Error(error)
  }
}

pub fn query_all_sqlite(
  database: String,
  sql: String,
  params: List(Param),
) -> Result(result.QueryResult, Error) {
  case open_sqlite(database) {
    Ok(connection) -> connection.query_all(connection, sql, params)
    Error(error) -> Error(error)
  }
}

pub fn query_one_sqlite_as(
  database: String,
  sql: String,
  params: List(Param),
  using decoder: decode.Decoder(a),
) -> Result(Option(a), Error) {
  case open_sqlite(database) {
    Ok(connection) ->
      connection.query_one_as(connection, sql, params, using: decoder)
    Error(error) -> Error(error)
  }
}

pub fn query_all_sqlite_as(
  database: String,
  sql: String,
  params: List(Param),
  using decoder: decode.Decoder(a),
) -> Result(List(a), Error) {
  case open_sqlite(database) {
    Ok(connection) ->
      connection.query_all_as(connection, sql, params, using: decoder)
    Error(error) -> Error(error)
  }
}

pub fn exec_mysql(
  host: String,
  port: Int,
  database: String,
  username: String,
  password: String,
  sql: String,
  params: List(Param),
) -> Result(result.ExecutionResult, Error) {
  case open_mysql(host, port, database, username, password) {
    Ok(connection) -> connection.exec(connection, sql, params)
    Error(error) -> Error(error)
  }
}

pub fn query_one_mysql(
  host: String,
  port: Int,
  database: String,
  username: String,
  password: String,
  sql: String,
  params: List(Param),
) -> Result(Option(row.Row), Error) {
  case open_mysql(host, port, database, username, password) {
    Ok(connection) -> connection.query_one(connection, sql, params)
    Error(error) -> Error(error)
  }
}

pub fn query_all_mysql(
  host: String,
  port: Int,
  database: String,
  username: String,
  password: String,
  sql: String,
  params: List(Param),
) -> Result(result.QueryResult, Error) {
  case open_mysql(host, port, database, username, password) {
    Ok(connection) -> connection.query_all(connection, sql, params)
    Error(error) -> Error(error)
  }
}

pub fn query_one_mysql_as(
  host: String,
  port: Int,
  database: String,
  username: String,
  password: String,
  sql: String,
  params: List(Param),
  using decoder: decode.Decoder(a),
) -> Result(Option(a), Error) {
  case open_mysql(host, port, database, username, password) {
    Ok(connection) ->
      connection.query_one_as(connection, sql, params, using: decoder)
    Error(error) -> Error(error)
  }
}

pub fn query_all_mysql_as(
  host: String,
  port: Int,
  database: String,
  username: String,
  password: String,
  sql: String,
  params: List(Param),
  using decoder: decode.Decoder(a),
) -> Result(List(a), Error) {
  case open_mysql(host, port, database, username, password) {
    Ok(connection) ->
      connection.query_all_as(connection, sql, params, using: decoder)
    Error(error) -> Error(error)
  }
}
