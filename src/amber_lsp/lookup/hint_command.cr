require "file_utils"

require "./api_cards"

module AmberLSP::Lookup
  class RunHintCommand
    USAGE = "Usage: amber-lsp hint [--root DIR]\nReads Crystal compiler output from stdin and shows matching API card hints."

    def initialize(
      @arguments : Array(String),
      @input : IO = STDIN,
      @stdout : IO = STDOUT,
      @stderr : IO = STDERR,
    )
    end

    def perform : Int32
      if @arguments.includes?("--help") || @arguments.includes?("-h")
        @stdout.puts(USAGE)
        return 0
      end

      root_path = project_root_path
      error_text = @input.gets_to_end
      card_collection = LoadAPICards.new(root_path).perform
      print_matching_hints(card_collection.matching_error_hint_matches(error_text))
      0
    rescue ex : ArgumentError | IO::Error
      @stderr.puts("amber-lsp hint failed: #{ex.message || ex.class.to_s}")
      2
    end

    private def project_root_path : String
      root_path = Dir.current
      argument_index = 0

      while argument_index < @arguments.size
        argument = @arguments[argument_index]
        case argument
        when "--root"
          argument_index += 1
          root_path = @arguments[argument_index]? || raise ArgumentError.new("--root requires a directory")
        else
          raise ArgumentError.new("unexpected argument #{argument.inspect}")
        end
        argument_index += 1
      end

      File.expand_path(root_path)
    end

    private def print_matching_hints(list_of_matches : Array(APICardErrorHintMatch)) : Nil
      list_of_matches.each do |match|
        @stdout.puts("hint: #{match.error_hint.hint} [#{match.card_library}@#{match.card_version}]")
        @stdout.puts("  right: #{match.error_hint.example}")
      end
    end
  end
end
