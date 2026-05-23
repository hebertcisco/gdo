pub opaque type Connection {
  Connection(driver_name: String)
}

pub fn new(driver_name driver_name: String) -> Connection {
  Connection(driver_name:)
}

pub fn driver_name(connection: Connection) -> String {
  let Connection(driver_name:) = connection
  driver_name
}
