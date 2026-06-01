require "../core/base_command"
require "../fsdd_docs/renderer"

module AmberCLI::Commands
  # The `docs:fsdd` command generates a static FSDD help-doc site from Crystal
  # docs JSON. It reads `FSDD_docs/json/<version>/index.json` (generating it via
  # `crystal docs` if absent), applies the version ramp across all stored versions,
  # and writes a self-contained static HTML site to `FSDD_docs/html/`.
  #
  # ## Usage
  # ```
  # amber docs:fsdd [OPTIONS]
  # ```
  #
  # ## Examples
  # ```
  # amber docs:fsdd
  # amber docs:fsdd --repo /path/to/project --version 2.1.0
  # ```
  class DocsFSDDCommand < AmberCLI::Core::BaseCommand
    getter repo_option : String = Dir.current
    getter version_option : String? = nil

    def help_description : String
      <<-HELP
      Generate a static FSDD help-doc site from Crystal docs JSON

      Usage: amber docs:fsdd [OPTIONS]

      This command:
        1. Runs `crystal docs --format=json` (or reads FSDD_docs/json/<v>/index.json)
        2. Parses FSDD doc-comment sections (Personas, Requires, Since, Ramp, Use, Result, Story)
        3. Computes a version ramp across all stored versions
        4. Renders a static HTML site to FSDD_docs/html/

      Options:
        --repo=DIR      Crystal project root (default: current directory)
        --version=VER   Version label to use (default: read from shard.yml or "snapshot")
      HELP
    end

    def setup_command_options
      option_parser.separator ""
      option_parser.separator "Options:"

      option_parser.on("--repo=DIR", "Crystal project root (default: current directory)") do |dir|
        @repo_option = dir
      end

      option_parser.on("--version=VER", "Version label (default: read from shard.yml or 'snapshot')") do |v|
        @version_option = v
      end
    end

    def execute
      repo = File.expand_path(repo_option)

      unless Dir.exists?(repo)
        error "Repo directory not found: #{repo}"
        exit(1)
      end

      version = version_option || read_shard_version(repo) || "snapshot"
      info "Generating FSDD docs for version #{version} in #{repo}"

      fsdd_docs_dir = File.join(repo, "FSDD_docs")
      json_dir = File.join(fsdd_docs_dir, "json", version)
      json_path = File.join(json_dir, "index.json")
      output_dir = File.join(fsdd_docs_dir, "html")

      unless File.exists?(json_path)
        generate_crystal_docs(repo, json_dir, json_path)
      else
        info "Using existing docs JSON: #{json_path}"
      end

      update_versions_json(fsdd_docs_dir, version)

      info "Loading version ramp..."
      ramp = FSDDDocs::VersionRamp.load(fsdd_docs_dir)

      info "Parsing #{json_path}..."
      types = FSDDDocs::Parser.parse_file(json_path)
      info "Found #{types.size} types"

      info "Rendering to #{output_dir}..."
      renderer = FSDDDocs::Renderer.new(types, ramp, output_dir, current_version: version)
      renderer.render

      success "FSDD docs generated: #{output_dir}"
      info "  #{types.size} type pages + index.html + style.css"
    end

    private def read_shard_version(repo : String) : String?
      shard_path = File.join(repo, "shard.yml")
      return nil unless File.exists?(shard_path)
      File.read(shard_path).each_line do |line|
        if line.starts_with?("version:")
          parts = line.split(":", 2)
          return parts[1].strip if parts.size == 2
        end
      end
      nil
    end

    private def generate_crystal_docs(repo : String, json_dir : String, json_path : String) : Nil
      info "Running crystal docs in #{repo}..."
      Dir.mkdir_p(json_dir)

      result = Process.run(
        "crystal",
        ["docs", "--output=#{json_dir}"],
        chdir: repo,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )

      unless result.success?
        error "crystal docs failed (exit #{result.exit_code})"
        exit(1)
      end

      unless File.exists?(json_path)
        error "crystal docs did not produce index.json at #{json_path}"
        exit(1)
      end

      success "crystal docs complete: #{json_path}"
    end

    private def update_versions_json(fsdd_docs_dir : String, version : String) : Nil
      versions_path = File.join(fsdd_docs_dir, "versions.json")
      Dir.mkdir_p(fsdd_docs_dir)

      versions = if File.exists?(versions_path)
        JSON.parse(File.read(versions_path)).as_a.map(&.as_s)
      else
        [] of String
      end

      unless versions.includes?(version)
        versions << version
        File.write(versions_path, versions.to_json)
        info "Updated versions.json: #{versions.inspect}"
      end
    end
  end
end

AmberCLI::Core::CommandRegistry.register("docs:fsdd", ["fsdd-docs"], AmberCLI::Commands::DocsFSDDCommand)
