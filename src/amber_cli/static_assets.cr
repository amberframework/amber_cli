require "asset_pipeline/static_assets"

module AmberCLI
  # Shared, convention-based access to a web application's authored and
  # compiled static assets. Keeping this outside the command class lets project
  # generation and watch mode use the compiler in-process instead of spawning a
  # second CLI executable.
  module StaticAssets
    SOURCE_ROOT   = Path["app/assets"]
    OUTPUT_ROOT   = Path["public/assets"]
    PUBLIC_PATH   = "/assets"
    MANIFEST_NAME = "manifest.json"

    def self.compiler(project_root : Path | String = Path["."]) : AssetPipeline::StaticAssets::Compiler
      root = Path[project_root.to_s].expand.normalize
      AssetPipeline::StaticAssets::Compiler.new(
        source_root: root.join(SOURCE_ROOT),
        output_root: root.join(OUTPUT_ROOT),
        public_path: PUBLIC_PATH,
        manifest_name: MANIFEST_NAME
      )
    end

    def self.build(project_root : Path | String = Path["."]) : AssetPipeline::StaticAssets::Manifest
      compiler(project_root).build
    end

    def self.check(project_root : Path | String = Path["."]) : AssetPipeline::StaticAssets::Manifest
      root = Path[project_root.to_s].expand.normalize
      AssetPipeline::StaticAssets::Compiler.check(
        output_root: root.join(OUTPUT_ROOT),
        manifest_name: MANIFEST_NAME
      )
    end
  end
end
