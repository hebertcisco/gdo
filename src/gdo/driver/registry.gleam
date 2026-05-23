import gdo/driver
import gdo/driver/sqlite

pub fn contract(driver_name: driver.Driver) -> driver.DriverContract {
  case driver_name {
    driver.Sqlite -> sqlite.contract()
  }
}
