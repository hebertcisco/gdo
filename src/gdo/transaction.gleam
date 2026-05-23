import gdo/error.{type Error, TransactionError}

pub type TransactionState {
  Idle
  Active
}

pub fn is_active(state: TransactionState) -> Bool {
  case state {
    Active -> True
    Idle -> False
  }
}

pub fn begin(state: TransactionState) -> Result(TransactionState, Error) {
  case state {
    Idle -> Ok(Active)
    Active -> Error(TransactionError("A transaction is already active."))
  }
}

pub fn commit(state: TransactionState) -> Result(TransactionState, Error) {
  case state {
    Active -> Ok(Idle)
    Idle ->
      Error(TransactionError("Cannot commit without an active transaction."))
  }
}

pub fn rollback(state: TransactionState) -> Result(TransactionState, Error) {
  case state {
    Active -> Ok(Idle)
    Idle ->
      Error(TransactionError("Cannot roll back without an active transaction."))
  }
}
