import gdo/value.{type DbValue}

pub type Row {
  Row(columns: List(#(String, DbValue)))
}

pub fn new(columns: List(#(String, DbValue))) -> Row {
  Row(columns:)
}
