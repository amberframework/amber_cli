class Country < Grant::Base
  table :countries

  column id : Int64, primary: true

  schema_tenant_excluded
end
