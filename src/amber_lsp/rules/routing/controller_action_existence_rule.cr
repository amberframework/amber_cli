module AmberLSP::Rules::Routing
  class ControllerActionExistenceRule < AmberLSP::Rules::BaseRule
    def id : String
      "amber/route-controller-exists"
    end

    def description : String
      "Route declarations should reference controllers that exist as files"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Warning
    end

    def applies_to : Array(String)
      ["config/routes.cr"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      return [] of Diagnostic unless file_path.ends_with?("config/routes.cr")

      diagnostics = [] of Diagnostic

      # Derive project root by stripping config/routes.cr from the file path
      project_root = file_path.sub("config/routes.cr", "")

      verb_pattern = /^\s*(?:get|post|put|patch|delete|options|head)\s+".+?",\s*(\w+Controller)\b/
      resources_pattern = /^\s*resources\s+".+?",\s*(\w+Controller)\b/

      content.each_line.with_index do |line, line_number|
        controller_name = nil
        match_data = nil

        verb_match = verb_pattern.match(line)
        resources_match = resources_pattern.match(line)

        if verb_match
          controller_name = verb_match[1]
          match_data = verb_match
        elsif resources_match
          controller_name = resources_match[1]
          match_data = resources_match
        end

        next unless controller_name && match_data

        snake_name = pascal_to_snake(controller_name)
        controller_file = File.join(project_root, "src", "controllers", "#{snake_name}.cr")

        unless File.exists?(controller_file)
          start_char = (match_data.begin(1) || 0).to_i32
          end_char = (match_data.end(1) || line.size).to_i32

          diagnostics << Diagnostic.new(
            range: TextRange.new(
              Position.new(line_number.to_i32, start_char),
              Position.new(line_number.to_i32, end_char)
            ),
            severity: default_severity,
            code: id,
            message: "Controller file 'src/controllers/#{snake_name}.cr' not found for '#{controller_name}'"
          )
        end
      end

      diagnostics
    end

    private def pascal_to_snake(name : String) : String
      name.gsub(/([A-Z])/) { |match, m| "_#{m[0].downcase}" }.lstrip('_')
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Routing::ControllerActionExistenceRule.new)
