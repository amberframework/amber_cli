values = {id: 1_i64}.to_h.all? { |key, value| key.to_s == "id" && value > 0 }
