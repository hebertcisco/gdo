pub opaque type Statement {
  Statement(sql: String)
}

pub fn new(sql sql: String) -> Statement {
  Statement(sql:)
}

pub fn sql(statement: Statement) -> String {
  let Statement(sql:) = statement
  sql
}
