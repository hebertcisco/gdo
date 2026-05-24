import gdo
import gdo/connection
import gdo/decode
import gdo/driver
import gdo/error
import gdo/result
import gdo/row
import gdo/statement
import gdo/value.{Int, Named, Null, Positional, String}
import gleam/list
import gleam/option.{None, Some}
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn package_name_test() {
  assert gdo.package_name == "gdo"
}

pub fn open_sqlite_connection_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  assert driver.name(connection.driver(conn)) == "sqlite"
  assert connection.database(conn) == ":memory:"
  assert connection.in_transaction(conn) == False
}

pub fn sqlite_config_aliases_test() {
  let config = gdo.sqlite_config(":memory:")
  let assert Ok(conn) = config |> connection.open

  assert connection.database(conn) == ":memory:"
  assert connection.sqlite_config(":memory:") == connection.sqlite(":memory:")
  assert connection.config_driver(config) == driver.Sqlite
  assert connection.config_target(config) == driver.EmbeddedDatabase(":memory:")
}

pub fn server_connection_config_building_test() {
  let config =
    connection.server(
      driver.Sqlite,
      "db.internal",
      3306,
      "app",
      connection.username_and_password("root", "secret"),
      connection.require_tls(),
    )
    |> connection.with_option("pool_size", "10")

  assert connection.config_driver(config) == driver.Sqlite
  assert connection.config_options(config) == [#("pool_size", "10")]
  assert connection.config_target(config)
    == driver.ServerDatabase(driver.NetworkEndpoint(
      host: "db.internal",
      port: 3306,
      database: "app",
      authentication: driver.UsernameAndPassword(
        username: "root",
        password: "secret",
      ),
      tls: driver.RequireTls,
    ))
}

pub fn reject_invalid_server_connection_config_test() {
  let config =
    connection.server(
      driver.Sqlite,
      "   ",
      3306,
      "app",
      connection.no_authentication(),
      connection.disable_tls(),
    )

  let assert Error(err) = connection.open(config)
  assert error.message(err) == "Host cannot be empty."
}

pub fn reject_invalid_server_authentication_config_test() {
  let config =
    connection.server(
      driver.Sqlite,
      "db.internal",
      3306,
      "app",
      connection.username_and_password("   ", "secret"),
      connection.disable_tls(),
    )

  let assert Error(err) = connection.open(config)
  assert error.message(err) == "Username cannot be empty."
}

pub fn sqlite_driver_capabilities_foundation_test() {
  let capabilities = driver.capabilities(driver.Sqlite)

  assert list.contains(capabilities, driver.SupportsTransactions)
  assert list.contains(capabilities, driver.SupportsLastInsertId)
  assert list.contains(capabilities, driver.SupportsEmbeddedConnections)
  assert driver.supports(driver.Sqlite, driver.SupportsNetworkConnections)
    == False
}

pub fn reject_empty_database_test() {
  let assert Error(err) = gdo.open_sqlite("   ")
  assert error.message(err) == "Database cannot be empty."
}

pub fn connection_transaction_lifecycle_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  let assert Ok(conn) = connection.begin(conn)
  assert connection.in_transaction(conn)

  let assert Ok(conn) = connection.commit(conn)
  assert connection.in_transaction(conn) == False
}

pub fn statement_rejects_mixed_placeholders_test() {
  let assert Error(err) =
    statement.prepare("select * from users where id = ? and email = :email")

  assert error.message(err)
    == "Cannot mix positional and named parameters in the same statement."
}

pub fn statement_validates_named_params_test() {
  let assert Ok(stmt) =
    statement.prepare("select * from users where email = :email")

  assert statement.validate_params(stmt, [Named("email", Int(1))]) == Ok(Nil)
}

pub fn statement_rejects_wrong_param_style_test() {
  let assert Ok(stmt) =
    statement.prepare("select * from users where email = :email")

  let assert Error(err) = statement.validate_params(stmt, [Positional(Int(1))])
  assert error.message(err) == "Named statements require named parameters only."
}

pub fn statement_ignores_placeholders_inside_single_quotes_test() {
  let assert Ok(stmt) =
    statement.prepare("select '?' as marker, ':name' as label")

  assert statement.placeholder_style(stmt) == statement.NoParameters
}

