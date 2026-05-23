import gdo/error.{type Error, DecodeError}
import gdo/value.{type DbValue}
import gleam/dict
import gleam/list

pub type Row {
  Row(columns: List(#(String, DbValue)))
}

pub fn new(columns: List(#(String, DbValue))) -> Row {
  Row(columns:)
}

pub fn columns(row: Row) -> List(#(String, DbValue)) {
  let Row(columns:) = row
  columns
}

pub fn column_count(row: Row) -> Int {
  row |> columns |> list.length
}

pub fn get(row: Row, column_name: String) -> Result(DbValue, Error) {
  case row |> columns |> dict.from_list |> dict.get(column_name) {
    Ok(value) -> Ok(value)
    Error(_) -> Error(DecodeError("Column not found: " <> column_name))
  }
}

pub fn get_at(row: Row, index: Int) -> Result(DbValue, Error) {
  case index < 0 {
    True -> Error(DecodeError("Column index cannot be negative."))
    False -> nth(columns(row), index)
  }
}

fn nth(
  columns: List(#(String, DbValue)),
  index: Int,
) -> Result(DbValue, Error) {
  case columns, index {
    [], _ -> Error(DecodeError("Column index out of bounds."))
    [#(_, value), ..], 0 -> Ok(value)
    [_, ..rest], _ -> nth(rest, index - 1)
  }
}
