import gleam/string
import gdo/driver as driver
import gdo/error.{type Error, InvalidConfiguration}
import gdo/transaction as transaction

pub type ConnectionConfig {
  ConnectionConfig(driver: driver.Driver, database: String)
}

pub opaque type Connection {
  Connection(
    config: ConnectionConfig,
    transaction_state: transaction.TransactionState,
  )
}

pub fn sqlite(database: String) -> ConnectionConfig {
  ConnectionConfig(driver: driver.Sqlite, database:)
}

pub fn open(config: ConnectionConfig) -> Result(Connection, Error) {
  let ConnectionConfig(database:, ..) = config

  case string.is_empty(string.trim(database)) {
    True -> Error(InvalidConfiguration("Database cannot be empty."))
    False -> Ok(Connection(config:, transaction_state: transaction.Idle))
  }
}

pub fn driver(connection: Connection) -> driver.Driver {
  let Connection(config:, ..) = connection
  let ConnectionConfig(driver:, ..) = config
  driver
}

pub fn database(connection: Connection) -> String {
  let Connection(config:, ..) = connection
  let ConnectionConfig(database:, ..) = config
  database
}

pub fn capabilities(connection: Connection) -> List(driver.Capability) {
  driver.capabilities(driver(connection))
}

pub fn in_transaction(connection: Connection) -> Bool {
  let Connection(transaction_state:, ..) = connection
  transaction.is_active(transaction_state)
}

pub fn begin(connection: Connection) -> Result(Connection, Error) {
  let Connection(config:, transaction_state:) = connection

  case transaction.begin(transaction_state) {
    Ok(next_state) -> Ok(Connection(config:, transaction_state: next_state))
    Error(error) -> Error(error)
  }
}

pub fn commit(connection: Connection) -> Result(Connection, Error) {
  let Connection(config:, transaction_state:) = connection

  case transaction.commit(transaction_state) {
    Ok(next_state) -> Ok(Connection(config:, transaction_state: next_state))
    Error(error) -> Error(error)
  }
}

pub fn rollback(connection: Connection) -> Result(Connection, Error) {
  let Connection(config:, transaction_state:) = connection

  case transaction.rollback(transaction_state) {
    Ok(next_state) -> Ok(Connection(config:, transaction_state: next_state))
    Error(error) -> Error(error)
  }
}
