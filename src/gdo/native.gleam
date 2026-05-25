import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}
import sqlight
import gdo/value.{type DbValue}

pub type Connection {
  Connection(inner: Dynamic)
}

pub type SqliteNativeError {
  SqliteNativeError(code: Int, message: String, offset: Int)
}

pub type MySqlNativeError {
  MySqlNativeError(
    code: Option(Int),
    sqlstate: Option(String),
    message: String,
  )
}

pub type MySqlExecutionResult {
  MySqlExecutionResult(rows_affected: Int, last_insert_id: Option(Int))
}

pub type MySqlQueryResult {
  MySqlQueryResult(columns: List(String), rows: List(Dynamic))
}

pub fn sqlite_open(path: String) -> Result(Connection, SqliteNativeError) {
  case sqlite_open_raw(path) {
    Ok(inner) -> Ok(Connection(inner:))
    Error(error) -> Error(error)
  }
}

pub fn sqlite_close(connection: Connection) -> Result(Nil, SqliteNativeError) {
  let Connection(inner:) = connection
  sqlite_close_raw(inner)
}

pub fn sqlite_exec(
  sql: String,
  on connection: Connection,
) -> Result(Nil, SqliteNativeError) {
  let Connection(inner:) = connection
  sqlite_exec_raw(sql, inner)
}

pub fn sqlite_query(
  sql: String,
  on connection: Connection,
  with arguments: List(sqlight.Value),
) -> Result(List(Dynamic), SqliteNativeError) {
  let Connection(inner:) = connection
  sqlite_query_raw(sql, inner, arguments)
}

pub fn mysql_open(
  host: String,
  port: Int,
  database: String,
  username: String,
  password: String,
  tls_mode: String,
  options: List(#(String, String)),
) -> Result(Connection, MySqlNativeError) {
  case mysql_open_raw(host, port, database, username, password, tls_mode, options) {
    Ok(inner) -> Ok(Connection(inner:))
    Error(error) -> Error(error)
  }
}

pub fn mysql_close(connection: Connection) -> Result(Nil, MySqlNativeError) {
  let Connection(inner:) = connection
  mysql_close_raw(inner)
}

pub fn mysql_exec(
  sql: String,
  on connection: Connection,
  with arguments: List(DbValue),
) -> Result(MySqlExecutionResult, MySqlNativeError) {
  let Connection(inner:) = connection
  mysql_exec_raw(sql, inner, arguments)
}

pub fn mysql_query(
  sql: String,
  on connection: Connection,
  with arguments: List(DbValue),
) -> Result(MySqlQueryResult, MySqlNativeError) {
  let Connection(inner:) = connection
  mysql_query_raw(sql, inner, arguments)
}

pub fn mysql_last_insert_id(
  on connection: Connection,
) -> Result(Option(Int), MySqlNativeError) {
  let Connection(inner:) = connection
  mysql_last_insert_id_raw(inner)
}

@external(erlang, "gdo_erl", "sqlite_open")
@external(javascript, "../gdo_js.mjs", "sqliteOpen")
fn sqlite_open_raw(path: String) -> Result(Dynamic, SqliteNativeError)

@external(erlang, "gdo_erl", "sqlite_close")
@external(javascript, "../gdo_js.mjs", "sqliteClose")
fn sqlite_close_raw(connection: Dynamic) -> Result(Nil, SqliteNativeError)

@external(erlang, "gdo_erl", "sqlite_exec")
@external(javascript, "../gdo_js.mjs", "sqliteExec")
fn sqlite_exec_raw(
  sql: String,
  connection: Dynamic,
) -> Result(Nil, SqliteNativeError)

@external(erlang, "gdo_erl", "sqlite_query")
@external(javascript, "../gdo_js.mjs", "sqliteQuery")
fn sqlite_query_raw(
  sql: String,
  connection: Dynamic,
  arguments: List(sqlight.Value),
) -> Result(List(Dynamic), SqliteNativeError)

@external(erlang, "gdo_erl", "mysql_open")
@external(javascript, "../gdo_js.mjs", "mysqlOpen")
fn mysql_open_raw(
  host: String,
  port: Int,
  database: String,
  username: String,
  password: String,
  tls_mode: String,
  options: List(#(String, String)),
) -> Result(Dynamic, MySqlNativeError)

@external(erlang, "gdo_erl", "mysql_close")
@external(javascript, "../gdo_js.mjs", "mysqlClose")
fn mysql_close_raw(connection: Dynamic) -> Result(Nil, MySqlNativeError)

@external(erlang, "gdo_erl", "mysql_exec")
@external(javascript, "../gdo_js.mjs", "mysqlExec")
fn mysql_exec_raw(
  sql: String,
  connection: Dynamic,
  arguments: List(DbValue),
) -> Result(MySqlExecutionResult, MySqlNativeError)

@external(erlang, "gdo_erl", "mysql_query")
@external(javascript, "../gdo_js.mjs", "mysqlQuery")
fn mysql_query_raw(
  sql: String,
  connection: Dynamic,
  arguments: List(DbValue),
) -> Result(MySqlQueryResult, MySqlNativeError)

@external(erlang, "gdo_erl", "mysql_last_insert_id")
@external(javascript, "../gdo_js.mjs", "mysqlLastInsertId")
fn mysql_last_insert_id_raw(
  connection: Dynamic,
) -> Result(Option(Int), MySqlNativeError)