pub fn statement_ignores_placeholders_inside_comments_test() {
  let assert Ok(stmt) =
    statement.prepare(
      "select 1 -- ? :ignored\nfrom users /* :still_ignored ? */ where id = ?",
    )

  assert statement.placeholder_style(stmt) == statement.PositionalParameters
}

pub fn statement_detects_named_placeholders_only_in_sql_context_test() {
  let assert Ok(stmt) =
    statement.prepare(
      "select ':' as prefix, name from users where email = :email",
    )

  assert statement.placeholder_style(stmt) == statement.NamedParameters
}

pub fn statement_rejects_mixed_placeholders_outside_strings_test() {
  let assert Error(err) =
    statement.prepare(
      "select ':ignored' as literal from users where id = ? and email = :email",
    )

  assert error.message(err)
    == "Cannot mix positional and named parameters in the same statement."
}

pub fn row_access_test() {
  let current_row = row.new([#("id", Int(10)), #("name", Int(20))])

  assert row.column_count(current_row) == 2
  assert row.get(current_row, "id") == Ok(Int(10))
  assert row.get_at(current_row, 1) == Ok(Int(20))
}

pub fn row_decode_map2_test() {
  let current_row = row.new([#("id", Int(10)), #("name", String("Ana"))])
  let decoder =
    decode.map2(
      decode.column("id", using: decode.int()),
      decode.column("name", using: decode.string()),
      with: fn(id, name) { #(id, name) },
    )

  assert decode.decode(current_row, using: decoder) == Ok(#(10, "Ana"))
}

pub fn row_decode_nullable_test() {
  let current_row = row.new([#("nickname", Null)])
  let decoder =
    decode.column("nickname", using: decode.nullable(decode.string()))

  assert decode.decode(current_row, using: decoder) == Ok(None)
}

pub fn row_decode_type_error_test() {
  let current_row = row.new([#("active", String("yes"))])
  let decoder = decode.column("active", using: decode.bool())

  let assert Error(err) = decode.decode(current_row, using: decoder)
  assert error.message(err) == "Expected bool but found string"
}

pub fn execution_result_test() {
  let current_result =
    result.execution_result(rows_affected: 3, last_insert_id: Some(42))

  assert result.rows_affected(current_result) == 3
  assert result.last_insert_id(current_result) == Some(42)
}

pub fn empty_query_result_test() {
  let current_result = result.empty_query_result()

  assert result.row_count(current_result) == 0
  assert result.first(current_result) == None
  assert result.rows(current_result) == []
}

pub fn query_result_with_rows_test() {
  let first_row = row.new([#("id", Int(1))])
  let second_row = row.new([#("id", Int(2))])
  let current_result = result.query_result([first_row, second_row])

  assert result.row_count(current_result) == 2
  assert result.first(current_result) == Some(first_row)
  assert result.rows(current_result) == [first_row, second_row]
}

pub fn statement_exec_test() {
  let assert Ok(stmt) = statement.prepare("update users set active = ?")
  let assert Ok(exec_result) = statement.exec(stmt, [Positional(Int(1))])

  assert result.rows_affected(exec_result) == 0
  assert result.last_insert_id(exec_result) == None
}

pub fn statement_query_apis_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  let assert Ok(_) =
    connection.exec(
      conn,
      "create table users (id integer primary key, name text)",
      [],
    )
  let assert Ok(_) =
    connection.exec(conn, "insert into users (id, name) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("Ana")),
    ])
  let assert Ok(stmt) =
    connection.prepare(conn, "select id, name from users where id = ?")
  let assert Ok(query_result) = statement.query_all(stmt, [Positional(Int(1))])
  let assert Ok(Some(current_row)) =
    statement.query_one(stmt, [Positional(Int(1))])

  assert result.row_count(query_result) == 1
  assert row.get_at(current_row, 0) == Ok(Int(1))
  assert row.get_at(current_row, 1) == Ok(String("Ana"))
}

pub fn statement_query_as_helpers_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  let assert Ok(_) =
    connection.exec(
      conn,
      "create table users (id integer primary key, name text)",
      [],
    )
  let assert Ok(_) =
    connection.exec(conn, "insert into users (id, name) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("Ana")),
    ])
  let assert Ok(stmt) =
    connection.prepare(conn, "select id, name from users where id = ?")
  let decoder =
    decode.map2(
      decode.column_at(0, using: decode.int()),
      decode.column_at(1, using: decode.string()),
      with: fn(id, name) { #(id, name) },
    )

  let assert Ok([#(1, "Ana")]) =
    statement.query_all_as(stmt, [Positional(Int(1))], using: decoder)
  let assert Ok(Some(#(1, "Ana"))) =
    statement.query_one_as(stmt, [Positional(Int(1))], using: decoder)
}

pub fn connection_exec_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  let assert Ok(_) =
    connection.exec(
      conn,
      "create table users (id integer primary key, active integer)",
      [],
    )
  let assert Ok(exec_result) =
    connection.exec(conn, "insert into users (id, active) values (?, ?)", [
      Positional(Int(1)),
      Positional(Int(1)),
    ])

  assert result.rows_affected(exec_result) == 1
  assert result.last_insert_id(exec_result) == Some(1)
  assert connection.last_insert_id(conn) == Some(1)
}

pub fn connection_exec_reports_sql_errors_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  let assert Error(err) = connection.exec(conn, "this is not valid sql", [])
  let assert error.QueryError(..) = err
  assert error.code(err) != None
  assert error.details(err) != []
}

pub fn connection_close_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  assert connection.close(conn) == Ok(Nil)
}

pub fn connection_query_apis_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  let assert Ok(_) =
    connection.exec(
      conn,
      "create table users (id integer primary key, name text)",
      [],
    )
  let assert Ok(_) =
    connection.exec(conn, "insert into users (id, name) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("Ana")),
    ])
  let assert Ok(query_result) =
    connection.query_all(conn, "select id, name from users where id = ?", [
      Positional(Int(1)),
    ])
  let assert Ok(Some(current_row)) =
    connection.query_one(conn, "select id, name from users where id = ?", [
      Positional(Int(1)),
    ])

  assert result.row_count(query_result) == 1
  assert row.get_at(current_row, 0) == Ok(Int(1))
  assert row.get_at(current_row, 1) == Ok(String("Ana"))
}

pub fn connection_prepare_uses_driver_contract_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  let assert Ok(_) =
    connection.exec(
      conn,
      "create table users (id integer primary key, email text)",
      [],
    )
  let assert Ok(_) =
    connection.exec(conn, "insert into users (id, email) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("ana@example.com")),
    ])
  let assert Ok(stmt) =
    connection.prepare(conn, "select id, email from users where email = :email")
  let assert Ok(query_result) =
    statement.query_all(stmt, [Named("email", String("ana@example.com"))])

  assert statement.placeholder_style(stmt) == statement.NamedParameters
  assert result.row_count(query_result) == 1
}

pub fn connection_query_as_helpers_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  let assert Ok(_) =
    connection.exec(
      conn,
      "create table users (id integer primary key, name text)",
      [],
    )
  let assert Ok(_) =
    connection.exec(conn, "insert into users (id, name) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("Ana")),
    ])
  let decoder =
    decode.map2(
      decode.column_at(0, using: decode.int()),
      decode.column_at(1, using: decode.string()),
      with: fn(id, name) { #(id, name) },
    )

  let assert Ok([#(1, "Ana")]) =
    connection.query_all_as(
      conn,
      "select id, name from users where id = ?",
      [Positional(Int(1))],
      using: decoder,
    )
  let assert Ok(Some(#(1, "Ana"))) =
    connection.query_one_as(
      conn,
      "select id, name from users where id = ?",
      [Positional(Int(1))],
      using: decoder,
    )
}

pub fn connection_query_as_propagates_decode_errors_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  let assert Ok(_) =
    connection.exec(
      conn,
      "create table users (id integer primary key, name text)",
      [],
    )
  let assert Ok(_) =
    connection.exec(conn, "insert into users (id, name) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("Ana")),
    ])
  let decoder =
    decode.map2(
      decode.column_at(0, using: decode.int()),
      decode.column_at(1, using: decode.bool()),
      with: fn(id, active) { #(id, active) },
    )

  let assert Error(err) =
    connection.query_one_as(
      conn,
      "select id, name from users where id = ?",
      [Positional(Int(1))],
      using: decoder,
    )

  let assert error.DecodeError(_) = err
}

pub fn root_exec_and_query_helpers_test() {
  let database = sqlite_test_database("root-test")
  let assert Ok(_) =
    gdo.exec_sqlite(
      database,
      "drop table if exists users; create table users (id integer primary key, name text)",
      [],
    )
  let assert Ok(exec_result) =
    gdo.exec_sqlite(database, "insert into users (id, name) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("Ana")),
    ])
  let assert Ok(query_result) =
    gdo.query_all_sqlite(database, "select id, name from users where id = ?", [
      Positional(Int(1)),
    ])
  let assert Ok(Some(current_row)) =
    gdo.query_one_sqlite(database, "select id, name from users where id = ?", [
      Positional(Int(1)),
    ])

  assert result.rows_affected(exec_result) == 1
  assert result.row_count(query_result) == 1
  assert row.get_at(current_row, 0) == Ok(Int(1))
  assert row.get_at(current_row, 1) == Ok(String("Ana"))
}

pub fn root_query_as_helpers_test() {
  let database = sqlite_test_database("root-query-as")
  let assert Ok(_) =
    gdo.exec_sqlite(
      database,
      "drop table if exists users; create table users (id integer primary key, name text)",
      [],
    )
  let assert Ok(_) =
    gdo.exec_sqlite(database, "insert into users (id, name) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("Ana")),
    ])
  let decoder =
    decode.map2(
      decode.column_at(0, using: decode.int()),
      decode.column_at(1, using: decode.string()),
      with: fn(id, name) { #(id, name) },
    )

  let assert Ok([#(1, "Ana")]) =
    gdo.query_all_sqlite_as(
      database,
      "select id, name from users where id = ?",
      [Positional(Int(1))],
      using: decoder,
    )
  let assert Ok(Some(#(1, "Ana"))) =
    gdo.query_one_sqlite_as(
      database,
      "select id, name from users where id = ?",
      [Positional(Int(1))],
      using: decoder,
    )
}

pub fn sqlite_transaction_commit_persists_rows_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  let assert Ok(_) =
    connection.exec(
      conn,
      "create table users (id integer primary key, name text)",
      [],
    )
  let assert Ok(conn) = connection.begin(conn)
  let assert Ok(_) =
    connection.exec(conn, "insert into users (id, name) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("Ana")),
    ])
  let assert Ok(conn) = connection.commit(conn)
  let assert Ok(Some(current_row)) =
    connection.query_one(conn, "select id, name from users where id = ?", [
      Positional(Int(1)),
    ])

  assert row.get_at(current_row, 0) == Ok(Int(1))
  assert row.get_at(current_row, 1) == Ok(String("Ana"))
}

pub fn sqlite_transaction_rollback_discards_rows_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  let assert Ok(_) =
    connection.exec(
      conn,
      "create table users (id integer primary key, name text)",
      [],
    )
  let assert Ok(conn) = connection.begin(conn)
  let assert Ok(_) =
    connection.exec(conn, "insert into users (id, name) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("Ana")),
    ])
  let assert Ok(conn) = connection.rollback(conn)
  let assert Ok(query_result) =
    connection.query_all(conn, "select id, name from users where id = ?", [
      Positional(Int(1)),
    ])

  assert result.row_count(query_result) == 0
}

pub fn sqlite_transaction_backend_failures_use_transaction_error_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  let assert Ok(_) = connection.exec(conn, "BEGIN", [])
  let assert Error(err) = connection.begin(conn)
  let assert error.TransactionError(_) = err
}

pub fn sqlite_last_insert_id_without_insert_is_none_test() {
  let assert Ok(conn) = gdo.open_sqlite(":memory:")
  assert connection.last_insert_id(conn) == None
}

pub fn sqlite_driver_contract_conformance_test() {
  assert_driver_contract_conformance(connection.sqlite(":memory:"))
}

pub fn sqlite_file_database_roundtrip_integration_test() {
  let database = sqlite_test_database("integration-roundtrip")
  let assert Ok(conn) = gdo.open_sqlite(database)
  let assert Ok(_) =
    connection.exec(
      conn,
      "drop table if exists accounts; create table accounts (id integer primary key, email text not null, active integer not null)",
      [],
    )
  let assert Ok(insert_statement) =
    connection.prepare(
      conn,
      "insert into accounts (id, email, active) values (?, ?, ?)",
    )
  let assert Ok(exec_result) =
    statement.exec(insert_statement, [
      Positional(Int(1)),
      Positional(String("ana@example.com")),
      Positional(Int(1)),
    ])
  let assert Ok(query_statement) =
    connection.prepare(
      conn,
      "select id, email, active from accounts where email = :email",
    )
  let assert Ok(Some(current_row)) =
    statement.query_one(query_statement, [
      Named("email", String("ana@example.com")),
    ])
  let assert Ok(_) = connection.close(conn)

  let assert Ok(reopened_conn) = gdo.open_sqlite(database)
  let assert Ok(query_result) =
    connection.query_all(
      reopened_conn,
      "select id, email, active from accounts order by id",
      [],
    )

  assert result.rows_affected(exec_result) == 1
  assert result.row_count(query_result) == 1
  assert row.get_at(current_row, 0) == Ok(Int(1))
  assert row.get_at(current_row, 1) == Ok(String("ana@example.com"))
  assert row.get_at(current_row, 2) == Ok(Int(1))
}

pub fn sqlite_file_database_transaction_integration_test() {
  let database = sqlite_test_database("integration-transactions")
  let assert Ok(conn) = gdo.open_sqlite(database)
  let assert Ok(_) =
    connection.exec(
      conn,
      "drop table if exists ledger; create table ledger (id integer primary key, note text not null)",
      [],
    )

  let assert Ok(conn) = connection.begin(conn)
  let assert Ok(_) =
    connection.exec(conn, "insert into ledger (id, note) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("committed")),
    ])
  let assert Ok(conn) = connection.commit(conn)

  let assert Ok(conn) = connection.begin(conn)
  let assert Ok(_) =
    connection.exec(conn, "insert into ledger (id, note) values (?, ?)", [
      Positional(Int(2)),
      Positional(String("rolled back")),
    ])
  let assert Ok(conn) = connection.rollback(conn)

  let assert Ok(query_result) =
    connection.query_all(conn, "select id, note from ledger order by id", [])
  let assert Ok(Some(current_row)) =
    connection.query_one(conn, "select id, note from ledger where id = ?", [
      Positional(Int(1)),
    ])

  assert result.row_count(query_result) == 1
  assert row.get_at(current_row, 0) == Ok(Int(1))
  assert row.get_at(current_row, 1) == Ok(String("committed"))
}

pub fn sqlite_file_database_failure_integration_test() {
  let database = sqlite_test_database("integration-failures")
  let assert Ok(conn) = gdo.open_sqlite(database)
  let assert Ok(_) =
    connection.exec(
      conn,
      "drop table if exists users; create table users (id integer primary key, email text not null unique)",
      [],
    )
  let assert Ok(_) =
    connection.exec(conn, "insert into users (id, email) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("ana@example.com")),
    ])
  let assert Error(err) =
    connection.exec(conn, "insert into users (id, email) values (?, ?)", [
      Positional(Int(2)),
      Positional(String("ana@example.com")),
    ])

  let assert error.QueryError(..) = err
  assert error.code(err) != None
}

fn sqlite_test_database(name: String) -> String {
  "/tmp/gdo-" <> name <> ".sqlite"
}

fn assert_driver_contract_conformance(config: connection.ConnectionConfig) {
  let assert Ok(conn) = connection.open(config)
  let assert Ok(_) =
    connection.exec(
      conn,
      "create table users (id integer primary key, name text not null)",
      [],
    )
  let assert Ok(exec_result) =
    connection.exec(conn, "insert into users (id, name) values (?, ?)", [
      Positional(Int(1)),
      Positional(String("Ana")),
    ])
  let assert Ok(Some(current_row)) =
    connection.query_one(conn, "select id, name from users where id = ?", [
      Positional(Int(1)),
    ])

  assert result.rows_affected(exec_result) == 1
  assert row.get_at(current_row, 0) == Ok(Int(1))
  assert row.get_at(current_row, 1) == Ok(String("Ana"))
  assert connection.close(conn) == Ok(Nil)
}
