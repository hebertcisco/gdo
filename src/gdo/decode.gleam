import gdo/error.{type Error, DecodeError}
import gdo/row
import gdo/value
import gleam/option.{type Option, None, Some}

pub type Decoder(a) =
  fn(row.Row) -> Result(a, Error)

pub type ValueDecoder(a) =
  fn(value.DbValue) -> Result(a, Error)

pub fn decode(
  current_row: row.Row,
  using decoder: Decoder(a),
) -> Result(a, Error) {
  decoder(current_row)
}

pub fn succeed(value: a) -> Decoder(a) {
  fn(_) { Ok(value) }
}

pub fn map(decoder: Decoder(a), with transform: fn(a) -> b) -> Decoder(b) {
  fn(current_row) {
    case decoder(current_row) {
      Ok(decoded) -> Ok(transform(decoded))
      Error(error) -> Error(error)
    }
  }
}

pub fn map2(
  decoder1: Decoder(a),
  decoder2: Decoder(b),
  with combine: fn(a, b) -> c,
) -> Decoder(c) {
  fn(current_row) {
    case decoder1(current_row) {
      Ok(value1) ->
        case decoder2(current_row) {
          Ok(value2) -> Ok(combine(value1, value2))
          Error(error) -> Error(error)
        }
      Error(error) -> Error(error)
    }
  }
}

pub fn map3(
  decoder1: Decoder(a),
  decoder2: Decoder(b),
  decoder3: Decoder(c),
  with combine: fn(a, b, c) -> d,
) -> Decoder(d) {
  fn(current_row) {
    case decoder1(current_row) {
      Ok(value1) ->
        case decoder2(current_row) {
          Ok(value2) ->
            case decoder3(current_row) {
              Ok(value3) -> Ok(combine(value1, value2, value3))
              Error(error) -> Error(error)
            }
          Error(error) -> Error(error)
        }
      Error(error) -> Error(error)
    }
  }
}

pub fn column(
  name: String,
  using value_decoder: ValueDecoder(a),
) -> Decoder(a) {
  fn(current_row) {
    case row.get(current_row, name) {
      Ok(current_value) -> value_decoder(current_value)
      Error(error) -> Error(error)
    }
  }
}

pub fn column_at(
  index: Int,
  using value_decoder: ValueDecoder(a),
) -> Decoder(a) {
  fn(current_row) {
    case row.get_at(current_row, index) {
      Ok(current_value) -> value_decoder(current_value)
      Error(error) -> Error(error)
    }
  }
}

pub fn nullable(value_decoder: ValueDecoder(a)) -> ValueDecoder(Option(a)) {
  fn(current_value) {
    case current_value {
      value.Null -> Ok(None)
      _ ->
        case value_decoder(current_value) {
          Ok(decoded) -> Ok(Some(decoded))
          Error(error) -> Error(error)
        }
    }
  }
}

pub fn int() -> ValueDecoder(Int) {
  fn(current_value) {
    case current_value {
      value.Int(inner) -> Ok(inner)
      _ -> Error(type_error("int", current_value))
    }
  }
}

pub fn float() -> ValueDecoder(Float) {
  fn(current_value) {
    case current_value {
      value.Float(inner) -> Ok(inner)
      _ -> Error(type_error("float", current_value))
    }
  }
}

pub fn bool() -> ValueDecoder(Bool) {
  fn(current_value) {
    case current_value {
      value.Bool(inner) -> Ok(inner)
      _ -> Error(type_error("bool", current_value))
    }
  }
}

pub fn string() -> ValueDecoder(String) {
  fn(current_value) {
    case current_value {
      value.String(inner) -> Ok(inner)
      _ -> Error(type_error("string", current_value))
    }
  }
}

pub fn bytes() -> ValueDecoder(BitArray) {
  fn(current_value) {
    case current_value {
      value.Bytes(inner) -> Ok(inner)
      _ -> Error(type_error("bytes", current_value))
    }
  }
}

fn type_error(expected: String, current_value: value.DbValue) -> Error {
  DecodeError(
    "Expected " <> expected <> " but found " <> value.type_name(current_value),
  )
}
