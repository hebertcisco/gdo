import gdo/driver
import gdo/error.{type Error}
import gdo/result
import gdo/value.{type Param}
import gleam/option.{type Option, None}

pub const sqlite_driver = driver.Sqlite

pub const driver_name = "sqlite"

pub fn capabilities() -> List(driver.Capability) {
  driver.capabilities(sqlite_driver)
}

pub fn contract() -> driver.DriverContract {
  driver.DriverContract(
    connect: connect,
    prepare: prepare,
    exec: exec,
    query_all: query_all,
    begin: begin,
    commit: commit,
    rollback: rollback,
    last_insert_id: last_insert_id,
  )
}

fn connect(database: String) -> Result(driver.DriverConnectionState, Error) {
  Ok(driver.SqliteConnectionState(database:, last_insert_id: None))
}

fn prepare(
  connection_state: driver.DriverConnectionState,
  sql: String,
) -> Result(driver.DriverStatementState, Error) {
  let driver.SqliteConnectionState(..) = connection_state
  Ok(driver.SqliteStatementState(sql:))
}

fn exec(
  statement_state: driver.DriverStatementState,
  params: List(Param),
) -> Result(result.ExecutionResult, Error) {
  let driver.SqliteStatementState(..) = statement_state
  let _ = params
  Ok(result.execution_result(rows_affected: 0, last_insert_id: None))
}

fn query_all(
  statement_state: driver.DriverStatementState,
  params: List(Param),
) -> Result(result.QueryResult, Error) {
  let driver.SqliteStatementState(..) = statement_state
  let _ = params
  Ok(result.empty_query_result())
}

fn begin(
  connection_state: driver.DriverConnectionState,
) -> Result(driver.DriverConnectionState, Error) {
  Ok(connection_state)
}

fn commit(
  connection_state: driver.DriverConnectionState,
) -> Result(driver.DriverConnectionState, Error) {
  Ok(connection_state)
}

fn rollback(
  connection_state: driver.DriverConnectionState,
) -> Result(driver.DriverConnectionState, Error) {
  Ok(connection_state)
}

fn last_insert_id(
  connection_state: driver.DriverConnectionState,
) -> Option(Int) {
  let driver.SqliteConnectionState(last_insert_id:, ..) = connection_state
  last_insert_id
}
