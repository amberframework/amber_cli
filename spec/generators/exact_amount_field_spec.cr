require "../amber_cli_spec"
require "../../src/amber_cli/generators/exact_amount_field"

private def parse_amount(field_name : String, kind : String, options_text : String? = nil) : AmberCLI::Generators::ExactAmountField
  AmberCLI::Generators::ExactAmountField.parse(field_name, kind, options_text)
end

private def parse_error_message(field_name : String, kind : String, options_text : String) : String
  expect_raises(AmberCLI::Generators::ExactAmountField::InvalidOptionsError) do
    parse_amount(field_name, kind, options_text)
  end.message.to_s
end

describe AmberCLI::Generators::ExactAmountField do
  describe ".parse" do
    it "defaults a decimal to precision 18 and scale 4" do
      amount_field = parse_amount("price", "decimal")
      amount_field.precision.should eq(18)
      amount_field.scale.should eq(4)
      amount_field.crystal_type.should eq("Grant::Decimal128")
      amount_field.column_options.should eq(", precision: 18, scale: 4")
    end

    it "reads a decimal's precision and scale" do
      amount_field = parse_amount("price", "decimal", "38,10")
      amount_field.precision.should eq(38)
      amount_field.scale.should eq(10)
    end

    it "accepts the edges of the range" do
      parse_amount("price", "decimal", "1,0").precision.should eq(1)
      parse_amount("price", "decimal", "38,38").scale.should eq(38)
      parse_amount("price", "decimal", " 12 , 2 ").scale.should eq(2)
    end

    it "defaults money to precision 18, scale 4, and a currency column" do
      amount_field = parse_amount("total", "money")
      amount_field.crystal_type.should eq("Grant::Money")
      amount_field.column_options.should eq(", precision: 18, scale: 4")
      amount_field.has_a_currency_column?.should be_true
      amount_field.currency_column_name.should eq("total_currency")
    end

    it "fixes a money field's currency with no currency column" do
      amount_field = parse_amount("total", "money", "usd")
      amount_field.fixed_currency_code.should eq("USD")
      amount_field.has_a_currency_column?.should be_false
      amount_field.column_options.should eq(%(, precision: 18, scale: 4, currency: "USD"))
    end

    it "reads money precision and scale with or without a currency" do
      amount_field = parse_amount("total", "money", "18,2,EUR")
      {amount_field.precision, amount_field.scale, amount_field.fixed_currency_code}.should eq({18, 2, "EUR"})

      amount_field = parse_amount("total", "money", "12,3")
      {amount_field.precision, amount_field.scale, amount_field.fixed_currency_code}.should eq({12, 3, nil})
    end

    it "refuses a precision outside 1 to 38" do
      parse_error_message("price", "decimal", "0,0").should contain("precision 0 is outside 1 to 38")
      parse_error_message("price", "decimal", "39,2").should contain("precision 39 is outside 1 to 38")
    end

    it "refuses a scale outside 0 to the precision" do
      parse_error_message("price", "decimal", "10,11").should contain("scale 11 is outside 0 to the precision (10)")
      parse_error_message("price", "decimal", "10,-1").should contain("scale -1 is outside 0 to the precision (10)")
    end

    it "refuses options that are not a precision and a scale" do
      parse_error_message("price", "decimal", "10").should contain("decimal takes a precision and a scale")
      parse_error_message("price", "decimal", "ten,2").should contain("precision and scale must be whole numbers")
      parse_error_message("price", "decimal", "").should contain("decimal{} is empty")
      parse_error_message("price", "decimal", "18,4,USD").should contain("decimal takes a precision and a scale")
      parse_error_message("total", "money", "18,4,US").should contain("money takes a precision and a scale")
    end
  end

  describe "#sql_type" do
    it "matches Grant's storage for each database" do
      amount_field = parse_amount("price", "decimal", "18,4")
      amount_field.sql_type("pg").should eq("NUMERIC(18,4)")
      amount_field.sql_type("mysql").should eq("DECIMAL(18,4)")
      amount_field.sql_type("sqlite").should eq("INTEGER")
    end

    it "stores 19 to 38 digits as TEXT on SQLite" do
      parse_amount("price", "decimal", "19,2").sql_type("sqlite").should eq("TEXT")
      parse_amount("price", "decimal", "38,10").sql_type("sqlite").should eq("TEXT")
      parse_amount("price", "decimal", "38,10").sql_type("pg").should eq("NUMERIC(38,10)")
    end

    it "gives the currency column three characters" do
      amount_field = parse_amount("total", "money")
      amount_field.currency_sql_type("pg").should eq("VARCHAR(3)")
      amount_field.currency_sql_type("mysql").should eq("VARCHAR(3)")
      amount_field.currency_sql_type("sqlite").should eq("TEXT")
    end
  end

  describe "#input_step" do
    it "is one unit of the last decimal place" do
      parse_amount("price", "decimal").input_step.should eq("0.0001")
      parse_amount("price", "decimal", "10,2").input_step.should eq("0.01")
      parse_amount("price", "decimal", "10,0").input_step.should eq("1")
    end
  end

  describe "#sample_amount" do
    it "is an exact string that fits the column" do
      parse_amount("price", "decimal").sample_amount.should eq("19.99")
      parse_amount("price", "decimal", "3,1").sample_amount.should eq("19.9")
      parse_amount("price", "decimal", "2,2").sample_amount.should eq("0.99")
      parse_amount("price", "decimal", "1,0").sample_amount.should eq("9")
    end

    it "builds exact sample literals, never floats" do
      parse_amount("price", "decimal").sample_literal.should eq(%(Grant::Decimal128.parse("19.99")))
      parse_amount("total", "money", "JPY").sample_literal.should eq(%(Grant::Money.new(Grant::Decimal128.parse("19.99"), "JPY")))
    end
  end
end
