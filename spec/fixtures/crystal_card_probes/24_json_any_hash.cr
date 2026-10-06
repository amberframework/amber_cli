require "json"

values = JSON.parse("{}").as_h
values["mode"] = JSON::Any.new("ready")
