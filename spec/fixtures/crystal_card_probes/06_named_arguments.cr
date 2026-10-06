def foo(a : Int32, b : Int32) : Int32
  a + b
end

a = 1
options = {b: 2}
foo(a: a, b: options[:b])
