class Invoice < Grant::Base
  table :invoices

  column id : Int64, primary: true
  column account_id : Int64
end
