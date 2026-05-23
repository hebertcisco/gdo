import gdo
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn package_name_test() {
  assert gdo.package_name == "gdo"
}
