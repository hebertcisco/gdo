pub type DbValue {
  Null
  Int(Int)
  Float(Float)
  Bool(Bool)
  String(String)
  Bytes(BitArray)
}

pub type Param {
  Positional(DbValue)
  Named(String, DbValue)
}

pub fn type_name(value: DbValue) -> String {
  case value {
    Null -> "null"
    Int(_) -> "int"
    Float(_) -> "float"
    Bool(_) -> "bool"
    String(_) -> "string"
    Bytes(_) -> "bytes"
  }
}

pub fn is_null(value: DbValue) -> Bool {
  case value {
    Null -> True
    _ -> False
  }
}

pub fn param_value(param: Param) -> DbValue {
  case param {
    Positional(value) -> value
    Named(_, value) -> value
  }
}
