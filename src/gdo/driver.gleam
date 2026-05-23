import gleam/list

pub type Capability {
  SupportsTransactions
  SupportsLastInsertId
  SupportsPositionalParameters
  SupportsNamedParameters
}

pub type Driver {
  Sqlite
}

pub fn name(driver: Driver) -> String {
  case driver {
    Sqlite -> "sqlite"
  }
}

pub fn capabilities(driver: Driver) -> List(Capability) {
  case driver {
    Sqlite -> [
      SupportsTransactions,
      SupportsLastInsertId,
      SupportsPositionalParameters,
      SupportsNamedParameters,
    ]
  }
}

pub fn supports(driver: Driver, capability capability: Capability) -> Bool {
  list.any(capabilities(driver), fn(current) { current == capability })
}
