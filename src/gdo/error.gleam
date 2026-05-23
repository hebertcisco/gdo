import gleam/option.{type Option, None}

pub type Error {
  ConnectionError(
    message: String,
    sqlstate: Option(String),
    code: Option(String),
  )
  QueryError(message: String, sqlstate: Option(String), code: Option(String))
  TransactionError(message: String)
  DecodeError(message: String)
  UnsupportedFeature(feature: String)
  InvalidConfiguration(message: String)
}

pub fn message(error: Error) -> String {
  case error {
    ConnectionError(message:, ..) -> message
    QueryError(message:, ..) -> message
    TransactionError(message:) -> message
    DecodeError(message:) -> message
    UnsupportedFeature(feature:) -> "Unsupported feature: " <> feature
    InvalidConfiguration(message:) -> message
  }
}

pub fn sqlstate(error: Error) -> Option(String) {
  case error {
    ConnectionError(sqlstate:, ..) -> sqlstate
    QueryError(sqlstate:, ..) -> sqlstate
    TransactionError(_) -> None
    DecodeError(_) -> None
    UnsupportedFeature(_) -> None
    InvalidConfiguration(_) -> None
  }
}

pub fn code(error: Error) -> Option(String) {
  case error {
    ConnectionError(code:, ..) -> code
    QueryError(code:, ..) -> code
    TransactionError(_) -> None
    DecodeError(_) -> None
    UnsupportedFeature(_) -> None
    InvalidConfiguration(_) -> None
  }
}
