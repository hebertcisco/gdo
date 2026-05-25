import gdo/error.{type Error}
import gdo/native
import gdo/result
import gdo/value.{type Param}
import gleam/list
import gleam/option.{type Option}

pub type Capability {
  SupportsTransactions
  SupportsLastInsertId
  SupportsPositionalParameters
  SupportsNamedParameters
  SupportsEmbeddedConnections
  SupportsNetworkConnections
  SupportsAuthentication
  SupportsTlsConfiguration
}

pub type Driver {
  Sqlite
}

pub type Authentication {
  NoAuthentication
  UsernameAndPassword(username: String, password: String)
}

pub type TransportSecurity {
  DisableTls
  PreferTls
  RequireTls
}

pub type NetworkEndpoint {
  NetworkEndpoint(
    host: String,
    port: Int,
    database: String,
    authentication: Authentication,
    tls: TransportSecurity,
  )
}

pub type ConnectionTarget {
  EmbeddedDatabase(path: String)
  ServerDatabase(network: NetworkEndpoint)
}

pub type DriverConnectionState {
  SqliteConnectionState(
    database: String,
    connection: native.Connection,
    last_insert_id: Option(Int),
  )
}

pub type DriverStatementState {
  SqliteStatementState(connection: native.Connection, sql: String)
}

pub type DriverContract {
  DriverContract(
    connect: fn(ConnectionTarget) -> Result(DriverConnectionState, Error),
    close: fn(DriverConnectionState) -> Result(Nil, Error),
    prepare: fn(DriverConnectionState, String) ->
      Result(DriverStatementState, Error),
    exec: fn(DriverStatementState, List(Param)) ->
      Result(result.ExecutionResult, Error),
    query_all: fn(DriverStatementState, List(Param)) ->
      Result(result.QueryResult, Error),
    begin: fn(DriverConnectionState) -> Result(DriverConnectionState, Error),
    commit: fn(DriverConnectionState) -> Result(DriverConnectionState, Error),
    rollback: fn(DriverConnectionState) -> Result(DriverConnectionState, Error),
    last_insert_id: fn(DriverConnectionState) -> Option(Int),
  )
}

pub fn name(driver: Driver) -> String {
  case driver {
    Sqlite -> "sqlite"
  }
}

pub fn capabilities(driver: Driver) -> List(Capability) {
  case driver {
    Sqlite -> [
      SupportsTransactions,
      SupportsLastInsertId,
      SupportsPositionalParameters,
      SupportsNamedParameters,
      SupportsEmbeddedConnections,
    ]
  }
}

pub fn connection_target_name(target: ConnectionTarget) -> String {
  case target {
    EmbeddedDatabase(_) -> "embedded"
    ServerDatabase(_) -> "server"
  }
}

pub fn identifier(target: ConnectionTarget) -> String {
  case target {
    EmbeddedDatabase(path:) -> path
    ServerDatabase(NetworkEndpoint(database:, ..)) -> database
  }
}

pub fn supports(driver: Driver, capability capability: Capability) -> Bool {
  list.any(capabilities(driver), fn(current) { current == capability })
}

pub fn connect(
  contract: DriverContract,
  target: ConnectionTarget,
) -> Result(DriverConnectionState, Error) {
  let DriverContract(connect:, ..) = contract
  connect(target)
}

pub fn prepare(
  contract: DriverContract,
  connection_state: DriverConnectionState,
  sql: String,
) -> Result(DriverStatementState, Error) {
  let DriverContract(prepare:, ..) = contract
  prepare(connection_state, sql)
}

pub fn close(
  contract: DriverContract,
  connection_state: DriverConnectionState,
) -> Result(Nil, Error) {
  let DriverContract(close:, ..) = contract
  close(connection_state)
}

pub fn exec(
  contract: DriverContract,
  statement_state: DriverStatementState,
  params: List(Param),
) -> Result(result.ExecutionResult, Error) {
  let DriverContract(exec:, ..) = contract
  exec(statement_state, params)
}

pub fn query_all(
  contract: DriverContract,
  statement_state: DriverStatementState,
  params: List(Param),
) -> Result(result.QueryResult, Error) {
  let DriverContract(query_all:, ..) = contract
  query_all(statement_state, params)
}

pub fn begin(
  contract: DriverContract,
  connection_state: DriverConnectionState,
) -> Result(DriverConnectionState, Error) {
  let DriverContract(begin:, ..) = contract
  begin(connection_state)
}

pub fn commit(
  contract: DriverContract,
  connection_state: DriverConnectionState,
) -> Result(DriverConnectionState, Error) {
  let DriverContract(commit:, ..) = contract
  commit(connection_state)
}

pub fn rollback(
  contract: DriverContract,
  connection_state: DriverConnectionState,
) -> Result(DriverConnectionState, Error) {
  let DriverContract(rollback:, ..) = contract
  rollback(connection_state)
}

pub fn last_insert_id(
  contract: DriverContract,
  connection_state: DriverConnectionState,
) -> Option(Int) {
  let DriverContract(last_insert_id:, ..) = contract
  last_insert_id(connection_state)
}
