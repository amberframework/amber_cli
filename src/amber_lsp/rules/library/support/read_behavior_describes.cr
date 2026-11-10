require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Reads all method behavior describes under a project's spec directory.
  class ReadBehaviorDescribes
    # Initializes the reader with *root_path*.
    def initialize(@root_path : String)
    end

    # Reads parsed behavior describes from every spec source file.
    def perform : ListOfBehaviorDescribes
      list_of_describes = [] of BehaviorDescribe
      spec_pattern = File.join(@root_path, "spec", "**", "*_spec.cr")

      Dir.glob(spec_pattern).each do |spec_path|
        source_code = File.read(spec_path)
        syntax_tree = ParseCrystalSource.new(source_code).perform
        next unless syntax_tree

        describe_collector = CollectBehaviorDescribes.new(syntax_tree)
        describe_collector.perform.each do |describe_call|
          if selector = ReadBehaviorSelector.new(describe_call).perform
            list_of_describes << BehaviorDescribe.new(
              selector,
              source_code,
              describe_call,
              describe_collector.owner_type_name_for(describe_call),
            )
          end
        end
      end

      list_of_describes
    end
  end
end
