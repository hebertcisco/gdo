import gleam/option.{type Option}

pub type Error {
  ConnectionError(message: String, sqlstate: Option(String), code: Option(String))
  QueryError(message: String, sqlstate: Option(String), code: Option(String))
  TransactionError(message: String)
  DecodeError(message: String)
  UnsupportedFeature(feature: String)
  InvalidConfiguration(message: String)
}
