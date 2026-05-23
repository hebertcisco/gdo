import gdo/driver
import gdo/error.{type Error, InvalidConfiguration}
import gdo/result
import gdo/row
import gdo/value.{type Param, Named, Positional}
import gleam/list
import gleam/option.{type Option, None}
import gleam/string

pub type PlaceholderStyle {
  NoParameters
  PositionalParameters
  NamedParameters
}

type StatementBackend {
  Unbound
  Bound(
    contract: driver.DriverContract,
    statement_state: driver.DriverStatementState,
  )
}

type ScanState {
  Normal
  InSingleQuotedString
  InDoubleQuotedString
  InLineComment
  InBlockComment
}

type PlaceholderSummary {
  PlaceholderSummary(has_positional: Bool, has_named: Bool)
}
pub opaque type Statement {
  Statement(
    sql: String,
    placeholder_style: PlaceholderStyle,
    backend: StatementBackend,
  )
}

pub fn prepare(sql sql: String) -> Result(Statement, Error) {
  let trimmed_sql = string.trim(sql)

  case string.is_empty(trimmed_sql) {
    True -> Error(InvalidConfiguration("SQL cannot be empty."))
    False ->
      case infer_placeholder_style(trimmed_sql) {
        Ok(placeholder_style) ->
          Ok(Statement(trimmed_sql, placeholder_style, Unbound))
        Error(error) -> Error(error)
      }
  }
}

pub fn sql(statement: Statement) -> String {
  let Statement(sql:, ..) = statement
  sql
}

pub fn placeholder_style(statement: Statement) -> PlaceholderStyle {
  let Statement(placeholder_style:, ..) = statement
  placeholder_style
}

pub fn bind(
  statement: Statement,
  contract: driver.DriverContract,
  statement_state: driver.DriverStatementState,
) -> Statement {
  let Statement(sql:, placeholder_style:, ..) = statement
  Statement(
    sql:,
    placeholder_style:,
    backend: Bound(contract:, statement_state:),
  )
}

pub fn uses_parameters(statement: Statement) -> Bool {
  case placeholder_style(statement) {
    NoParameters -> False
    _ -> True
  }
}

pub fn validate_params(
  statement: Statement,
  params: List(Param),
) -> Result(Nil, Error) {
  case placeholder_style(statement) {
    NoParameters ->
      case params {
        [] -> Ok(Nil)
        _ ->
          Error(InvalidConfiguration(
            "This statement does not accept parameters.",
          ))
      }

    PositionalParameters ->
      case
        list.any(params, fn(param) {
          case param {
            Named(_, _) -> True
            Positional(_) -> False
          }
        })
      {
        True ->
          Error(InvalidConfiguration(
            "Positional statements require positional parameters only.",
          ))
        False -> Ok(Nil)
      }

    NamedParameters ->
      case
        list.any(params, fn(param) {
          case param {
            Positional(_) -> True
            Named(_, _) -> False
          }
        })
      {
        True ->
          Error(InvalidConfiguration(
            "Named statements require named parameters only.",
          ))
        False -> Ok(Nil)
      }
  }
}

pub fn exec(
  statement: Statement,
  params: List(Param),
) -> Result(result.ExecutionResult, Error) {
  case validate_params(statement, params) {
    Ok(_) ->
      case backend(statement) {
        Bound(contract:, statement_state:) ->
          driver.exec(contract, statement_state, params)
        Unbound ->
          Ok(result.execution_result(rows_affected: 0, last_insert_id: None))
      }
    Error(error) -> Error(error)
  }
}

pub fn execute(
  statement: Statement,
  params: List(Param),
) -> Result(result.ExecutionResult, Error) {
  exec(statement, params)
}

pub fn query_all(
  statement: Statement,
  params: List(Param),
) -> Result(result.QueryResult, Error) {
  case validate_params(statement, params) {
    Ok(_) ->
      case backend(statement) {
        Bound(contract:, statement_state:) ->
          driver.query_all(contract, statement_state, params)
        Unbound -> Ok(result.empty_query_result())
      }
    Error(error) -> Error(error)
  }
}

pub fn query_one(
  statement: Statement,
  params: List(Param),
) -> Result(Option(row.Row), Error) {
  case query_all(statement, params) {
    Ok(query_result) -> Ok(result.first(query_result))
    Error(error) -> Error(error)
  }
}

fn backend(statement: Statement) -> StatementBackend {
  let Statement(backend:, ..) = statement
  backend
}

fn infer_placeholder_style(sql: String) -> Result(PlaceholderStyle, Error) {
  let PlaceholderSummary(has_positional:, has_named:) =
    sql
    |> string.to_graphemes
    |> scan_placeholders(Normal, PlaceholderSummary(False, False))

  case has_positional, has_named {
    True, True ->
      Error(InvalidConfiguration(
        "Cannot mix positional and named parameters in the same statement.",
      ))
    True, False -> Ok(PositionalParameters)
    False, True -> Ok(NamedParameters)
    False, False -> Ok(NoParameters)
  }
}

fn scan_placeholders(
  graphemes: List(String),
  state: ScanState,
  summary: PlaceholderSummary,
) -> PlaceholderSummary {
  case graphemes {
    [] -> summary

    ["'", "'", ..rest] if state == InSingleQuotedString ->
      scan_placeholders(rest, InSingleQuotedString, summary)

    ["\"", "\"", ..rest] if state == InDoubleQuotedString ->
      scan_placeholders(rest, InDoubleQuotedString, summary)

    ["'", ..rest] ->
      case state {
        Normal -> scan_placeholders(rest, InSingleQuotedString, summary)
        InSingleQuotedString -> scan_placeholders(rest, Normal, summary)
        _ -> scan_placeholders(rest, state, summary)
      }

    ["\"", ..rest] ->
      case state {
        Normal -> scan_placeholders(rest, InDoubleQuotedString, summary)
        InDoubleQuotedString -> scan_placeholders(rest, Normal, summary)
        _ -> scan_placeholders(rest, state, summary)
      }

    ["-", "-", ..rest] if state == Normal ->
      scan_placeholders(rest, InLineComment, summary)

    ["/", "*", ..rest] if state == Normal ->
      scan_placeholders(rest, InBlockComment, summary)

    ["*", "/", ..rest] if state == InBlockComment ->
      scan_placeholders(rest, Normal, summary)

    ["\n", ..rest] if state == InLineComment ->
      scan_placeholders(rest, Normal, summary)

    ["?", ..rest] if state == Normal ->
      scan_placeholders(rest, Normal, set_has_positional(summary))

    [":", next, ..rest] ->
      case state, is_identifier_start(next) {
        Normal, True -> scan_placeholders(rest, Normal, set_has_named(summary))
        _, _ -> scan_placeholders([next, ..rest], state, summary)
      }

    [_, ..rest] -> scan_placeholders(rest, state, summary)
  }
}

fn set_has_positional(summary: PlaceholderSummary) -> PlaceholderSummary {
  let PlaceholderSummary(has_named:, ..) = summary
  PlaceholderSummary(has_positional: True, has_named:)
}

fn set_has_named(summary: PlaceholderSummary) -> PlaceholderSummary {
  let PlaceholderSummary(has_positional:, ..) = summary
  PlaceholderSummary(has_positional:, has_named: True)
}

fn is_identifier_start(grapheme: String) -> Bool {
  case ascii_codepoint(grapheme) {
    Ok(codepoint) -> is_ascii_letter(codepoint) || codepoint == 95
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
