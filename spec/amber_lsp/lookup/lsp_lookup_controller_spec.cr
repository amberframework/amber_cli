require "../spec_helper"
require "../../../src/amber_lsp/lookup/normalize_crystal_docs"

describe AmberLSP::Controller do
  it "shows a receiver-resolved return type in hover markdown" do
    with_lsp_lookup_project do |project, service|
      fixture_path = File.join(Dir.current, "spec", "fixtures", "api_lookup", "crystal_docs_return_types.json")
      layer = AmberLSP::Lookup::NormalizeCrystalDocs.new(
        File.read(fixture_path),
        project,
        "project",
        "fixture_return_types",
        "fixture-key",
        [] of String,
      ).perform
      service.seed(project, [AmberLSP::Lookup::CachedAPIIndexLayer.new(layer, "fresh")])

      source_path = File.join(project, "src", "models", "user.cr")
      File.write(source_path, "FixtureTypes::Post.find\n")
      uri = "file://#{source_path}"
      controller = AmberLSP::Controller.new(service)
      server = AmberLSP::Server.new(IO::Memory.new, IO::Memory.new)
      initialize_lookup_controller(controller, server, project)
      response = controller.handle(
        lsp_lookup_request(7, "textDocument/hover", {
          "textDocument" => {"uri" => uri},
          "position"     => {"line" => 0, "character" => 21},
        }),
        server,
      ) || raise "Expected receiver-resolved hover response"
      hover_response = AmberLSP::Lookup::LSPHoverResponse.from_json(response)
      hover = hover_response.result || raise "Expected hover contents"

      hover.contents.markdown_value.should contain(
        "FixtureTypes::ClassMethods.find(id : Int64) : FixtureTypes::Post | Nil (declared: self?) (class method via extend)",
      )
    end
  end

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

      extension_workspace_response = controller.handle(
        lsp_lookup_request(6, "workspace/symbol", {"query" => "FixtureAPI::Team.where"}),
        server,
      )
      extension_workspace_json = extension_workspace_response || raise "Expected extended method symbol response"
      extension_workspace = AmberLSP::Lookup::LSPWorkspaceSymbolResponse.from_json(extension_workspace_json)
      extension_workspace_symbol = extension_workspace.list_of_workspace_symbols.first? ||
                                   raise "Expected an extended method workspace symbol"
      extension_workspace_symbol.symbol_name.should eq(
        "FixtureAPI::QueryMethods.where(field : String) (class method via extend)",
      )

      hover_value = hover_json["result"]["contents"]["value"].as_s
      hover_value.should contain("FixtureAPI::User#id() : Int64 | Nil")
      hover_value.should contain("The user's primary key.")
      hover_value.should contain("Layer: fixture_project")
      hover_value.should contain("Freshness: fresh")
      hover_value.should contain("The ID getter is generated from the persisted table column.")

      class_hover_response = controller.handle(
        lsp_lookup_request(4, "textDocument/hover", {
          "textDocument" => {"uri" => uri},
          "position"     => {"line" => 1, "character" => 21},
        }),
        server,
      )
      class_hover_json = class_hover_response || raise "Expected class method hover response"
      class_hover = AmberLSP::Lookup::LSPHoverResponse.from_json(class_hover_json)
      class_hover_result = class_hover.result || raise "Expected class method hover contents"
      class_hover_value = class_hover_result.contents.markdown_value
      class_hover_value.should contain("FixtureAPI::User.count() : Int32")

      extension_hover_response = controller.handle(
        lsp_lookup_request(5, "textDocument/hover", {
          "textDocument" => {"uri" => uri},
          "position"     => {"line" => 2, "character" => 21},
        }),
        server,
      )
      extension_hover_json = extension_hover_response || raise "Expected extended method hover response"
      extension_hover = AmberLSP::Lookup::LSPHoverResponse.from_json(extension_hover_json)
      extension_hover_result = extension_hover.result || raise "Expected extended method hover contents"
      extension_hover_value = extension_hover_result.contents.markdown_value
      extension_hover_value.should contain("FixtureAPI::QueryMethods.where(field : String) : Query (class method via extend)")

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
    File.write(
      File.join(source_root, "user.cr"),
      "FixtureAPI::User#id\nFixtureAPI::User.count\nFixtureAPI::Team.where\n",
    )
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
