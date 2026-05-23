import gdo/driver

pub const sqlite_driver = driver.Sqlite

pub const driver_name = "sqlite"

pub fn capabilities() -> List(driver.Capability) {
  driver.capabilities(sqlite_driver)
}
