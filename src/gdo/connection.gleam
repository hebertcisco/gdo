import gdo/decode
import gdo/driver
import gdo/driver/registry
import gdo/error.{type Error, InvalidConfiguration}
import gdo/result
import gdo/row
import gdo/statement
import gdo/transaction
import gdo/value.{type Param}
import gleam/option.{type Option}
import gleam/string

pub type ConnectionConfig {
  ConnectionConfig(driver: driver.Driver, database: String)
}

pub opaque type Connection {
  Connection(
    config: ConnectionConfig,
    transaction_state: transaction.TransactionState,
    contract: driver.DriverContract,
    connection_state: driver.DriverConnectionState,
  )
}

pub fn sqlite(database: String) -> ConnectionConfig {
  ConnectionConfig(driver: driver.Sqlite, database:)
}

pub fn sqlite_config(database: String) -> ConnectionConfig {
  sqlite(database)
}

pub fn open(config: ConnectionConfig) -> Result(Connection, Error) {
  let ConnectionConfig(database:, driver: current_driver) = config

  case string.is_empty(string.trim(database)) {
    True -> Error(InvalidConfiguration("Database cannot be empty."))
    False -> {
      let contract = registry.contract(current_driver)

      case driver.connect(contract, database) {
        Ok(connection_state) ->
          Ok(Connection(
            config:,
            transaction_state: transaction.Idle,
            contract:,
            connection_state:,
          ))
        Error(error) -> Error(error)
      }
    }
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
  let Connection(config:, transaction_state:, contract:, connection_state:) =
    connection

  case transaction.begin(transaction_state) {
    Ok(next_state) ->
      case driver.begin(contract, connection_state) {
        Ok(next_connection_state) ->
          Ok(Connection(
            config:,
            transaction_state: next_state,
            contract:,
            connection_state: next_connection_state,
          ))
        Error(error) -> Error(error)
      }
    Error(error) -> Error(error)
  }
}

pub fn commit(connection: Connection) -> Result(Connection, Error) {
  let Connection(config:, transaction_state:, contract:, connection_state:) =
    connection

  case transaction.commit(transaction_state) {
    Ok(next_state) ->
      case driver.commit(contract, connection_state) {
        Ok(next_connection_state) ->
          Ok(Connection(
            config:,
            transaction_state: next_state,
            contract:,
            connection_state: next_connection_state,
          ))
        Error(error) -> Error(error)
      }
    Error(error) -> Error(error)
  }
}

pub fn rollback(connection: Connection) -> Result(Connection, Error) {
  let Connection(config:, transaction_state:, contract:, connection_state:) =
    connection

  case transaction.rollback(transaction_state) {
    Ok(next_state) ->
      case driver.rollback(contract, connection_state) {
        Ok(next_connection_state) ->
          Ok(Connection(
            config:,
            transaction_state: next_state,
            contract:,
            connection_state: next_connection_state,
          ))
        Error(error) -> Error(error)
      }
    Error(error) -> Error(error)
  }
}

pub fn prepare(
  connection: Connection,
  sql: String,
) -> Result(statement.Statement, Error) {
  let Connection(contract:, connection_state:, ..) = connection

  case statement.prepare(sql) {
    Ok(prepared_statement) ->
      case
        driver.prepare(
          contract,
          connection_state,
          statement.sql(prepared_statement),
        )
      {
        Ok(statement_state) ->
          Ok(statement.bind(prepared_statement, contract, statement_state))
        Error(error) -> Error(error)
      }
    Error(error) -> Error(error)
  }
}

pub fn close(connection: Connection) -> Result(Nil, Error) {
  let Connection(contract:, connection_state:, ..) = connection
  driver.close(contract, connection_state)
}

pub fn exec(
  connection: Connection,
  sql: String,
  params: List(Param),
) -> Result(result.ExecutionResult, Error) {
  case prepare(connection, sql) {
    Ok(prepared) -> statement.exec(prepared, params)
    Error(error) -> Error(error)
  }
}

pub fn query_one(
  connection: Connection,
  sql: String,
  params: List(Param),
) -> Result(Option(row.Row), Error) {
  case prepare(connection, sql) {
    Ok(prepared) -> statement.query_one(prepared, params)
    Error(error) -> Error(error)
  }
}

pub fn query_all(
  connection: Connection,
  sql: String,
  params: List(Param),
) -> Result(result.QueryResult, Error) {
  case prepare(connection, sql) {
    Ok(prepared) -> statement.query_all(prepared, params)
    Error(error) -> Error(error)
  }
}

pub fn query_one_as(
  connection: Connection,
  sql: String,
  params: List(Param),
  using decoder: decode.Decoder(a),
) -> Result(Option(a), Error) {
  case prepare(connection, sql) {
    Ok(prepared) -> statement.query_one_as(prepared, params, using: decoder)
    Error(error) -> Error(error)
  }
}

pub fn query_all_as(
  connection: Connection,
  sql: String,
  params: List(Param),
  using decoder: decode.Decoder(a),
) -> Result(List(a), Error) {
  case prepare(connection, sql) {
    Ok(prepared) -> statement.query_all_as(prepared, params, using: decoder)
    Error(error) -> Error(error)
  }
}

pub fn last_insert_id(connection: Connection) -> Option(Int) {
  let Connection(contract:, connection_state:, ..) = connection
  driver.last_insert_id(contract, connection_state)
}
