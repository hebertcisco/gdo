import gleam/dynamic.{type Dynamic}
import sqlight

pub type Connection {
  Connection(inner: Dynamic)
}

pub type SqliteNativeError {
  SqliteNativeError(code: Int, message: String, offset: Int)
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
