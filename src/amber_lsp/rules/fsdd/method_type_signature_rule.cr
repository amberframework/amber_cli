module AmberLSP::Rules::FSDD
  # Crystal lifecycle methods that conventionally omit return type annotations.
  SKIP_METHODS = {"initialize", "finalize"}

  class MethodTypeSignatureRule < AmberLSP::Rules::BaseRule
    def id : String
      "fsdd/method-type-signature"
    end

    def description : String
      "All method definitions must have fully typed signatures: typed parameters and an explicit return type (FSDD verbose + fully-typed standard)"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Warning
    end

    def applies_to : Array(String)
      ["src/**"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      diagnostics = [] of Diagnostic

      # Group 1: leading whitespace + "def ", Group 2: method name, Group 3: rest of signature
      def_pattern = /^(\s*def\s+)(\w+[!?]?)(.*)/

      content.each_line.with_index do |line, line_number|
        match = def_pattern.match(line)
        next unless match

        method_name = match[2]
        rest = match[3]

        next if SKIP_METHODS.includes?(method_name)

        has_untyped_params = false
        has_return_type = false

        if rest.includes?("(")
          paren_start = rest.index('(')
          paren_end = rest.rindex(')')

          # Multi-line signatures (no closing ) on this line) are skipped — known limitation
          next unless paren_start && paren_end && paren_end > paren_start

          params_str = rest[paren_start + 1...paren_end]
          after_paren = rest[paren_end + 1..]

          has_return_type = !!(/\s*:\s*\w/.match(after_paren))
          has_untyped_params = untyped_params?(params_str)
        else
          # No parens: "def foo : ReturnType" or "def foo" (no params)
          has_return_type = !!(/\s*:\s*\w/.match(rest))
        end

        issues = [] of String
        issues << "untyped parameter(s)" if has_untyped_params
        issues << "missing return type" unless has_return_type
        next if issues.empty?

        name_start = (match.begin(2) || 0).to_i32
        name_end = (match.end(2) || line.size).to_i32

        diagnostics << Diagnostic.new(
          range: TextRange.new(
            Position.new(line_number.to_i32, name_start),
            Position.new(line_number.to_i32, name_end)
          ),
          severity: default_severity,
          code: id,
          message: "Method '#{method_name}' has incomplete type signature: #{issues.join(", ")}"
        )
      end

      diagnostics
    end

    private def untyped_params?(params_str : String) : Bool
      return false if params_str.strip.empty?
      params_str.split(",").any? do |param|
        param = param.strip
        next false if param.empty?
        # Splat/double-splat/block params are exempt (typed differently in Crystal)
        next false if param.starts_with?("*") || param.starts_with?("&")
        !param.includes?(":")
      end
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new)
