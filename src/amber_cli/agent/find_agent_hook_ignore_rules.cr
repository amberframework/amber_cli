module AmberCLI::Agent
  record IgnoredAgentHookSetting, path : String, matching_line : String

  # Finds ignore rules that keep an agent hook settings file out of Git worktrees.
  class FindAgentHookIgnoreRules
    LIST_OF_SETTINGS_PATHS = [".claude/settings.json", ".codex/hooks.json"]

    def initialize(@project_root : String)
    end

    def perform : Array(IgnoredAgentHookSetting)
      git_matches = read_git_matches
      return git_matches if git_matches

      read_ignore_files
    end

    private def read_git_matches : Array(IgnoredAgentHookSetting)?
      output = IO::Memory.new
      errors = IO::Memory.new
      status = Process.run(
        "git",
        ["check-ignore", "-v", "--no-index", "--", *LIST_OF_SETTINGS_PATHS],
        chdir: @project_root,
        output: output,
        error: errors,
      )
      return [] of IgnoredAgentHookSetting if status.exit_code == 1 && output.to_s.empty?
      return nil unless status.success?

      output.to_s.lines.compact_map do |result_line|
        list_of_line_fields = result_line.split('\t')
        next unless matching_path = list_of_line_fields.last?
        next unless LIST_OF_SETTINGS_PATHS.includes?(matching_path)
        rule_line = list_of_line_fields.first? || result_line
        IgnoredAgentHookSetting.new(matching_path, rule_line)
      end
    rescue ex : File::NotFoundError
      nil
    end

    private def read_ignore_files : Array(IgnoredAgentHookSetting)
      list_of_rules = {} of String => String?
      [
        {File.join(@project_root, ".git/info/exclude"), ".git/info/exclude"},
        {File.join(@project_root, ".gitignore"), ".gitignore"},
      ].each do |file_path, display_path|
        next unless File.file?(file_path)

        line_number = 0
        File.each_line(file_path) do |raw_line|
          line_number += 1
          rule = raw_line.rstrip
          next if rule.empty? || rule.starts_with?('#')

          is_negation = rule.starts_with?('!')
          pattern = is_negation ? rule.lchop('!') : rule
          LIST_OF_SETTINGS_PATHS.each do |settings_path|
            directory = File.dirname(settings_path)
            next unless pattern.includes?(directory)
            next unless may_match_agent_settings?(pattern, settings_path, directory)

            if is_negation
              list_of_rules[directory] = nil
            else
              list_of_rules[directory] = "#{display_path}:#{line_number}:#{rule}"
            end
          end
        end
      end

      LIST_OF_SETTINGS_PATHS.compact_map do |settings_path|
        directory = File.dirname(settings_path)
        if matching_line = list_of_rules[directory]?
          IgnoredAgentHookSetting.new(settings_path, matching_line)
        end
      end
    end

    private def may_match_agent_settings?(pattern : String, settings_path : String, directory : String) : Bool
      normalized_pattern = pattern.lchop('/')
      normalized_pattern = normalized_pattern[3..] if normalized_pattern.starts_with?("**/")
      if normalized_pattern.ends_with?('/')
        normalized_pattern = normalized_pattern[0...normalized_pattern.size - 1]
      end
      return true if normalized_pattern == directory || normalized_pattern == settings_path
      return true if normalized_pattern == "#{directory}/**"
      return false if normalized_pattern.includes?('/')

      normalized_pattern == directory || normalized_pattern == "#{directory}*"
    end
  end
end
