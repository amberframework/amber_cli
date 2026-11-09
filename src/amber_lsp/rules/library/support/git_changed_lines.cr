require "set"

module AmberLSP::Rules::Library::Support
  # Holds lines added relative to a git merge base.
  class GitChangedLines
    HUNK_PATTERN = /^@@ -[0-9]+(?:,[0-9]+)? \+([0-9]+)(?:,([0-9]+))? @@/

    @added_lines_by_path : Hash(String, Set(Int32))

    # Initializes the line set with *root_path* and *reference*.
    def initialize(@root_path : String, @reference : String)
      @added_lines_by_path = Hash(String, Set(Int32)).new
    end

    # Reads working-tree additions since the merge base of *reference* and HEAD.
    def perform : GitChangedLines
      merge_base = run_git("merge-base", [@reference, "HEAD"]).strip
      diff_text = run_git("diff", ["--unified=0", "--no-color", merge_base])
      parse_added_lines(diff_text)
      self
    end

    # Returns whether *line_number* was added in *relative_path*.
    def includes?(relative_path : String, line_number : Int32) : Bool
      normalized_path = relative_path.lchop("./")
      @added_lines_by_path[normalized_path]?.try(&.includes?(line_number)) || false
    end

    # Returns paths with at least one added line.
    def changed_paths : Support::ListOfStrings
      @added_lines_by_path.keys
    end

    # Returns whether an added line overlaps the inclusive method line range.
    def includes_any?(relative_path : String, first_line : Int32, last_line : Int32) : Bool
      return false if first_line > last_line

      normalized_path = relative_path.lchop("./")
      return false unless line_numbers = @added_lines_by_path[normalized_path]?

      line_numbers.any? do |line_number|
        line_number >= first_line && line_number <= last_line
      end
    end

    private def run_git(command_name : String, command_arguments : Array(String)) : String
      output_buffer = IO::Memory.new
      error_buffer = IO::Memory.new
      status = Process.run(
        "git",
        [command_name] + command_arguments,
        chdir: @root_path,
        output: output_buffer,
        error: error_buffer,
      )
      return output_buffer.to_s if status.success?

      details = error_buffer.to_s.strip
      details = output_buffer.to_s.strip if details.empty?
      message = details.empty? ? "git #{command_name} failed" : "git #{command_name} failed: #{details}"
      raise GitCommandError.new(message)
    rescue ex : IO::Error
      raise GitCommandError.new("git #{command_name} could not run: #{ex.message}")
    end

    private def parse_added_lines(diff_text : String) : Nil
      current_path : String? = nil
      diff_text.each_line do |diff_line|
        if diff_line.starts_with?("+++ b/")
          current_path = diff_line.lchop("+++ b/")
          current_path = nil if current_path == "/dev/null"
          next
        end

        next unless current_path
        next unless hunk_match = HUNK_PATTERN.match(diff_line)

        first_added_line = hunk_match[1].to_i
        added_line_count = hunk_match[2]?.try(&.to_i) || 1
        next if added_line_count == 0

        path_line_numbers = @added_lines_by_path[current_path]?
        unless path_line_numbers
          path_line_numbers = Set(Int32).new
          @added_lines_by_path[current_path] = path_line_numbers
        end

        (first_added_line...first_added_line + added_line_count).each do |line_number|
          path_line_numbers << line_number
        end
      end
    end
  end
end
