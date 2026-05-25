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
import gleam/option
import gleam/option.{type Option, None, Some}
import gleam/string

pub const mysql_driver = driver.MySql

pub const driver_name = "mysql"

type ScanState {
  Normal
  InSingleQuotedString
  InDoubleQuotedString
  InLineComment
  InBlockComment
}

type NamedPlaceholderRewrite {
  NamedPlaceholderRewrite(sql: String, parameter_order: Option(List(String)))
}

pub fn capabilities() -> List(driver.Capability) {
  driver.capabilities(mysql_driver)
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
  options: List(#(String, String)),
) -> Result(driver.DriverConnectionState, Error) {
  case target {
    driver.ServerDatabase(network:) ->
      case network.authentication {
        driver.NoAuthentication ->
          open_connection(network, "", "", options)
        driver.UsernameAndPassword(username:, password:) ->
          open_connection(network, username, password, options)
      }

    driver.EmbeddedDatabase(_) ->
      Error(
        ConnectionError(
          message: "MySQL does not support embedded database targets.",
          sqlstate: None,
          code: None,
          details: [#("driver", "mysql"), #("target", "embedded")],
        ),
      )
  }
}

fn open_connection(
  network: driver.NetworkEndpoint,
  username: String,
  password: String,
  options: List(#(String, String)),
) -> Result(driver.DriverConnectionState, Error) {
  let driver.NetworkEndpoint(host:, port:, database:, tls:, ..) = network

  case
    native.mysql_open(
      host,
      port,
      database,
      username,
      password,
      transport_security_name(tls),
      options,
    )
  {
    Ok(connection) ->
      Ok(driver.MySqlConnectionState(endpoint: network, connection: connection))
    Error(error) -> Error(connection_error(error))
  }
}

fn close(connection_state: driver.DriverConnectionState) -> Result(Nil, Error) {
  let assert driver.MySqlConnectionState(connection:, ..) = connection_state

  case native.mysql_close(connection) {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(connection_error(error))
  }
}

fn prepare(
  connection_state: driver.DriverConnectionState,
  sql: String,
) -> Result(driver.DriverStatementState, Error) {
  let assert driver.MySqlConnectionState(connection:, ..) = connection_state
  let NamedPlaceholderRewrite(sql:, parameter_order:) = rewrite_named_placeholders(
    sql,
  )
  Ok(driver.MySqlStatementState(connection:, sql:, named_parameter_order: parameter_order))
}

fn exec(
  statement_state: driver.DriverStatementState,
  params: List(value.Param),
) -> Result(result.ExecutionResult, Error) {
  let assert driver.MySqlStatementState(connection:, sql:, named_parameter_order:) =
    statement_state

  case mysql_arguments(params, named_parameter_order) {
    Ok(arguments) ->
      case native.mysql_exec(sql, on: connection, with: arguments) {
        Ok(native.MySqlExecutionResult(rows_affected:, last_insert_id:)) ->
          Ok(result.execution_result(rows_affected:, last_insert_id:))
        Error(error) -> Error(query_error_from_native(error))
      }
    Error(error) -> Error(error)
  }
}

fn query_all(
  statement_state: driver.DriverStatementState,
  params: List(value.Param),
) -> Result(result.QueryResult, Error) {
  let assert driver.MySqlStatementState(connection:, sql:, named_parameter_order:) =
    statement_state

  case mysql_arguments(params, named_parameter_order) {
    Ok(arguments) ->
      case native.mysql_query(sql, on: connection, with: arguments) {
        Ok(query_result) -> decode_query_result(query_result)
        Error(error) -> Error(query_error_from_native(error))
      }
    Error(error) -> Error(error)
  }
}

fn begin(
  connection_state: driver.DriverConnectionState,
) -> Result(driver.DriverConnectionState, Error) {
  let assert driver.MySqlConnectionState(connection:, ..) = connection_state

  case native.mysql_exec("BEGIN", on: connection, with: []) {
    Ok(_) -> Ok(connection_state)
    Error(error) -> Error(transaction_error_from_native(error))
  }
}

fn commit(
  connection_state: driver.DriverConnectionState,
) -> Result(driver.DriverConnectionState, Error) {
  let assert driver.MySqlConnectionState(connection:, ..) = connection_state

  case native.mysql_exec("COMMIT", on: connection, with: []) {
    Ok(_) -> Ok(connection_state)
    Error(error) -> Error(transaction_error_from_native(error))
  }
}

fn rollback(
  connection_state: driver.DriverConnectionState,
) -> Result(driver.DriverConnectionState, Error) {
  let assert driver.MySqlConnectionState(connection:, ..) = connection_state

  case native.mysql_exec("ROLLBACK", on: connection, with: []) {
    Ok(_) -> Ok(connection_state)
    Error(error) -> Error(transaction_error_from_native(error))
  }
}

fn last_insert_id(
  connection_state: driver.DriverConnectionState,
) -> Option(Int) {
  let assert driver.MySqlConnectionState(connection:, ..) = connection_state

  case native.mysql_last_insert_id(on: connection) {
    Ok(last_insert_id) -> last_insert_id
    Error(_) -> None
  }
}

fn decode_query_result(
  query_result: native.MySqlQueryResult,
) -> Result(result.QueryResult, Error) {
  let native.MySqlQueryResult(columns:, rows:) = query_result

  case list.try_map(rows, decode_mysql_row(columns, _)) {
    Ok(decoded_rows) -> Ok(result.query_result(decoded_rows))
    Error(error) -> Error(error)
  }
}

fn decode_mysql_row(
  columns: List(String),
  dynamic_row: Dynamic,
) -> Result(row.Row, Error) {
  case decode.run(dynamic_row, decode.list(decode.dynamic)) {
    Ok(values) ->
      case list.try_map(values, decode_mysql_value) {
        Ok(decoded_values) ->
          Ok(row.new(pair_columns(columns, decoded_values, [])))
        Error(error) -> Error(error)
      }
    Error(_) -> Error(DecodeError("MySQL returned a row in an unsupported format."))
  }
}

fn pair_columns(
  columns: List(String),
  values: List(value.DbValue),
  acc: List(#(String, value.DbValue)),
) -> List(#(String, value.DbValue)) {
  case columns, values {
    [], [] -> list.reverse(acc)
    [column, ..rest_columns], [current_value, ..rest_values] ->
      pair_columns(
        rest_columns,
        rest_values,
        [#(column, current_value), ..acc],
      )
    _, _ -> list.reverse(acc)
  }
}

fn decode_mysql_value(dynamic_value: Dynamic) -> Result(value.DbValue, Error) {
  case decode.run(dynamic_value, decode.optional(decode.int)) {
    Ok(Some(current_value)) -> Ok(value.Int(current_value))
    Ok(None) -> Ok(value.Null)
    Error(_) -> decode_mysql_float(dynamic_value)
  }
}

fn decode_mysql_float(dynamic_value: Dynamic) -> Result(value.DbValue, Error) {
  case decode.run(dynamic_value, decode.float) {
    Ok(current_value) -> Ok(value.Float(current_value))
    Error(_) -> decode_mysql_bool(dynamic_value)
  }
}

fn decode_mysql_bool(dynamic_value: Dynamic) -> Result(value.DbValue, Error) {
  case decode.run(dynamic_value, decode.bool) {
    Ok(current_value) -> Ok(value.Bool(current_value))
    Error(_) -> decode_mysql_string(dynamic_value)
  }
}

fn decode_mysql_string(dynamic_value: Dynamic) -> Result(value.DbValue, Error) {
  case decode.run(dynamic_value, decode.string) {
    Ok(current_value) -> Ok(value.String(current_value))
    Error(_) -> decode_mysql_bytes(dynamic_value)
  }
}

fn decode_mysql_bytes(dynamic_value: Dynamic) -> Result(value.DbValue, Error) {
  case decode.run(dynamic_value, decode.bit_array) {
    Ok(current_value) -> Ok(value.Bytes(current_value))
    Error(_) ->
      Error(DecodeError("MySQL returned a value in an unsupported format."))
  }
}

fn mysql_arguments(
  params: List(value.Param),
  named_parameter_order: Option(List(String)),
) -> Result(List(value.DbValue), Error) {
  case named_parameter_order {
    None ->
      Ok(list.map(params, value.param_value))

    Some(parameter_order) ->
      parameter_order
      |> list.try_map(fn(name) { lookup_named_param(params, name) })
  }
}

fn lookup_named_param(
  params: List(value.Param),
  name: String,
) -> Result(value.DbValue, Error) {
  case params {
    [] ->
      Error(QueryError(
        message: "Missing named parameter: " <> name,
        sqlstate: None,
        code: None,
        details: [#("driver", "mysql"), #("parameter", name)],
      ))

    [value.Named(current_name, current_value), ..rest] ->
      case current_name == name {
        True -> Ok(current_value)
        False -> lookup_named_param(rest, name)
      }

    [_current, ..rest] -> lookup_named_param(rest, name)
  }
}

fn rewrite_named_placeholders(sql: String) -> NamedPlaceholderRewrite {
  let #(rewritten_sql, names) =
    scan_named_placeholders(
      string.to_graphemes(sql),
      Normal,
      [],
      [],
    )

  case names {
    [] ->
      NamedPlaceholderRewrite(sql: rewritten_sql, parameter_order: None)
    _ ->
      NamedPlaceholderRewrite(
        sql: rewritten_sql,
        parameter_order: Some(list.reverse(names)),
      )
  }
}

fn scan_named_placeholders(
  graphemes: List(String),
  state: ScanState,
  fragments: List(String),
  names: List(String),
) -> #(String, List(String)) {
  case graphemes {
    [] -> #(string.concat(list.reverse(fragments)), names)

    ["'", "'", ..rest] if state == InSingleQuotedString ->
      scan_named_placeholders(
        rest,
        InSingleQuotedString,
        ["''", ..fragments],
        names,
      )

    ["\"", "\"", ..rest] if state == InDoubleQuotedString ->
      scan_named_placeholders(
        rest,
        InDoubleQuotedString,
        ["\"\"", ..fragments],
        names,
      )

    ["'", ..rest] ->
      case state {
        Normal ->
          scan_named_placeholders(
            rest,
            InSingleQuotedString,
            ["'", ..fragments],
            names,
          )
        InSingleQuotedString ->
          scan_named_placeholders(rest, Normal, ["'", ..fragments], names)
        _ -> scan_named_placeholders(rest, state, ["'", ..fragments], names)
      }

    ["\"", ..rest] ->
      case state {
        Normal ->
          scan_named_placeholders(
            rest,
            InDoubleQuotedString,
            ["\"", ..fragments],
            names,
          )
        InDoubleQuotedString ->
          scan_named_placeholders(rest, Normal, ["\"", ..fragments], names)
        _ -> scan_named_placeholders(rest, state, ["\"", ..fragments], names)
      }

    ["-", "-", ..rest] if state == Normal ->
      scan_named_placeholders(rest, InLineComment, ["--", ..fragments], names)

    ["/", "*", ..rest] if state == Normal ->
      scan_named_placeholders(rest, InBlockComment, ["/*", ..fragments], names)

    ["*", "/", ..rest] if state == InBlockComment ->
      scan_named_placeholders(rest, Normal, ["*/", ..fragments], names)

    ["\n", ..rest] if state == InLineComment ->
      scan_named_placeholders(rest, Normal, ["\n", ..fragments], names)

    [":", next, ..rest] ->
      case state, is_identifier_start(next) {
        Normal, True -> {
          let #(name, remaining) = read_identifier([next, ..rest], [])
          scan_named_placeholders(remaining, Normal, ["?", ..fragments], [
            name,
            ..names
          ])
        }
        _, _ ->
          scan_named_placeholders(
            [next, ..rest],
            state,
            [":", ..fragments],
            names,
          )
      }

    [current, ..rest] ->
      scan_named_placeholders(rest, state, [current, ..fragments], names)
  }
}

fn read_identifier(
  graphemes: List(String),
  acc: List(String),
) -> #(String, List(String)) {
  case graphemes {
    [current, ..rest] ->
      case is_identifier_part(current) {
        True -> read_identifier(rest, [current, ..acc])
        False -> #(string.concat(list.reverse(acc)), graphemes)
      }
    _ -> #(string.concat(list.reverse(acc)), graphemes)
  }
}

fn is_identifier_start(grapheme: String) -> Bool {
  case ascii_codepoint(grapheme) {
    Ok(codepoint) -> is_ascii_letter(codepoint) || codepoint == 95
    Error(_) -> False
  }
}

fn is_identifier_part(grapheme: String) -> Bool {
  case ascii_codepoint(grapheme) {
    Ok(codepoint) ->
      is_ascii_letter(codepoint)
      || codepoint == 95
      || { codepoint >= 48 && codepoint <= 57 }
    Error(_) -> False
  }
}

fn is_ascii_letter(codepoint: Int) -> Bool {
  { codepoint >= 65 && codepoint <= 90 }
  || { codepoint >= 97 && codepoint <= 122 }
}

fn ascii_codepoint(grapheme: String) -> Result(Int, Nil) {
  case string.to_utf_codepoints(grapheme) {
    [codepoint] -> Ok(string.utf_codepoint_to_int(codepoint))
    _ -> Error(Nil)
  }
}

fn transport_security_name(security: driver.TransportSecurity) -> String {
  case security {
    driver.DisableTls -> "disable_tls"
    driver.PreferTls -> "prefer_tls"
    driver.RequireTls -> "require_tls"
  }
}

fn connection_error(native_error: native.MySqlNativeError) -> Error {
  let native.MySqlNativeError(code:, sqlstate:, message:) = native_error
  ConnectionError(
    message: message,
    sqlstate: sqlstate,
    code: option.map(code, int.to_string),
    details: [#("driver", "mysql")],
  )
}

fn query_error_from_native(native_error: native.MySqlNativeError) -> Error {
  let native.MySqlNativeError(code:, sqlstate:, message:) = native_error
  QueryError(
    message: message,
    sqlstate: sqlstate,
    code: option.map(code, int.to_string),
    details: [#("driver", "mysql")],
  )
}

fn transaction_error_from_native(native_error: native.MySqlNativeError) -> Error {
  let native.MySqlNativeError(message:, ..) = native_error
  TransactionError(message: message)
}
