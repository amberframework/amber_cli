module AmberLSP::Rules::FSDD
  class StoryGrammarRule < AmberLSP::Rules::BaseRule
    STORY_INITIATOR_RE    = /\b(As a|At |Every )/
    ACTION_VERB_RE        = /\b(GET|POST|PUT|PATCH|DELETE|perform|do)\b/
    STORY_INITIATOR_WORDS = {"As", "At", "Every"}
    MODEL_NAME_RE         = /\b[A-Z][a-z][a-zA-Z0-9]*\b/

    def id : String
      "fsdd/story-grammar"
    end

    def description : String
      "Feature story doc comments must include an action verb and a capitalized Model name or process reference"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Warning
    end

    def applies_to : Array(String)
      ["src/**"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      diagnostics = [] of Diagnostic
      lines = content.lines

      in_block       = false
      block_lines    = [] of String
      block_start    = 0

      lines.each_with_index do |line, i|
        is_comment = line.strip.starts_with?("#")

        if is_comment
          unless in_block
            in_block    = true
            block_start = i
            block_lines = [] of String
          end
          block_lines << line.strip.lchop("#").strip
        elsif in_block
          in_block = false
          emit_story_diagnostics(block_lines, block_start, diagnostics)
        end
      end

      emit_story_diagnostics(block_lines, block_start, diagnostics) if in_block

      diagnostics
    end

    private def emit_story_diagnostics(
      block_lines : Array(String),
      block_start : Int32,
      diagnostics : Array(Diagnostic)
    ) : Nil
      block_text = block_lines.join(" ")
      return unless STORY_INITIATOR_RE.matches?(block_text)

      issues = [] of String
      issues << "missing action verb (GET, POST, PUT, PATCH, DELETE, perform, or do)" unless ACTION_VERB_RE.matches?(block_text)
      issues << "missing capitalized Model name or process reference" unless has_model_name?(block_text)
      return if issues.empty?

      # Point to the line that contains the story initiator
      story_line = block_start
      block_lines.each_with_index do |line_content, bi|
        if STORY_INITIATOR_RE.matches?(line_content)
          story_line = block_start + bi
          break
        end
      end

      diagnostics << Diagnostic.new(
        range: TextRange.new(
          Position.new(story_line, 0),
          Position.new(story_line, 0)
        ),
        severity: default_severity,
        code: id,
        message: "Story comment: #{issues.join("; ")}"
      )
    end

    # Returns true if text contains a PascalCase word that looks like a model
    # or process name (4+ chars, not a story initiator word like "As"/"At"/"Every").
    private def has_model_name?(text : String) : Bool
      pos = 0
      while (m = MODEL_NAME_RE.match(text, pos))
        word = m[0]
        return true if word.size >= 4 && !STORY_INITIATOR_WORDS.includes?(word)
        new_pos = (m.end(0) || pos + 1).to_i32
        pos = new_pos > pos ? new_pos : pos + 1
      end
      false
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FSDD::StoryGrammarRule.new)
