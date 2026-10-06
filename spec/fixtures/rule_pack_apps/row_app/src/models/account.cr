class Account < Grant::Base
  table :accounts

  column id : Int64, primary: true
  column account_id : Int64
end
