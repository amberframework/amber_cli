module AmberLSP::Rules::Sockets
  class SocketChannelRule < AmberLSP::Rules::BaseRule
    def id : String
      "amber/socket-channel-macro"
    end

    def description : String
      "Structs inheriting Amber::WebSockets::ClientSocket must define at least one channel macro"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Warning
    end

    def applies_to : Array(String)
      ["src/sockets/*"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      return [] of Diagnostic unless file_path.includes?("sockets/")

      diagnostics = [] of Diagnostic
      struct_pattern = /^\s*struct\s+(\w+)\s*<\s*Amber::WebSockets::ClientSocket/
      channel_pattern = /^\s*channel\s+"[\w:*]+",\s*\w+/

      has_channel = content.lines.any? { |line| channel_pattern.matches?(line) }

      content.each_line.with_index do |line, line_number|
        match = struct_pattern.match(line)
        next unless match

        unless has_channel
          struct_name = match[1]
          start_char = (match.begin(1) || 0).to_i32
          end_char = (match.end(1) || line.size).to_i32

          diagnostics << Diagnostic.new(
            range: TextRange.new(
              Position.new(line_number.to_i32, start_char),
              Position.new(line_number.to_i32, end_char)
            ),
            severity: default_severity,
            code: id,
            message: "Socket struct '#{struct_name}' must define at least one 'channel' macro"
          )
        end
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Sockets::SocketChannelRule.new)
