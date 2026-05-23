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
