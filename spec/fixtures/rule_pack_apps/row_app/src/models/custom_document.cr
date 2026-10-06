@[Grant::Table(name: :custom_documents)]
class CustomDocument < Grant::Base
  column account_id : Int64
  multitenant :account_id
end
