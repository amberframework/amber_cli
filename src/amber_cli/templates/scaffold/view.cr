require "../field.cr"

module AmberCLI::Scaffold
  class View < Teeplate::FileTree
    include AmberCLI::Helpers
    directory "#{__DIR__}/view"

    @name : String
    @fields : Array(Field)
    @language : String = AmberCLI.config.language
    @database : String = AmberCLI.config.database
    @model : String = AmberCLI.config.model

    def initialize(@name, fields)
      @fields = fields.map { |field| Field.new(field, database: @database) }
      @fields += %w(created_at:time updated_at:time).map do |f|
        Field.new(f, hidden: true, database: @database)
      end
    end

    def filter(entries)
      entries.reject { |entry| entry.path.includes?("src/views") && !entry.path.includes?(".#{@language}") }
    end
  end
end
