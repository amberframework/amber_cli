require "../amber_cli_spec"
require "../../src/amber_cli/commands/build"

private def with_crystal_compiler(compiler : String, &)
  original_compiler = ENV["CRYSTAL"]?
  ENV["CRYSTAL"] = compiler
  begin
    yield
  ensure
    ENV["CRYSTAL"] = original_compiler
  end
end

private def write_app_files(amber_yml : String? = nil)
  File.write("shard.yml", <<-YAML)
    name: shop
    version: 0.1.0
    targets:
      shop:
        main: src/shop.cr
    YAML
  File.write(".amber.yml", amber_yml) if amber_yml
end

private def parsed_build_command(list_of_arguments : Array(String)) : AmberCLI::Commands::BuildCommand
  command = AmberCLI::Commands::BuildCommand.new("build")
  command.option_parser.parse(list_of_arguments)
  command
end

describe AmberCLI::TargetTier do
  describe "TARGET_TIERS" do
    it "lists portable first and every named tier the CLI supports" do
      AmberCLI::TARGET_TIERS.map(&.tier_name).should eq([
        "portable", "x86-64-v2", "x86-64-v3", "x86-64-v4",
        "neoverse-v1", "neoverse-n2", "neoverse-v2", "apple-m1", "apple-m4",
      ])
    end

    it "gives each tier a unique name and a one-line description" do
      list_of_names = AmberCLI::TARGET_TIERS.map(&.tier_name)
      list_of_names.uniq.size.should eq(list_of_names.size)
      AmberCLI::TARGET_TIERS.each do |tier|
        tier.description.should_not be_empty
        tier.description.should_not contain('\n')
      end
    end

    it "keeps the portable tier on crystal-alpha's default target" do
      portable = AmberCLI.find_target_tier!("portable")
      portable.portable?.should be_true
      portable.list_of_compiler_flags.should be_empty
      portable.builds_on?("x86_64").should be_true
      portable.builds_on?("aarch64").should be_true
    end

    it "maps each named tier to its LLVM CPU and architecture" do
      expected = {
        "x86-64-v2"   => {"x86_64", "x86-64-v2"},
        "x86-64-v3"   => {"x86_64", "x86-64-v3"},
        "x86-64-v4"   => {"x86_64", "x86-64-v4"},
        "neoverse-v1" => {"aarch64", "neoverse-v1"},
        "neoverse-n2" => {"aarch64", "neoverse-n2"},
        "neoverse-v2" => {"aarch64", "neoverse-v2"},
        "apple-m1"    => {"aarch64", "apple-m1"},
        "apple-m4"    => {"aarch64", "apple-m4"},
      }
      expected.each do |tier_name, (architecture, cpu_name)|
        tier = AmberCLI.find_target_tier!(tier_name)
        tier.architecture.should eq(architecture)
        tier.list_of_compiler_flags.should eq(["--mcpu", cpu_name])
      end
    end
  end

  describe ".find_target_tier!" do
    it "names every valid tier when the tier is unknown" do
      error = expect_raises(AmberCLI::UnknownTargetTierError) do
        AmberCLI.find_target_tier!("pentium-pro")
      end
      message = error.message.to_s
      message.should contain("Unknown target tier 'pentium-pro'")
      AmberCLI::TARGET_TIERS.each { |tier| message.should contain(tier.tier_name) }
    end
  end

  describe ".target_tier_table" do
    it "prints one line per tier with its flags and description" do
      table = AmberCLI.target_tier_table
      AmberCLI::TARGET_TIERS.each do |tier|
        table.should contain(tier.tier_name)
        table.should contain(tier.description)
      end
      table.should contain("--mcpu x86-64-v3")
      table.should contain("(default target)")
    end
  end
end

