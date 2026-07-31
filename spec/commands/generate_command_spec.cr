require "../amber_cli_spec"
require "../../src/amber_cli/commands/generate"

describe AmberCLI::Commands::GenerateCommand do
  it "uses ECR and does not double-pluralize controller route guidance" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\n")

      command = AmberCLI::Commands::GenerateCommand.new("generate")
      command.parse_and_execute(["controller", "Posts", "index", "show"])

      File.exists?("src/views/posts/index.ecr").should be_true
      spec = File.read("spec/controllers/posts_controller_spec.cr")
      spec.should contain("GET /posts")
      spec.should contain("GET /posts/1")
      spec.should_not contain("postses")
    end
  end

  it "generates mailer ECR rendering against the Amber V2 mailer API" do
    SpecHelper.within_temp_directory do
      command = AmberCLI::Commands::GenerateCommand.new("generate")
      command.parse_and_execute(["mailer", "Digest", "--actions=weekly"])

      mailer = File.read("src/mailers/digest_mailer.cr")
      mailer.should contain(%(ECR.render("src/views/digest_mailer/weekly.ecr")))
      mailer.should_not contain("    render(\"src/views")
      File.exists?("src/views/digest_mailer/weekly.ecr").should be_true
    end
  end
end
