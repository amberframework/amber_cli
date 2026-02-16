module AmberLSP::Rules
  class RuleRegistry
    @@rules = [] of BaseRule

    def self.register(rule : BaseRule) : Nil
      @@rules << rule
    end

    def self.rules : Array(BaseRule)
      @@rules
    end

    def self.rules_for_file(file_path : String) : Array(BaseRule)
      @@rules.select do |rule|
        rule.applies_to.any? { |pattern| file_matches_pattern?(file_path, pattern) }
      end
    end

    def self.clear : Nil
      @@rules.clear
    end

    def self.file_matches_pattern?(file_path : String, pattern : String) : Bool
      if pattern == "*"
        true
      elsif pattern.ends_with?("**")
        # Recursive glob: "src/**" matches anything under "src/"
        prefix = pattern.rchop("**")
        file_path.includes?(prefix)
      elsif pattern.starts_with?("*")
        file_path.ends_with?(pattern.lchop("*"))
      elsif pattern.ends_with?("*")
        # Use includes? to support both relative and absolute file paths.
        # E.g., pattern "src/controllers/*" should match "/tmp/project/src/controllers/foo.cr"
        file_path.includes?(pattern.rchop("*"))
      elsif pattern.includes?("*")
        parts = pattern.split("*", 2)
        file_path.includes?(parts[0]) && file_path.ends_with?(parts[1])
      else
        file_path.ends_with?(pattern)
      end
    end
  end
end
