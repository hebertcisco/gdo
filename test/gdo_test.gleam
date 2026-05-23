import gdo
import gdo/connection
import gdo/driver
import gdo/error
import gdo/result
import gdo/row
import gdo/statement
import gdo/value.{Int, Named, Positional}
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

pub fn row_access_test() {
  let current_row = row.new([#("id", Int(10)), #("name", Int(20))])

  assert row.column_count(current_row) == 2
  assert row.get(current_row, "id") == Ok(Int(10))
  assert row.get_at(current_row, 1) == Ok(Int(20))
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
