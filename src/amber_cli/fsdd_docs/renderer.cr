require "ecr"
require "html"
require "./parser"
require "./version_ramp"

module AmberCLI::FSDDDocs
  CSS_CONTENT = <<-CSS
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body { font: 15px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; color: #24292f; background: #f6f8fa; }
    a { color: #0969da; }
    a:hover { text-decoration: underline; }
    code, pre { font-family: "SFMono-Regular",Consolas,monospace; }
    nav { background: #24292f; color: #e6edf3; padding: 12px 24px; display: flex; align-items: center; gap: 16px; flex-wrap: wrap; }
    nav .nav-title { font-size: 1.1rem; font-weight: 600; }
    nav a { color: #79c0ff; text-decoration: none; }
    nav a:hover { text-decoration: underline; }
    .ver { background: #388bfd; color: #fff; padding: 2px 8px; border-radius: 10px; font-size: .8rem; font-weight: 600; }
    main { max-width: 960px; margin: 0 auto; padding: 24px; }
    h2 { font-size: 1rem; border-bottom: 1px solid #d0d7de; padding-bottom: 6px; margin: 20px 0 12px; }
    .badge { display: inline-block; padding: 2px 7px; border-radius: 4px; font-size: .72rem; font-weight: 700; text-transform: uppercase; }
    .badge.class { background: #ddf4ff; color: #0550ae; }
    .badge.module { background: #fff8c5; color: #9a6700; }
    .badge.struct { background: #ffd8d3; color: #82071e; }
    .badge.enum { background: #e8d5ff; color: #6e40c9; }
    .type-list { list-style: none; }
    .type-item { background: #fff; border: 1px solid #d0d7de; border-radius: 6px; padding: 10px 14px; margin-bottom: 8px; }
    .type-link { display: flex; align-items: center; gap: 8px; text-decoration: none; color: #0969da; font-weight: 600; }
    .type-link .type-name { font-weight: 600; }
    .type-link:hover .type-name { text-decoration: underline; }
    .summary { font-size: .85rem; color: #57606a; margin-top: 4px; }
    .fsdd-marker { font-size: .7rem; font-weight: 700; color: #0969da; background: #ddf4ff; padding: 1px 5px; border-radius: 3px; text-transform: uppercase; }
    .ramp { display: flex; gap: 14px; align-items: center; background: #f0f7ff; border: 1px solid #cce5ff; border-radius: 6px; padding: 7px 14px; margin: 14px 0; font-size: .85rem; flex-wrap: wrap; }
    .sym { font-size: 1rem; font-weight: 700; color: #0969da; }
    .fsdd { background: #f6f8fa; border: 1px solid #d0d7de; border-radius: 6px; padding: 10px 14px; margin: 12px 0; }
    .fsdd-row { display: flex; gap: 10px; margin: 3px 0; font-size: .875rem; align-items: baseline; }
    .lbl { font-weight: 600; color: #57606a; min-width: 70px; flex-shrink: 0; }
    .story-block { margin-top: 8px; padding-top: 8px; border-top: 1px solid #d0d7de; font-style: italic; font-size: .875rem; white-space: pre-wrap; }
    .method { background: #fff; border: 1px solid #d0d7de; border-radius: 6px; padding: 10px 14px; margin-bottom: 10px; }
    .msig { display: flex; align-items: baseline; gap: 8px; flex-wrap: wrap; margin-bottom: 4px; }
    .mkind { font-size: .7rem; font-weight: 700; text-transform: uppercase; color: #57606a; background: #f6f8fa; padding: 2px 5px; border-radius: 3px; border: 1px solid #d0d7de; }
    .mname { font-family: "SFMono-Regular",Consolas,monospace; font-size: .9rem; color: #0969da; background: #f6f8fa; padding: 2px 6px; border-radius: 3px; }
    .mloc { font-size: .75rem; color: #57606a; margin: 4px 0; }
    CSS

  class IndexView
    getter types : Array(ParsedType)
    getter ramp : VersionRamp
    getter current_version : String?

    def initialize(@types : Array(ParsedType), @ramp : VersionRamp, @current_version : String?)
    end

    ECR.def_to_s "#{__DIR__}/templates/index.ecr"
  end

  class TypeView
    getter type : ParsedType
    getter ramp : VersionRamp
    getter current_version : String?

    def initialize(@type : ParsedType, @ramp : VersionRamp, @current_version : String?)
    end

    ECR.def_to_s "#{__DIR__}/templates/type_page.ecr"
  end

  class Renderer
    def initialize(
      @types : Array(ParsedType),
      @ramp : VersionRamp,
      @output_dir : String,
      @current_version : String? = nil
    )
    end

    def render : Nil
      Dir.mkdir_p(@output_dir)
      File.write(File.join(@output_dir, "style.css"), CSS_CONTENT)
      render_index
      @types.each { |t| render_type(t) }
    end

    private def render_index : Nil
      html = IndexView.new(@types, @ramp, @current_version).to_s
      File.write(File.join(@output_dir, "index.html"), html)
    end

    private def render_type(type : ParsedType) : Nil
      html = TypeView.new(type, @ramp, @current_version).to_s
      File.write(File.join(@output_dir, "#{type.slug}.html"), html)
    end
  end
end
