class LedgerEntry < Grant::Base
  column id : Int64, primary: true
  column account_id : Int64
  multitenant :account_id
end
