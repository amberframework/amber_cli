module AmberLSP::Rules::FSDD
  class DocBlockRequiredRule < AmberLSP::Rules::BaseRule
    CLASS_RE = /^\s*(abstract\s+)?class\s+/
    DEF_RE   = /^\s*(abstract\s+)?def\s+/
    PRIV_RE  = /^\s*(private|protected)\s+(abstract\s+)?(def|class)\s+/
    NAME_RE  = /\b(?:class|def)\s+(?:self\.)?(\w+[?!]?)/

    def id : String
      "fsdd/doc-block-required"
    end

    def description : String
      "Every public class and public method must have a preceding doc comment"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Information
    end

    def applies_to : Array(String)
      ["src/**"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      diagnostics = [] of Diagnostic
      lines = content.lines

      # prev_nb[i] = index of the previous non-blank line before line i, or -1
      prev_nb = Array(Int32).new(lines.size, -1)
      last_non_blank = -1
      lines.each_with_index do |line, i|
        prev_nb[i] = last_non_blank
        last_non_blank = i unless line.strip.empty?
      end

      lines.each_with_index do |line, i|
        next if line.strip.empty?

        is_class = CLASS_RE.matches?(line)
        is_def   = DEF_RE.matches?(line)
        next unless is_class || is_def

        # Skip singleton class (class << self)
        next if /^\s*class\s+<</.matches?(line)

        # Skip explicitly private/protected on same line
        next if PRIV_RE.matches?(line)

        # Examine the previous non-blank line
        prev_idx = prev_nb[i]
        if prev_idx >= 0
          prev_stripped = lines[prev_idx].strip
          # Preceded by standalone private / protected
          next if prev_stripped == "private" || prev_stripped == "protected"
          has_doc = prev_stripped.starts_with?("#")
        else
          has_doc = false
        end

        next if has_doc

        name_match = NAME_RE.match(line)
        if nm = name_match
          name       = nm[1]
          start_char = (nm.begin(1) || 0).to_i32
          end_char   = (nm.end(1) || line.size).to_i32
        else
          name       = is_class ? "class" : "method"
          start_char = 0
          end_char   = 0
        end

        kind = is_class ? "Class" : "Method"

        diagnostics << Diagnostic.new(
          range: TextRange.new(
            Position.new(i.to_i32, start_char),
            Position.new(i.to_i32, end_char)
          ),
          severity: default_severity,
          code: id,
          message: "#{kind} '#{name}' is missing a doc comment"
        )
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FSDD::DocBlockRequiredRule.new)
