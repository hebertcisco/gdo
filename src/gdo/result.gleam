import gdo/row.{type Row}
import gleam/list
import gleam/option.{type Option, None, Some}

pub type ExecutionResult {
  ExecutionResult(rows_affected: Int, last_insert_id: Option(Int))
}

pub type QueryResult {
  QueryResult(rows: List(Row))
}

pub fn execution_result(
  rows_affected rows_affected: Int,
  last_insert_id last_insert_id: Option(Int),
) -> ExecutionResult {
  ExecutionResult(rows_affected:, last_insert_id:)
}

pub fn rows_affected(result: ExecutionResult) -> Int {
  let ExecutionResult(rows_affected:, ..) = result
  rows_affected
}

pub fn last_insert_id(result: ExecutionResult) -> Option(Int) {
  let ExecutionResult(last_insert_id:, ..) = result
  last_insert_id
}

pub fn query_result(rows rows: List(Row)) -> QueryResult {
  QueryResult(rows:)
}

pub fn empty_query_result() -> QueryResult {
  QueryResult(rows: [])
}

pub fn rows(result: QueryResult) -> List(Row) {
  let QueryResult(rows:) = result
  rows
}

pub fn row_count(result: QueryResult) -> Int {
  result |> rows |> list.length
}

pub fn first(result: QueryResult) -> Option(Row) {
  case rows(result) {
    [first, ..] -> Some(first)
    [] -> None
  }
}
