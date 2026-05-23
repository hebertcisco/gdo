import gdo/driver.{
  type Capability, SupportsLastInsertId, SupportsNamedParameters,
  SupportsPositionalParameters, SupportsTransactions,
}

pub const driver_name = "sqlite"

pub fn capabilities() -> List(Capability) {
  [
    SupportsTransactions,
    SupportsLastInsertId,
    SupportsPositionalParameters,
    SupportsNamedParameters,
  ]
}
