class InvoiceExport < Grant::Base
  table :invoice_exports
  column account_id : Int64
end
