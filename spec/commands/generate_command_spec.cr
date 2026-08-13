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

  it "generates a database-backed ECR scaffold that is ready to migrate" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")
      Dir.mkdir_p("config")
      File.write("config/routes.cr", <<-CRYSTAL)
      Amber::Server.configure do |app|
        routes :web do
        end
      end
      CRYSTAL

      command = AmberCLI::Commands::GenerateCommand.new("generate")
      command.parse_and_execute([
        "scaffold",
        "Pet",
        "name:string:required",
        "species:string:required",
        "adopted:bool",
      ])

      File.read("src/models/pet.cr").should contain("class Pet < Grant::Base")
      File.read("src/models/pet.cr").should contain("column adopted : Bool?")

      migration = Dir.glob("db/migrations/*_create_pets.sql").first
      File.read(migration).should contain("-- +micrate Up")
      File.read(migration).should contain("CREATE TABLE IF NOT EXISTS pets")
      File.read(migration).should contain("-- +micrate Down")

      File.read("config/routes.cr").should contain(%(resources "/pets", PetController))
      schema = File.read("src/schemas/pet_schema.cr")
      schema.should contain(%(content_type "application/x-www-form-urlencoded"))

      controller = File.read("src/controllers/pet_controller.cr")
      controller.should contain("schema :create, PetSchema")
      controller.should contain("schema :update, PetSchema")
      controller.should contain("validated_as(PetSchema)")
      controller.should contain("schema.adopted")
      controller.should_not contain("schema.adopted.not_nil!")
      controller.should contain("handle_schema_validation_failure")
      controller.should contain(%(context.content = render("new.ecr")))
      controller.should_not contain("PetSchema.new(merge_request_data)")
      File.read("src/views/pet/new.ecr").should contain(%(render(partial: "_form.ecr")))
      File.read("src/views/pet/_form.ecr").should contain(%(hidden_field("_method", "PATCH")))
      File.read("src/views/pet/_form.ecr").should contain(%(checkbox("adopted", checked: @pet.adopted? || false, value: "true")))
    end
  end

  it "generates schemas with the executable controller contract as the primary path" do
    SpecHelper.within_temp_directory do
      command = AmberCLI::Commands::GenerateCommand.new("generate")
      command.parse_and_execute(["schema", "Post", "title:string:required"])

      schema = File.read("src/schemas/post_schema.cr")
      schema.should contain("schema :create, PostSchema")
      schema.should contain("validated_as(PostSchema)")
      schema.should_not contain("PostSchema.new(data)")

      spec = File.read("spec/schemas/post_schema_spec.cr")
      spec.should contain("PostSchema.new(data)")
    end
  end

  it "generates API writes with automatically enforced JSON schemas" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

      command = AmberCLI::Commands::GenerateCommand.new("generate")
      command.parse_and_execute([
        "api",
        "Pet",
        "name:string:required",
        "adopted:bool",
      ])

      schema = File.read("src/schemas/pet_schema.cr")
      schema.should contain(%(content_type "application/json"))

      controller = File.read("src/controllers/api/pet_controller.cr")
      controller.should contain("schema :create, PetSchema")
      controller.should contain("schema :update, PetSchema")
      controller.should contain("validated_as(PetSchema)")
      controller.should_not contain("PetSchema.new(merge_request_data)")
    end
  end

  it "adds scaffold routes to Windows-style route files" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")
      Dir.mkdir_p("config")
      File.write("config/routes.cr", "Amber::Server.configure do |app|\r\n  routes :web do\r\n  end\r\nend\r\n")

      command = AmberCLI::Commands::GenerateCommand.new("generate")
      command.parse_and_execute([
        "scaffold",
        "Pet",
        "name:string:required",
      ])

      routes = File.read("config/routes.cr")
      routes.should contain("  routes :web do\r\n    resources \"/pets\", PetController\r\n")
    end
  end
end
