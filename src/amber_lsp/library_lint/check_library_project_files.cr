module AmberLSP::LibraryLint
  # Checks selected project files with the isolated library rule list.
  class CheckLibraryProjectFiles
    CARRIED_IN_RULE_IDS = %w[
      library/swallowed-rescue
      library/unchecked-cast
      library/unsynchronized-class-variable
      library/disabled-certificate-verification
    ]

    # Initializes the checker with its root, paths, rules config, and git changes.
    def initialize(
      @root_path : String,
      @list_of_relative_paths : Array(String),
      @configuration : AmberLSP::Configuration,
      @list_of_exclusion_patterns : Array(String),
      @list_of_carried_in_prefixes : Array(String),
      @changed_lines : AmberLSP::Rules::Library::Support::GitChangedLines?,
    )
    end

    # Runs enabled rules and returns sorted findings.
    def perform : ListOfIssues
      list_of_included_paths = included_paths
      list_of_rules = AmberLSP::Rules::Library::BuildLibraryRuleList.new(@root_path).perform
      changed_method_rule : AmberLSP::Rules::Library::ChangedMethodCollar? = nil
      list_of_issues = [] of Issue

      list_of_rules.each do |rule|
        if collar_rule = rule.as?(AmberLSP::Rules::Library::ChangedMethodCollar)
          changed_method_rule = collar_rule
          next
        end
        next unless @configuration.rule_enabled?(rule.id)

        list_of_included_paths.each do |relative_path|
          next unless rule_checks_path?(rule, relative_path)

          source_code = File.read(File.join(@root_path, relative_path))
          rule.check(relative_path, source_code).each do |diagnostic|
            next unless changed_line_includes?(relative_path, diagnostic)

            list_of_issues << issue_from_diagnostic(relative_path, rule, diagnostic)
          end
        end
      end

      if changed_lines = @changed_lines
        if rule = changed_method_rule
          if @configuration.rule_enabled?(rule.id)
            list_of_diagnostics = rule.check_project(
              @root_path,
              list_of_included_paths,
              changed_lines,
              @list_of_carried_in_prefixes,
            )
            list_of_diagnostics.each do |diagnostic|
              list_of_issues << issue_from_diagnostic(diagnostic.source, rule, diagnostic)
            end
          end
        end
      end

      list_of_issues.sort_by! { |issue| {issue.path, issue.line, issue.column, issue.rule} }
      list_of_issues
    end

    private def included_paths : Array(String)
      @list_of_relative_paths.reject do |relative_path|
        excluded_path?(relative_path) && !carried_in_path?(relative_path)
      end
    end

    private def excluded_path?(relative_path : String) : Bool
      @list_of_exclusion_patterns.any? do |pattern|
        PathMatchesExclusionPattern.new(relative_path, pattern).perform?
      end
    end

    private def rule_checks_path?(rule : AmberLSP::Rules::BaseRule, relative_path : String) : Bool
      return CARRIED_IN_RULE_IDS.includes?(rule.id) if carried_in_path?(relative_path)

      rule.applies_to.any? { |pattern| path_matches_rule_pattern?(relative_path, pattern) }
    end

    # The registry matches `src/**` anywhere in an absolute editor path. These
    # paths are root-relative, so the prefix has to sit at the start.
    private def path_matches_rule_pattern?(relative_path : String, pattern : String) : Bool
      return relative_path.starts_with?(pattern.rchop("**")) if pattern.ends_with?("**")

      AmberLSP::Rules::RuleRegistry.file_matches_pattern?(relative_path, pattern)
    end

    private def carried_in_path?(relative_path : String) : Bool
      @list_of_carried_in_prefixes.any? do |path_prefix|
        path_prefix.empty? || relative_path == path_prefix || relative_path.starts_with?("#{path_prefix}/")
      end
    end

    private def changed_line_includes?(relative_path : String, diagnostic : AmberLSP::Rules::Diagnostic) : Bool
      return true unless changed_lines = @changed_lines

      line_number = diagnostic.range.start.line + 1
      changed_lines.includes?(relative_path, line_number)
    end

    private def issue_from_diagnostic(
      relative_path : String,
      rule : AmberLSP::Rules::BaseRule,
      diagnostic : AmberLSP::Rules::Diagnostic,
    ) : Issue
      configured_severity = @configuration.rule_severity(rule.id, diagnostic.severity)
      classification = classification_for(configured_severity)
      Issue.new(
        relative_path,
        diagnostic.range.start.line + 1,
        diagnostic.range.start.character + 1,
        classification,
        rule.id,
        diagnostic.message,
      )
    end

    private def classification_for(severity : AmberLSP::Rules::Severity) : String
      case severity
      when AmberLSP::Rules::Severity::Error, AmberLSP::Rules::Severity::Warning
        "blocking"
      when AmberLSP::Rules::Severity::Information, AmberLSP::Rules::Severity::Hint
        "advisory"
      else
        "advisory"
      end
    end
  end
end
