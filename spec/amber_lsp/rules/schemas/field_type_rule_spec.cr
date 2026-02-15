require "../../spec_helper"
require "../../../../src/amber_lsp/rules/schemas/field_type_rule"

describe AmberLSP::Rules::Schemas::FieldTypeRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Schemas::FieldTypeRule.new)
  end

  describe "#check" do
    it "produces no diagnostics for valid field types" do
      content = <<-CRYSTAL
      class UserSchema < Amber::Schema::Definition
        field :name, String
        field :age, Int32
        field :score, Float64
        field :active, Bool
        field :created_at, Time
        field :uuid, UUID
      end
      CRYSTAL

      rule = AmberLSP::Rules::Schemas::FieldTypeRule.new
      diagnostics = rule.check("src/schemas/user_schema.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for valid array types" do
      content = <<-CRYSTAL
      class TagSchema < Amber::Schema::Definition
        field :tags, Array(String)
        field :ids, Array(Int32)
        field :scores, Array(Float64)
        field :flags, Array(Bool)
        field :big_ids, Array(Int64)
      end
      CRYSTAL

      rule = AmberLSP::Rules::Schemas::FieldTypeRule.new
      diagnostics = rule.check("src/schemas/tag_schema.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for valid hash type" do
      content = <<-CRYSTAL
      class MetaSchema < Amber::Schema::Definition
        field :metadata, Hash(String,JSON::Any)
      end
      CRYSTAL

      rule = AmberLSP::Rules::Schemas::FieldTypeRule.new
      diagnostics = rule.check("src/schemas/meta_schema.cr", content)
      diagnostics.should be_empty
    end

    it "reports error for invalid field type" do
      content = <<-CRYSTAL
      class UserSchema < Amber::Schema::Definition
        field :data, CustomType
      end
      CRYSTAL

      rule = AmberLSP::Rules::Schemas::FieldTypeRule.new
      diagnostics = rule.check("src/schemas/user_schema.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/schema-field-type")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Error)
      diagnostics[0].message.should contain("CustomType")
      diagnostics[0].message.should contain("Valid types")
    end

    it "reports errors for multiple invalid field types" do
      content = <<-CRYSTAL
      class UserSchema < Amber::Schema::Definition
        field :name, String
        field :data, CustomType
        field :other, AnotherType
      end
      CRYSTAL

      rule = AmberLSP::Rules::Schemas::FieldTypeRule.new
      diagnostics = rule.check("src/schemas/user_schema.cr", content)
      diagnostics.size.should eq(2)
      diagnostics[0].message.should contain("CustomType")
      diagnostics[1].message.should contain("AnotherType")
    end

    it "skips files not in schemas/ directory" do
      content = <<-CRYSTAL
      class UserSchema < Amber::Schema::Definition
        field :data, CustomType
      end
      CRYSTAL

      rule = AmberLSP::Rules::Schemas::FieldTypeRule.new
      diagnostics = rule.check("src/models/user.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::Schemas::FieldTypeRule.new
      diagnostics = rule.check("src/schemas/empty_schema.cr", "")
      diagnostics.should be_empty
    end

    it "validates Int64 and Float32 types" do
      content = <<-CRYSTAL
      class NumericSchema < Amber::Schema::Definition
        field :big_id, Int64
        field :small_float, Float32
      end
      CRYSTAL

      rule = AmberLSP::Rules::Schemas::FieldTypeRule.new
      diagnostics = rule.check("src/schemas/numeric_schema.cr", content)
      diagnostics.should be_empty
    end

    it "correctly positions the diagnostic range on the type" do
      content = "  field :name, CustomType"

      rule = AmberLSP::Rules::Schemas::FieldTypeRule.new
      diagnostics = rule.check("src/schemas/user_schema.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].range.start.line.should eq(0)
    end
  end
end
