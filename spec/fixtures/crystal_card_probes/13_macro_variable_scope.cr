macro define_value_method
 {% method_name = "value".id %}; def {{method_name}} : String; "ready"; end; end

class CardProbeMacro
  define_value_method
end

CardProbeMacro.new.value
