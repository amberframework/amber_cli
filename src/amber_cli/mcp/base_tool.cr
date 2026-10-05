# :nodoc:
require "json"
require "mcprotocol"
require "./tool_outcome"

module AmberCLI::MCP
  # Base class for every tool `amber mcp serve` exposes.
  #
  # One tool per file, mirroring the one-command-per-file layout under
  # `src/amber_cli/commands/`.
  abstract class BaseTool
    # The programmatic identifier the client calls.
    abstract def name : String

    # What the tool does, in the terms a model needs to decide whether to call it.
    # Mutating tools state plainly that they write to disk.
    abstract def description : String

    # JSON Schema (2020-12) for the tool's arguments.
    abstract def input_schema : ::MCProtocol::ToolInputSchema

    # Runs the tool. Implementations return a `ToolOutcome` rather than raising;
    # anything that escapes is caught by the dispatcher and reported as a failed
    # tool result.
    abstract def call(arguments : Hash(String, JSON::Any)) : ToolOutcome

    # Whether the tool writes to the filesystem. Advertised to clients through
    # the `destructiveHint` annotation so a host can gate it behind confirmation.
    def mutating? : Bool
      false
    end

    # Human-readable label; falls back to `name` when absent.
    def title : String?
      nil
    end

    # The wire representation sent in `tools/list`.
    def definition : ::MCProtocol::Tool
      ::MCProtocol::Tool.new(
        inputSchema: input_schema,
        name: name,
        description: description,
        title: title,
        meta: annotations
      )
    end

    # Behavioral hints. `readOnlyHint` and `destructiveHint` are what let a host
    # auto-approve introspection while prompting for scaffolding.
    private def annotations : Hash(String, JSON::Any)
      {
        "annotations" => JSON.parse({
          "readOnlyHint"    => !mutating?,
          "destructiveHint" => mutating?,
          "idempotentHint"  => !mutating?,
          "openWorldHint"   => false,
        }.to_json),
      }
    end

    # Reads a required string argument, or returns `nil` when it is absent or of
    # the wrong type.
    protected def string_argument(arguments : Hash(String, JSON::Any), key : String) : String?
      arguments[key]?.try(&.as_s?)
    end

    # Whether *value* is an absolute path.
    #
    # Application-scoped tools require absolute paths: a relative path would be
    # resolved against the server's working directory, which is wherever the user
    # happened to launch `amber mcp serve` and has nothing to do with the
    # application the caller means.
    protected def absolute_path?(value : String) : Bool
      Path[value].absolute?
    end

    # Reads an optional array-of-strings argument.
    protected def string_list_argument(arguments : Hash(String, JSON::Any), key : String) : Array(String)
      arguments[key]?.try(&.as_a?).try(&.compact_map(&.as_s?)) || [] of String
    end
  end
end
