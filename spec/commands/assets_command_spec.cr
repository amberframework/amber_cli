require "../amber_cli_spec"
require "../../src/amber_cli/commands/assets"

describe AmberCLI::Commands::AssetsCommand do
  it "builds and verifies a convention-based application asset tree" do
    SpecHelper.within_temp_directory do
      Dir.mkdir_p("app/assets/stylesheets")
      Dir.mkdir_p("app/assets/images")
      File.write("app/assets/images/mark.svg", %(<svg xmlns="http://www.w3.org/2000/svg"/>))
      File.write("app/assets/stylesheets/app.css", %(.mark { background: url("../images/mark.svg"); }))

      AmberCLI::Commands::AssetsCommand.new("assets").parse_and_execute(["build"])
      manifest = AssetPipeline::StaticAssets::Manifest.load("public/assets/manifest.json")
      manifest.assets.keys.sort.should eq(["images/mark.svg", "stylesheets/app.css"])

      AmberCLI::Commands::AssetsCommand.new("assets").parse_and_execute(["check"])

      css_path = Path["public"].join(manifest.path("stylesheets/app.css").lchop('/'))
      File.write(css_path, "tampered")
      expect_raises(AssetPipeline::StaticAssets::VerificationError) do
        AmberCLI::StaticAssets.check
      end
    end
  end
end
