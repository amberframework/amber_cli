module AmberCLI::Generators
  # An exact-amount field given to a generator: `decimal` becomes a
  # `Grant::Decimal128` column and `money` a `Grant::Money` column.
  #
  # Precision and scale follow the type in braces, and a money field may fix
  # its currency there:
  #
  # ```
  # ExactAmountField.parse("price", "decimal")           # NUMERIC(18,4)
  # ExactAmountField.parse("price", "decimal", "38,10")  # NUMERIC(38,10)
  # ExactAmountField.parse("total", "money")             # amount plus a total_currency column
  # ExactAmountField.parse("total", "money", "USD")      # amount only, always USD
  # ExactAmountField.parse("total", "money", "18,2,USD") # NUMERIC(18,2), always USD
  # ```
  #
  # The storage per database matches Grant's: PostgreSQL `NUMERIC(p,s)`,
  # MySQL `DECIMAL(p,s)`, and SQLite `INTEGER` (the coefficient at the column
  # scale) up to 18 digits or `TEXT` from 19 to 38 digits.
  struct ExactAmountField
    KINDS = %w[decimal money]

    DEFAULT_PRECISION = 18
    DEFAULT_SCALE     =  4
    MAXIMUM_PRECISION = 38

    # SQLite keeps up to this many digits in an INTEGER column; more go in TEXT.
    MAXIMUM_SQLITE_INTEGER_PRECISION = 18

    # Raised when the braces after `decimal` or `money` cannot be read.
    class InvalidOptionsError < Exception
    end

    getter field_name : String
    getter amount_kind : String
    getter precision : Int32
    getter scale : Int32
    getter fixed_currency_code : String?

    def initialize(@field_name : String, @amount_kind : String, @precision : Int32 = DEFAULT_PRECISION,
                   @scale : Int32 = DEFAULT_SCALE, @fixed_currency_code : String? = nil)
    end

    # Whether *field_type* (without braces) is an exact-amount type.
    def self.kind?(field_type : String) : Bool
      KINDS.includes?(field_type)
    end

    # Reads the options between the braces of `decimal{...}` or `money{...}`.
    # *options_text* is nil when the type had no braces. Raises
    # `InvalidOptionsError` naming the field when an option is out of range.
    def self.parse(field_name : String, kind : String, options_text : String? = nil) : ExactAmountField
      raise InvalidOptionsError.new("#{field_name}: #{kind} is not an exact-amount type") unless kind?(kind)
      return new(field_name, kind) if options_text.nil?

      list_of_options = options_text.strip.empty? ? [] of String : options_text.split(',').map(&.strip)
      currency_code = nil
      if kind == "money" && (last_option = list_of_options.last?) && currency_code?(last_option)
        currency_code = last_option.upcase
        list_of_options.pop
      end

      precision, scale = read_precision_and_scale(field_name, kind, list_of_options)
      new(field_name, kind, precision, scale, currency_code)
    end

    private def self.read_precision_and_scale(field_name : String, kind : String, list_of_options : Array(String)) : Tuple(Int32, Int32)
      case list_of_options.size
      when 0
        raise InvalidOptionsError.new("#{field_name}: #{kind}{} is empty; #{usage(kind)}") if kind == "decimal"
        {DEFAULT_PRECISION, DEFAULT_SCALE}
      when 2
        precision = list_of_options[0].to_i?
        scale = list_of_options[1].to_i?
        if precision.nil? || scale.nil?
          raise InvalidOptionsError.new("#{field_name}: precision and scale must be whole numbers; #{usage(kind)}")
        end
        check_range(field_name, precision, scale)
        {precision, scale}
      else
        raise InvalidOptionsError.new("#{field_name}: #{kind} takes a precision and a scale; #{usage(kind)}")
      end
    end

    private def self.check_range(field_name : String, precision : Int32, scale : Int32) : Nil
      unless 1 <= precision <= MAXIMUM_PRECISION
        raise InvalidOptionsError.new("#{field_name}: precision #{precision} is outside 1 to #{MAXIMUM_PRECISION}")
      end
      unless 0 <= scale <= precision
        raise InvalidOptionsError.new("#{field_name}: scale #{scale} is outside 0 to the precision (#{precision})")
      end
    end

    private def self.currency_code?(text : String) : Bool
      text.size == 3 && text.each_char.all?(&.ascii_letter?)
    end

    private def self.usage(kind : String) : String
      if kind == "decimal"
        "write price:decimal{38,10} (precision 1 to 38, scale 0 to the precision)"
      else
        "write total:money, total:money{USD}, total:money{18,4} or total:money{18,4,USD}"
      end
    end

    def money? : Bool
      amount_kind == "money"
    end

    # Whether a money field keeps its currency in a companion column.
    def has_a_currency_column? : Bool
      money? && fixed_currency_code.nil?
    end

    def currency_column_name : String
      "#{field_name}_currency"
    end

    def crystal_type : String
      money? ? "Grant::Money" : "Grant::Decimal128"
    end

    # The options after the type in the model's `column` declaration.
    def column_options : String
      options = ", precision: #{precision}, scale: #{scale}"
      if currency_code = fixed_currency_code
        options += %(, currency: "#{currency_code}")
      end
      options
    end

    def sql_type(database_type : String) : String
      case database_type
      when "pg"    then "NUMERIC(#{precision},#{scale})"
      when "mysql" then "DECIMAL(#{precision},#{scale})"
      else              precision <= MAXIMUM_SQLITE_INTEGER_PRECISION ? "INTEGER" : "TEXT"
      end
    end

    def currency_sql_type(database_type : String) : String
      database_type == "pg" || database_type == "mysql" ? "VARCHAR(3)" : "TEXT"
    end

    # The `step` of the number input: one unit of the last decimal place.
    def input_step : String
      scale.zero? ? "1" : "0.#{"0" * (scale - 1)}1"
    end

    # An exact sample amount that fits the column, such as "19.99".
    def sample_amount : String
      whole_digits = precision - scale
      whole_part = whole_digits >= 2 ? "19" : (whole_digits == 1 ? "9" : "0")
      case scale
      when 0 then whole_part
      when 1 then "#{whole_part}.9"
      else        "#{whole_part}.99"
      end
    end

    def sample_currency_code : String
      fixed_currency_code || "USD"
    end

    # Crystal source for the sample value assigned to a record in specs.
    def sample_literal : String
      if money?
        %(Grant::Money.new(Grant::Decimal128.parse("#{sample_amount}"), "#{sample_currency_code}"))
      else
        %(Grant::Decimal128.parse("#{sample_amount}"))
      end
    end
  end
end
