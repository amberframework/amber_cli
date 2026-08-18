# :nodoc:
require "json"

module AmberCLI::MCP
  # The documentation corpus `search_docs` and `read_doc` serve.
  #
  # The documents are read into the binary at compile time. `amber` is distributed
  # as a single binary through Homebrew, so anything resolved from disk at runtime
  # would be absent on every installed copy — the docs directory only exists in a
  # source checkout.
  module DocumentIndex
    # Document id => contents. Ids are the repository-relative paths, so a result
    # can be traced back to the file it came from.
    DOCUMENTS = {
      "README.md"                                      => {{ read_file("#{__DIR__}/../../../README.md") }},
      "docs/BETA_WEB_APP.md"                           => {{ read_file("#{__DIR__}/../../../docs/BETA_WEB_APP.md") }},
      "docs/GENERATOR_SUPPORT.md"                      => {{ read_file("#{__DIR__}/../../../docs/GENERATOR_SUPPORT.md") }},
      "docs/RELEASE_CHECKLIST.md"                      => {{ read_file("#{__DIR__}/../../../docs/RELEASE_CHECKLIST.md") }},
      "docs/adr/README.md"                             => {{ read_file("#{__DIR__}/../../../docs/adr/README.md") }},
      "docs/adr/0001-homebrew-release-distribution.md" => {{ read_file("#{__DIR__}/../../../docs/adr/0001-homebrew-release-distribution.md") }},
    }

    # Lines of context returned either side of a match.
    CONTEXT_LINES = 2

    # Ceiling on returned matches, so a one-letter query cannot return the corpus.
    DEFAULT_MATCH_LIMIT = 25

    record Match, document : String, line_number : Int32, line : String, context : String

    # Every document id, with its title and size.
    def self.catalog : Array(NamedTuple(id: String, title: String, lines: Int32, bytes: Int32))
      DOCUMENTS.map do |id, body|
        {id: id, title: title_of(body, id), lines: body.lines.size, bytes: body.bytesize}
      end
    end

    def self.ids : Array(String)
      DOCUMENTS.keys.to_a
    end

    def self.document?(id : String) : String?
      DOCUMENTS[id]?
    end

    # Case-insensitive substring search across every document.
    def self.search(query : String, limit : Int32 = DEFAULT_MATCH_LIMIT) : Array(Match)
      needle = query.downcase
      matches = [] of Match
      return matches if needle.blank?

      DOCUMENTS.each do |id, body|
        lines = body.lines
        lines.each_with_index do |line, index|
          next unless line.downcase.includes?(needle)

          matches << Match.new(
            document: id,
            line_number: index + 1,
            line: line.strip,
            context: context_around(lines, index),
          )
          return matches if matches.size >= limit
        end
      end

      matches
    end

    private def self.context_around(lines : Array(String), index : Int32) : String
      first = Math.max(0, index - CONTEXT_LINES)
      last = Math.min(lines.size - 1, index + CONTEXT_LINES)
      lines[first..last].join("\n")
    end

    # The first Markdown heading, falling back to the id.
    private def self.title_of(body : String, id : String) : String
      heading = body.lines.find(&.starts_with?("#"))
      return id unless heading
      heading.lstrip('#').strip
    end
  end
end
