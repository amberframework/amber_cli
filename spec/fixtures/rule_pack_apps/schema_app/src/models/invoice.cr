class Invoice < Grant::Base
  table :invoices

  column id : Int64, primary: true
end
