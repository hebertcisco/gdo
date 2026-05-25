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
  ConnectionConfig(
    driver: driver.Driver,
    target: driver.ConnectionTarget,
    options: List(#(String, String)),
  )
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
  ConnectionConfig(
    driver: driver.Sqlite,
    target: driver.EmbeddedDatabase(database),
    options: [],
  )
}

pub fn sqlite_config(database: String) -> ConnectionConfig {
  sqlite(database)
}

pub fn mysql(
  host: String,
  port: Int,
  database: String,
  username: String,
  password: String,
) -> ConnectionConfig {
  server(
    driver.MySql,
    host,
    port,
    database,
    username_and_password(username, password),
    disable_tls(),
  )
}

pub fn mysql_config(
  host: String,
  port: Int,
  database: String,
  username: String,
  password: String,
) -> ConnectionConfig {
  mysql(host, port, database, username, password)
}

pub fn server(
  current_driver: driver.Driver,
  host: String,
  port: Int,
  database: String,
  authentication: driver.Authentication,
  tls: driver.TransportSecurity,
) -> ConnectionConfig {
  ConnectionConfig(
    driver: current_driver,
    target: driver.ServerDatabase(driver.NetworkEndpoint(
      host: host,
      port: port,
      database: database,
      authentication: authentication,
      tls: tls,
    )),
    options: [],
  )
}

pub fn no_authentication() -> driver.Authentication {
  driver.NoAuthentication
}

pub fn username_and_password(
  username: String,
  password: String,
) -> driver.Authentication {
  driver.UsernameAndPassword(username:, password:)
}

pub fn disable_tls() -> driver.TransportSecurity {
  driver.DisableTls
}

pub fn prefer_tls() -> driver.TransportSecurity {
  driver.PreferTls
}

pub fn require_tls() -> driver.TransportSecurity {
  driver.RequireTls
}

pub fn with_option(
  config: ConnectionConfig,
  key: String,
  value: String,
) -> ConnectionConfig {
  let ConnectionConfig(driver:, target:, options:) = config
  ConnectionConfig(driver:, target:, options: [#(key, value), ..options])
}

pub fn config_driver(config: ConnectionConfig) -> driver.Driver {
  let ConnectionConfig(driver:, ..) = config
  driver
}

pub fn config_target(config: ConnectionConfig) -> driver.ConnectionTarget {
  let ConnectionConfig(target:, ..) = config
  target
}

pub fn config_options(config: ConnectionConfig) -> List(#(String, String)) {
  let ConnectionConfig(options:, ..) = config
  options
}

pub fn open(config: ConnectionConfig) -> Result(Connection, Error) {
  let ConnectionConfig(target:, driver: current_driver, options:) = config

  case validate_target(target) {
    Ok(_) -> {
      let contract = registry.contract(current_driver)

      case driver.connect(contract, target, options) {
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
    Error(error) -> Error(error)
  }
}

pub fn driver(connection: Connection) -> driver.Driver {
  let Connection(config:, ..) = connection
  let ConnectionConfig(driver:, ..) = config
  driver
}

pub fn database(connection: Connection) -> String {
  let Connection(config:, ..) = connection
  let ConnectionConfig(target:, ..) = config
  driver.identifier(target)
}

pub fn capabilities(connection: Connection) -> List(driver.Capability) {
  driver.capabilities(driver(connection))
}

pub fn target(connection: Connection) -> driver.ConnectionTarget {
  let Connection(config:, ..) = connection
  let ConnectionConfig(target:, ..) = config
  target
}

pub fn options(connection: Connection) -> List(#(String, String)) {
  let Connection(config:, ..) = connection
  let ConnectionConfig(options:, ..) = config
  options
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

fn validate_target(target: driver.ConnectionTarget) -> Result(Nil, Error) {
  case target {
    driver.EmbeddedDatabase(path:) ->
      case string.is_empty(string.trim(path)) {
        True -> Error(InvalidConfiguration("Database cannot be empty."))
        False -> Ok(Nil)
      }

    driver.ServerDatabase(network) -> validate_network_endpoint(network)
  }
}

fn validate_network_endpoint(
  network: driver.NetworkEndpoint,
) -> Result(Nil, Error) {
  let driver.NetworkEndpoint(
    host: host,
    port: port,
    database: database,
    authentication: authentication,
    ..,
  ) = network

  case string.is_empty(string.trim(host)) {
    True -> Error(InvalidConfiguration("Host cannot be empty."))
    False ->
      case port <= 0 {
        True -> Error(InvalidConfiguration("Port must be greater than zero."))
        False ->
          case string.is_empty(string.trim(database)) {
            True -> Error(InvalidConfiguration("Database cannot be empty."))
            False -> validate_authentication(authentication)
          }
      }
  }
}

fn validate_authentication(
  authentication: driver.Authentication,
) -> Result(Nil, Error) {
  case authentication {
    driver.NoAuthentication -> Ok(Nil)
    driver.UsernameAndPassword(username:, ..) ->
      case string.is_empty(string.trim(username)) {
        True -> Error(InvalidConfiguration("Username cannot be empty."))
        False -> Ok(Nil)
      }
  }
}
