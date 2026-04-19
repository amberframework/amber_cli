module AmberLSP::Rules::Schemas
  class FieldTypeRule < AmberLSP::Rules::BaseRule
    VALID_TYPES = [
      "String",
      "Int32",
      "Int64",
      "Float32",
      "Float64",
      "Bool",
      "Time",
      "UUID",
      "Array(String)",
      "Array(Int32)",
      "Array(Int64)",
      "Array(Float64)",
      "Array(Bool)",
      "Hash(String,JSON::Any)",
    ]

    def id : String
      "amber/schema-field-type"
    end

    def description : String
      "Schema field types must be valid Amber schema types"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Error
    end

    def applies_to : Array(String)
      ["src/schemas/*"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      return [] of Diagnostic unless file_path.includes?("schemas/")

      diagnostics = [] of Diagnostic
      field_pattern = /^\s*field\s+:\w+,\s*(\w+(?:\([^)]*\))?)/

      content.each_line.with_index do |line, line_number|
        match = field_pattern.match(line)
        next unless match

        field_type = match[1]
        unless VALID_TYPES.includes?(field_type)
          start_char = (match.begin(1) || 0).to_i32
          end_char = (match.end(1) || line.size).to_i32

          diagnostics << Diagnostic.new(
            range: TextRange.new(
              Position.new(line_number.to_i32, start_char),
              Position.new(line_number.to_i32, end_char)
            ),
            severity: default_severity,
            code: id,
            message: "Invalid schema field type '#{field_type}'. Valid types: #{VALID_TYPES.join(", ")}"
          )
        end
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Schemas::FieldTypeRule.new)
