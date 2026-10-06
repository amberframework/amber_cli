def with_integer(&block : -> Int64) : Int64
  block.call
end

with_integer { 1_i64 }
