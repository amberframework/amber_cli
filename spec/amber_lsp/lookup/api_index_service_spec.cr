require "../spec_helper"

require "../../../src/amber_lsp/lookup/api_index_service"
require "../../../src/amber_lsp/lookup/normalize_crystal_docs"

describe AmberLSP::Lookup::APIIndexService do
  it "keeps an invalidated background build from replacing a newer index" do
    with_tempdir do |project|
      fixture_path = File.join(Dir.current, "spec", "fixtures", "api_lookup", "crystal_docs_small.json")
      layer = AmberLSP::Lookup::NormalizeCrystalDocs.new(
        File.read(fixture_path),
        project,
        "project",
        "fixture_project",
        "fixture-key",
        [] of String,
      ).perform
      stale_layer = AmberLSP::Lookup::CachedAPIIndexLayer.new(layer, "stale")
      fresh_layer = AmberLSP::Lookup::CachedAPIIndexLayer.new(layer, "fresh")
      build_started = Channel(Int32).new(2)
      release_stale_build = Channel(Nil).new(1)
      release_fresh_build = Channel(Nil).new(1)
      build_count = 0
      layer_builder = ->(_root : String) {
        build_count += 1
        current_build = build_count
        build_started.send(current_build)
        if current_build == 1
          release_stale_build.receive
          [stale_layer]
        else
          release_fresh_build.receive
          [fresh_layer]
        end
      }
      service = AmberLSP::Lookup::APIIndexService.new(File.join(project, ".cache"), layer_builder)

      service.layers_for(project).should be_nil
      build_started.receive.should eq(1)
      service.invalidate(project)
      service.layers_for(project).should be_nil
      build_started.receive.should eq(2)

      release_fresh_build.send(nil)
      100.times do
        break if service.layers_for(project)
        Fiber.yield
      end
      service.layers_for(project).try(&.first.freshness).should eq("fresh")

      release_stale_build.send(nil)
      Fiber.yield
      service.layers_for(project).try(&.first.freshness).should eq("fresh")
    end
  end
end