describe AmberCLI::Commands::BuildCommand do
  describe "option parsing" do
    it "reads --target-tier, -t, --list-target-tiers and --dry-run" do
      parsed_build_command(["--target-tier", "x86-64-v3"]).target_tier_name.should eq("x86-64-v3")
      parsed_build_command(["--target-tier=apple-m1"]).target_tier_name.should eq("apple-m1")
      parsed_build_command(["-t", "neoverse-n2"]).target_tier_name.should eq("neoverse-n2")
      parsed_build_command(["--list-target-tiers"]).list_target_tiers?.should be_true
      parsed_build_command(["--dry-run"]).dry_run?.should be_true
      parsed_build_command([] of String).target_tier_name.should be_nil
    end
  end

  describe "#selected_target_tier" do
    it "defaults to portable" do
      SpecHelper.within_temp_directory do
        write_app_files
        parsed_build_command([] of String).selected_target_tier("aarch64").tier_name.should eq("portable")
      end
    end

    it "reads build.target_tier from .amber.yml" do
      SpecHelper.within_temp_directory do
        write_app_files("app: shop\nbuild:\n  target_tier: x86-64-v3\n")
        parsed_build_command([] of String).selected_target_tier("x86_64").tier_name.should eq("x86-64-v3")
      end
    end

    it "lets --target-tier win over .amber.yml" do
      SpecHelper.within_temp_directory do
        write_app_files("app: shop\nbuild:\n  target_tier: x86-64-v3\n")
        parsed_build_command(["--target-tier", "x86-64-v4"]).selected_target_tier("x86_64").tier_name.should eq("x86-64-v4")
      end
    end

    it "rejects an unknown tier and lists the valid ones" do
      SpecHelper.within_temp_directory do
        write_app_files
        error = expect_raises(AmberCLI::UnknownTargetTierError) do
          parsed_build_command(["--target-tier", "graviton9"]).selected_target_tier("aarch64")
        end
        error.message.to_s.should contain("Valid tiers: portable, x86-64-v2, x86-64-v3, x86-64-v4, neoverse-v1, neoverse-n2, neoverse-v2, apple-m1, apple-m4")
      end
    end

    it "rejects a tier for another architecture than this machine" do
      SpecHelper.within_temp_directory do
        write_app_files
        error = expect_raises(AmberCLI::TargetTierArchitectureError) do
          parsed_build_command(["--target-tier", "x86-64-v3"]).selected_target_tier("aarch64")
        end
        error.message.to_s.should contain("is for x86_64 machines and this machine is aarch64")
      end
    end
  end

  describe "#compiler_arguments" do
    it "builds the first shard.yml target into bin/ with the exact crystal-alpha command line per tier" do
      with_crystal_compiler("crystal-alpha") do
        SpecHelper.within_temp_directory do
          write_app_files
          command = parsed_build_command([] of String)
          command.compiler_command.should eq("crystal-alpha")

          expected = {
            "portable"    => %w[build src/shop.cr -o bin/shop --release],
            "x86-64-v2"   => %w[build src/shop.cr -o bin/shop --release --mcpu x86-64-v2],
            "x86-64-v3"   => %w[build src/shop.cr -o bin/shop --release --mcpu x86-64-v3],
            "x86-64-v4"   => %w[build src/shop.cr -o bin/shop --release --mcpu x86-64-v4],
            "neoverse-v1" => %w[build src/shop.cr -o bin/shop --release --mcpu neoverse-v1],
            "neoverse-n2" => %w[build src/shop.cr -o bin/shop --release --mcpu neoverse-n2],
            "neoverse-v2" => %w[build src/shop.cr -o bin/shop --release --mcpu neoverse-v2],
            "apple-m1"    => %w[build src/shop.cr -o bin/shop --release --mcpu apple-m1],
            "apple-m4"    => %w[build src/shop.cr -o bin/shop --release --mcpu apple-m4],
          }
          expected.size.should eq(AmberCLI::TARGET_TIERS.size)
          expected.each do |tier_name, list_of_arguments|
            command.compiler_arguments(AmberCLI.find_target_tier!(tier_name)).should eq(list_of_arguments)
          end
        end
      end
    end

    it "falls back to src/<name>.cr when shard.yml has no targets" do
      SpecHelper.within_temp_directory do
        File.write("shard.yml", "name: shop\nversion: 0.1.0\n")
        command = parsed_build_command([] of String)
        command.entry_point.should eq("src/shop.cr")
        command.output_path.should eq("bin/shop")
      end
    end
  end

  it "is registered as `amber build` and `amber b`" do
    AmberCLI::Core::CommandRegistry.find_command("build").should eq(AmberCLI::Commands::BuildCommand)
    AmberCLI::Core::CommandRegistry.find_command("b").should eq(AmberCLI::Commands::BuildCommand)
  end
end
