import gdo/error.{type Error, InvalidConfiguration}
import gdo/value.{type Param, Named, Positional}
import gleam/list
import gleam/string

pub type PlaceholderStyle {
  NoParameters
  PositionalParameters
  NamedParameters
}

pub opaque type Statement {
  Statement(sql: String, placeholder_style: PlaceholderStyle)
}

pub fn prepare(sql sql: String) -> Result(Statement, Error) {
  let trimmed_sql = string.trim(sql)

  case string.is_empty(trimmed_sql) {
    True -> Error(InvalidConfiguration("SQL cannot be empty."))
    False ->
      case infer_placeholder_style(trimmed_sql) {
        Ok(placeholder_style) -> Ok(Statement(trimmed_sql, placeholder_style))
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

fn infer_placeholder_style(sql: String) -> Result(PlaceholderStyle, Error) {
  let has_positional = string.contains(sql, "?")
  let has_named = string.contains(sql, ":")

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
