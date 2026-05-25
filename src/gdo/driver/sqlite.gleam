import gdo/driver
import gdo/error.{
  type Error, ConnectionError, DecodeError, QueryError, TransactionError,
}
import gdo/native
import gdo/result
import gdo/row
import gdo/value
import gleam/dynamic.{type Dynamic}
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

fn connect(
  target: driver.ConnectionTarget,
) -> Result(driver.DriverConnectionState, Error) {
  case target {
    driver.EmbeddedDatabase(path:) ->
      case native.sqlite_open(path) {
        Ok(connection) ->
          Ok(driver.SqliteConnectionState(
            database: path,
            connection: connection,
            last_insert_id: None,
          ))
        Error(error) -> Error(connection_error(error))
      }

    driver.ServerDatabase(_) ->
      Error(
        ConnectionError(
          message: "SQLite does not support network connection targets.",
          sqlstate: None,
          code: None,
          details: [#("driver", "sqlite"), #("target", "server")],
        ),
      )
  }
}

fn close(connection_state: driver.DriverConnectionState) -> Result(Nil, Error) {
  let driver.SqliteConnectionState(connection:, ..) = connection_state

  case native.sqlite_close(connection) {
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
      case native.sqlite_exec(sql, on: connection) {
        Ok(_) -> execution_result(connection)
        Error(error) -> Error(query_error_from_native(error))
      }

    arguments ->
      case native.sqlite_query(sql, on: connection, with: arguments) {
        Ok(_) -> execution_result(connection)
        Error(error) -> Error(query_error_from_native(error))
      }
  }
}

fn query_all(
  statement_state: driver.DriverStatementState,
  params: List(value.Param),
) -> Result(result.QueryResult, Error) {
  let driver.SqliteStatementState(connection:, sql:) = statement_state

  case
    native.sqlite_query(sql, on: connection, with: to_sqlight_values(params))
  {
    Ok(rows) ->
      case list.try_map(rows, decode_sqlite_row) {
        Ok(decoded_rows) -> Ok(result.query_result(decoded_rows))
        Error(error) -> Error(error)
      }
    Error(error) -> Error(query_error_from_native(error))
  }
}

fn begin(
  connection_state: driver.DriverConnectionState,
) -> Result(driver.DriverConnectionState, Error) {
  let driver.SqliteConnectionState(connection:, ..) = connection_state

  case native.sqlite_exec("BEGIN", on: connection) {
    Ok(_) -> Ok(connection_state)
    Error(error) -> Error(transaction_error_from_native(error))
  }
}

fn commit(
  connection_state: driver.DriverConnectionState,
) -> Result(driver.DriverConnectionState, Error) {
  let driver.SqliteConnectionState(connection:, ..) = connection_state

  case native.sqlite_exec("COMMIT", on: connection) {
    Ok(_) -> Ok(connection_state)
    Error(error) -> Error(transaction_error_from_native(error))
  }
}

fn rollback(
  connection_state: driver.DriverConnectionState,
) -> Result(driver.DriverConnectionState, Error) {
  let driver.SqliteConnectionState(connection:, ..) = connection_state

  case native.sqlite_exec("ROLLBACK", on: connection) {
    Ok(_) -> Ok(connection_state)
    Error(error) -> Error(transaction_error_from_native(error))
  }
}

fn last_insert_id(
  connection_state: driver.DriverConnectionState,
) -> Option(Int) {
  let driver.SqliteConnectionState(connection:, ..) = connection_state

  case read_last_insert_id(connection) {
    Ok(last_insert_id) -> last_insert_id
    Error(_) -> None
  }
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

fn connection_error(native_error: native.SqliteNativeError) -> Error {
  let native.SqliteNativeError(code:, message:, offset:) = native_error
  ConnectionError(
    message: message,
    sqlstate: None,
    code: Some(int.to_string(code)),
    details: sqlite_error_details(code, offset),
  )
}

fn query_error_from_native(native_error: native.SqliteNativeError) -> Error {
  let native.SqliteNativeError(code:, message:, offset:) = native_error
  QueryError(
    message: message,
    sqlstate: None,
    code: Some(int.to_string(code)),
    details: sqlite_error_details(code, offset),
  )
}

fn transaction_error_from_native(
  native_error: native.SqliteNativeError,
) -> Error {
  let native.SqliteNativeError(message:, ..) = native_error
  TransactionError(message: message)
}

fn execution_result(
  connection: native.Connection,
) -> Result(result.ExecutionResult, Error) {
  case read_rows_affected(connection) {
    Ok(rows_affected) ->
      case read_last_insert_id(connection) {
        Ok(last_insert_id) ->
          Ok(result.execution_result(rows_affected:, last_insert_id:))
        Error(error) -> Error(error)
      }
    Error(error) -> Error(error)
  }
}

fn read_rows_affected(connection: native.Connection) -> Result(Int, Error) {
  case native.sqlite_query("select changes()", on: connection, with: []) {
    Ok(rows) ->
      case list.first(rows) {
        Ok(current_row) ->
          case decode.run(current_row, decode.at([0], decode.int)) {
            Ok(rows_affected) -> Ok(rows_affected)
            Error(_) ->
              Error(DecodeError("SQLite did not return a changes() value."))
          }
        Error(_) ->
          Error(DecodeError("SQLite did not return a changes() value."))
      }
    Error(error) -> Error(query_error_from_native(error))
  }
}

fn read_last_insert_id(
  connection: native.Connection,
) -> Result(Option(Int), Error) {
  case
    native.sqlite_query("select last_insert_rowid()", on: connection, with: [])
  {
    Ok(rows) ->
      case list.first(rows) {
        Ok(current_row) ->
          case decode.run(current_row, decode.at([0], decode.int)) {
            Ok(0) -> Ok(None)
            Ok(last_insert_id) -> Ok(Some(last_insert_id))
            Error(_) ->
              Error(DecodeError(
                "SQLite did not return a last_insert_rowid() value.",
              ))
          }
        Error(_) ->
          Error(DecodeError(
            "SQLite did not return a last_insert_rowid() value.",
          ))
      }
    Error(error) -> Error(query_error_from_native(error))
  }
}

fn decode_sqlite_row(current_row: Dynamic) -> Result(row.Row, Error) {
  case dynamic_row_to_columns(current_row, 0, []) {
    Ok(columns) -> Ok(row.new(columns))
    Error(error) -> Error(error)
  }
}

fn dynamic_row_to_columns(
  current_row: Dynamic,
  index: Int,
  columns: List(#(String, value.DbValue)),
) -> Result(List(#(String, value.DbValue)), Error) {
  case decode.run(current_row, decode.at([index], decode.dynamic)) {
    Ok(dynamic_value) ->
      case dynamic_to_db_value(dynamic_value) {
        Ok(db_value) ->
          dynamic_row_to_columns(current_row, index + 1, [
            #(column_name(index), db_value),
            ..columns
          ])
        Error(error) -> Error(error)
      }

    Error(_) -> Ok(list.reverse(columns))
  }
}

fn dynamic_to_db_value(dynamic_value: Dynamic) -> Result(value.DbValue, Error) {
  case decode.run(dynamic_value, decode.optional(decode.dynamic)) {
    Ok(None) -> Ok(value.Null)
    Ok(Some(non_null_value)) -> decode_non_null_db_value(non_null_value)
    Error(_) -> Error(DecodeError("Unsupported SQLite value type."))
  }
}

fn decode_non_null_db_value(
  dynamic_value: Dynamic,
) -> Result(value.DbValue, Error) {
  case decode.run(dynamic_value, decode.int) {
    Ok(current_value) -> Ok(value.Int(current_value))
    Error(_) ->
      case decode.run(dynamic_value, decode.float) {
        Ok(current_value) -> Ok(value.Float(current_value))
        Error(_) ->
          case decode.run(dynamic_value, decode.string) {
            Ok(current_value) -> Ok(value.String(current_value))
            Error(_) ->
              case decode.run(dynamic_value, decode.bit_array) {
                Ok(current_value) -> Ok(value.Bytes(current_value))
                Error(_) ->
                  case decode.run(dynamic_value, decode.bool) {
                    Ok(current_value) -> Ok(value.Bool(current_value))
                    Error(_) ->
                      Error(DecodeError("Unsupported SQLite value type."))
                  }
              }
          }
      }
  }
}

fn column_name(index: Int) -> String {
  "column_" <> int.to_string(index)
}

fn sqlite_error_details(code: Int, offset: Int) -> List(#(String, String)) {
  [
    #("driver", "sqlite"),
    #("driver_code", int.to_string(code)),
    #("error_offset", int.to_string(offset)),
  ]
}
