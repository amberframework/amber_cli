require "../spec_helper"
require "../../../src/amber_lsp/lookup/normalize_crystal_docs"

describe AmberLSP::Controller do
  it "serves workspace symbols, hover, and definitions through the controller" do
    with_lsp_lookup_project do |project, service|
      controller = AmberLSP::Controller.new(service)
      server = AmberLSP::Server.new(IO::Memory.new, IO::Memory.new)
      initialize_lookup_controller(controller, server, project)
      uri = "file://#{File.join(project, "src", "models", "user.cr")}"

      workspace_response = controller.handle(
        lsp_lookup_request(1, "workspace/symbol", {"query" => "FixtureAPI::User#id"}),
        server,
      )
      workspace_json = JSON.parse(workspace_response.not_nil!)

      hover_response = controller.handle(
        lsp_lookup_request(2, "textDocument/hover", {
          "textDocument" => {"uri" => uri},
          "position"     => {"line" => 0, "character" => 18},
        }),
        server,
      )
      hover_json = JSON.parse(hover_response.not_nil!)

      definition_response = controller.handle(
        lsp_lookup_request(3, "textDocument/definition", {
          "textDocument" => {"uri" => uri},
          "position"     => {"line" => 0, "character" => 18},
        }),
        server,
      )
      definition_json = JSON.parse(definition_response.not_nil!)

      workspace_json["result"].as_a.size.should eq(1)
      workspace_symbol = workspace_json["result"].as_a.first
      workspace_symbol["name"].as_s.should eq("FixtureAPI::User#id()")
      workspace_symbol["data"]["freshness"].as_s.should eq("fresh")

      hover_value = hover_json["result"]["contents"]["value"].as_s
      hover_value.should contain("FixtureAPI::User#id() : Int64 | Nil")
      hover_value.should contain("The user's primary key.")
      hover_value.should contain("Layer: fixture_project")
      hover_value.should contain("Freshness: fresh")
      hover_value.should contain("The ID getter is generated from the persisted table column.")

      definition_json["result"].as_a.first["uri"].as_s.should eq("file://#{File.join(project, "src", "models", "user.cr")}")
      definition_json["result"].as_a.first["range"]["start"]["line"].as_i.should eq(11)
    end
  end

  it "returns unavailable hover data while the index builds in a background fiber" do
    with_lsp_lookup_project do |project, _service|
      fixture_path = File.join(Dir.current, "spec", "fixtures", "api_lookup", "crystal_docs_small.json")
      layer = AmberLSP::Lookup::NormalizeCrystalDocs.new(
        File.read(fixture_path),
        project,
        "project",
        "fixture_project",
        "fixture-key",
        [] of String,
      ).perform
      cached_layer = AmberLSP::Lookup::CachedAPIIndexLayer.new(layer, "fresh")
      build_started = Channel(Nil).new(1)
      release_build = Channel(Nil).new(1)
      layer_builder = ->(_root : String) {
        build_started.send(nil)
        release_build.receive
        [cached_layer]
      }
      service = AmberLSP::Lookup::APIIndexService.new(
        File.join(project, ".cache"),
        layer_builder,
      )
      controller = AmberLSP::Controller.new(service)
      server = AmberLSP::Server.new(IO::Memory.new, IO::Memory.new)
      initialize_lookup_controller(controller, server, project)
      uri = "file://#{File.join(project, "src", "models", "user.cr")}"

      response = controller.handle(
        lsp_lookup_request(1, "textDocument/hover", {
          "textDocument" => {"uri" => uri},
          "position"     => {"line" => 0, "character" => 18},
        }),
        server,
      )
      hover_value = JSON.parse(response.not_nil!)["result"]["contents"]["value"].as_s
      hover_value.should contain("API index unavailable")
      hover_value.should contain("Freshness: unavailable")

      build_started.receive
      release_build.send(nil)
      100.times do
        break if service.layers_for(project)
        Fiber.yield
      end
      service.layers_for(project).should_not be_nil
    end
  end
end

private def initialize_lookup_controller(
  controller : AmberLSP::Controller,
  server : AmberLSP::Server,
  project : String,
) : Nil
  request = lsp_lookup_request(0, "initialize", {"rootUri" => "file://#{project}"})
  controller.handle(request, server).should_not be_nil
end

private def lsp_lookup_request(id : Int32, method : String, params) : String
  {"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params}.to_json
end

private def with_lsp_lookup_project(&)
  with_tempdir do |project|
    source_root = File.join(project, "src", "models")
    api_card_root = File.join(project, ".amber-lsp", "api")
    Dir.mkdir_p(source_root)
    Dir.mkdir_p(api_card_root)
    File.write(File.join(project, "shard.yml"), "name: fixture_project\nversion: 1.5.0\n")
    File.write(File.join(source_root, "user.cr"), "FixtureAPI::User#id\n")
    card_fixture = File.join(Dir.current, "spec", "fixtures", "api_lookup", "cards", "project", ".amber-lsp")
    FileUtils.cp_r(card_fixture, project)

    fixture_path = File.join(Dir.current, "spec", "fixtures", "api_lookup", "crystal_docs_small.json")
    layer = AmberLSP::Lookup::NormalizeCrystalDocs.new(
      File.read(fixture_path),
      project,
      "project",
      "fixture_project",
      "fixture-key",
      [] of String,
    ).perform
    service = AmberLSP::Lookup::APIIndexService.new(File.join(project, ".cache"))
    service.seed(project, [AmberLSP::Lookup::CachedAPIIndexLayer.new(layer, "fresh")])
    yield project, service
  end
end
