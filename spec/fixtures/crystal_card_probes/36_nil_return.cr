optional_value : String? = "ready"
value = optional_value || raise "missing"
value.size
