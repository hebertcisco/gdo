import gdo/driver
import gdo/error.{type Error, ConnectionError, QueryError}
import gdo/result
import gdo/value
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import sqlight

pub const sqlite_driver = driver.Sqlite

pub const driver_name = "sqlite"

pub fn capabilities() -> List(driver.Capability) {
  driver.capabilities(sqlite_driver)
}

pub fn contract() -> driver.DriverContract {
  driver.DriverContract(
    connect: connect,
    close: close,
    prepare: prepare,
    exec: exec,
    query_all: query_all,
    begin: begin,
    commit: commit,
    rollback: rollback,
    last_insert_id: last_insert_id,
  )
}

fn connect(database: String) -> Result(driver.DriverConnectionState, Error) {
  case sqlight.open(database) {
    Ok(connection) ->
      Ok(driver.SqliteConnectionState(
        database:,
        connection: connection,
        last_insert_id: None,
      ))
    Error(error) -> Error(connection_error(error))
  }
}

fn close(connection_state: driver.DriverConnectionState) -> Result(Nil, Error) {
  let driver.SqliteConnectionState(connection:, ..) = connection_state

  case sqlight.close(connection) {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(connection_error(error))
  }
}

fn prepare(
  connection_state: driver.DriverConnectionState,
  sql: String,
) -> Result(driver.DriverStatementState, Error) {
  let driver.SqliteConnectionState(connection:, ..) = connection_state
  Ok(driver.SqliteStatementState(connection:, sql:))
}

fn exec(
  statement_state: driver.DriverStatementState,
  params: List(value.Param),
) -> Result(result.ExecutionResult, Error) {
  let driver.SqliteStatementState(connection:, sql:) = statement_state

  case to_sqlight_values(params) {
    [] ->
      case sqlight.exec(sql, on: connection) {
        Ok(_) ->
          Ok(result.execution_result(rows_affected: 0, last_insert_id: None))
        Error(error) -> Error(query_error(error))
      }

    arguments ->
      case
        sqlight.query(
          sql,
          on: connection,
          with: arguments,
          expecting: decode.success(Nil),
        )
      {
        Ok(_) ->
          Ok(result.execution_result(rows_affected: 0, last_insert_id: None))
        Error(error) -> Error(query_error(error))
      }
  }
}

fn query_all(
  statement_state: driver.DriverStatementState,
  params: List(value.Param),
) -> Result(result.QueryResult, Error) {
  let driver.SqliteStatementState(connection:, sql:) = statement_state
  let _ = connection
  let _ = sql
  let _ = params
  Ok(result.empty_query_result())
}

fn begin(
  connection_state: driver.DriverConnectionState,
) -> Result(driver.DriverConnectionState, Error) {
  let driver.SqliteConnectionState(connection:, ..) = connection_state

  case sqlight.exec("BEGIN", on: connection) {
    Ok(_) -> Ok(connection_state)
    Error(error) -> Error(query_error(error))
  }
}

fn commit(
  connection_state: driver.DriverConnectionState,
) -> Result(driver.DriverConnectionState, Error) {
  let driver.SqliteConnectionState(connection:, ..) = connection_state

  case sqlight.exec("COMMIT", on: connection) {
    Ok(_) -> Ok(connection_state)
    Error(error) -> Error(query_error(error))
  }
}

fn rollback(
  connection_state: driver.DriverConnectionState,
) -> Result(driver.DriverConnectionState, Error) {
  let driver.SqliteConnectionState(connection:, ..) = connection_state

  case sqlight.exec("ROLLBACK", on: connection) {
    Ok(_) -> Ok(connection_state)
    Error(error) -> Error(query_error(error))
  }
}

fn last_insert_id(
  connection_state: driver.DriverConnectionState,
) -> Option(Int) {
  let driver.SqliteConnectionState(last_insert_id:, ..) = connection_state
  last_insert_id
}

fn to_sqlight_values(params: List(value.Param)) -> List(sqlight.Value) {
  list.map(params, fn(param) {
    case param {
      value.Positional(current_value) -> to_sqlight_value(current_value)
      value.Named(_, current_value) -> to_sqlight_value(current_value)
    }
  })
}

fn to_sqlight_value(db_value: value.DbValue) -> sqlight.Value {
  case db_value {
    value.Null -> sqlight.null()
    value.Int(current_value) -> sqlight.int(current_value)
    value.Float(current_value) -> sqlight.float(current_value)
    value.Bool(current_value) -> sqlight.bool(current_value)
    value.String(current_value) -> sqlight.text(current_value)
    value.Bytes(current_value) -> sqlight.blob(current_value)
  }
}

fn connection_error(sqlight_error: sqlight.Error) -> Error {
  let sqlight.SqlightError(code:, message:, ..) = sqlight_error
  ConnectionError(
    message: message,
    sqlstate: None,
    code: Some(int.to_string(sqlight.error_code_to_int(code))),
  )
}

fn query_error(sqlight_error: sqlight.Error) -> Error {
  let sqlight.SqlightError(code:, message:, ..) = sqlight_error
  QueryError(
    message: message,
    sqlstate: None,
    code: Some(int.to_string(sqlight.error_code_to_int(code))),
  )
}
