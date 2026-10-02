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

  it "lists scaffold and API records newest first with an explicit order" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

      AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Pet", "name:string"])
      AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["api", "Toy", "name:string"])

      File.read("src/controllers/pet_controller.cr").should contain("Pet.order(id: :desc).to_a")
      File.read("src/controllers/pet_controller.cr").should_not contain("Pet.all.to_a")
      File.read("src/controllers/api/toy_controller.cr").should contain("Toy.order(id: :desc).to_a")
      File.read("src/controllers/api/toy_controller.cr").should_not contain("Toy.all.to_a")
    end
  end

  it "generates a belongs_to and a foreign key for reference fields" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

      command = AmberCLI::Commands::GenerateCommand.new("generate")
      command.parse_and_execute(["scaffold", "Comment", "post:reference", "body:text"])

      model = File.read("src/models/comment.cr")
      model.should contain("belongs_to :post")
      model.should_not contain("column post ")
      model.should_not contain("column post_id")

      migration = File.read(Dir.glob("db/migrations/*_create_comments.sql").first)
      migration.should contain("post_id BIGINT")

      File.read("src/schemas/comment_schema.cr").should contain("field :post_id, Int64")
      File.read("src/controllers/comment_controller.cr").should contain("comment.post_id = schema.post_id")
      form = File.read("src/views/comment/_form.ecr")
      form.should contain(%(number_field("post_id", value: @comment.post_id?)))
      form.should_not contain(%(text_field("post")))

      spec = File.read("spec/controllers/comment_controller_spec.cr")
      spec.should contain("def create_parent_post : Post")
      spec.should contain("saved.post_id = create_parent_post.id")
    end
  end

  it "fills required parent columns in reference specs from the parent model" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

      AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Post", "title:string:required"])
      AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Comment", "post:reference"])

      File.read("spec/controllers/comment_controller_spec.cr").should contain(%(parent.title = "Sample"))
    end
  end

  it "responds from API controllers with respond_with and routes them under /api" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")
      Dir.mkdir_p("config")
      File.write("config/routes.cr", <<-CRYSTAL)
      Amber::Server.configure do
        routes :web do
        end

        # routes :api do
        # end

        routes :static do
          get "/*", Amber::Controller::Static, :index
        end
      end
      CRYSTAL

      command = AmberCLI::Commands::GenerateCommand.new("generate")
      command.parse_and_execute(["api", "Product", "name:string"])

      controller = File.read("src/controllers/api/product_controller.cr")
      controller.should_not contain("render json:")
      controller.should contain("respond_with { json products.to_json }")
      controller.should contain("respond_with(201) { json product.to_json }")
      controller.should contain("respond_with(404)")

      routes = File.read("config/routes.cr")
      routes.should contain(%(routes :api, "/api" do))
      routes.should contain(%(resources "/products", Api::ProductController, except: [:new, :edit]))
      # The wildcard static route must come last.
      (routes.index!(%(routes :api, "/api")) < routes.index!("routes :static")).should be_true

      spec = File.read("spec/controllers/api_product_controller_spec.cr")
      spec.should contain(%(post_json("/api/products", {name: "Sample"})))
      spec.should contain("assert_response_status(response, 201)")
    end
  end

  it "generates exercised write specs that send a CSRF token" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

      command = AmberCLI::Commands::GenerateCommand.new("generate")
      command.parse_and_execute(["scaffold", "Pet", "name:string"])

      spec = File.read("spec/controllers/pet_controller_spec.cr")
      spec.should contain(%(require "../support/csrf_helpers"))
      spec.should contain(%(csrf_headers("/pets/new")))
      spec.should contain("post(\"/pets\", body:")
      spec.should contain("put(\"/pets/\#{saved.id}\", body:")
      spec.should contain(%(delete("/pets/\#{saved.id}", headers: headers)))
      spec.should contain("assert_response_status(response, 403)")
      spec.should_not contain("# assert_response")

      helpers = File.read("spec/support/csrf_helpers.cr")
      helpers.should contain("X-CSRF-TOKEN")
      helpers.should contain(%(name="_csrf"))
    end
  end

  it "generates an authentication system with a working model, views, and routes" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")
      Dir.mkdir_p("config")
      File.write("config/routes.cr", "Amber::Server.configure do\n  routes :web do\n  end\nend\n")

      command = AmberCLI::Commands::GenerateCommand.new("generate")
      command.parse_and_execute(["auth"])

      model = File.read("src/models/user.cr")
      model.should contain(%(require "crypto/bcrypt/password"))
      model.should contain("column password_digest : String?")
      model.should contain("def password=(value : String)")
      model.should contain("def self.authenticate(email : String?, password : String?) : User?")
      model.should contain("Crypto::Bcrypt::Password.create(value)")

      migration = File.read(Dir.glob("db/migrations/*_create_users.sql").first)
      migration.should contain("email VARCHAR(255) NOT NULL")
      migration.should contain("password_digest VARCHAR(255) NOT NULL")
      migration.should_not contain("hashed_password")

      File.read("src/controllers/session_controller.cr").should contain("User.authenticate(")
      File.read("src/controllers/registration_controller.cr").should contain("user.password = password")
      ["src/views/session/new.ecr", "src/views/registration/new.ecr"].each do |view|
        contents = File.read(view)
        contents.should contain("<form ")
        contents.should contain("<%= csrf_tag %>")
        contents.should_not contain("form_for")
        contents.should_not contain("{ %>")
      end

      File.exists?("spec/models/user_spec.cr").should be_true
      File.read("spec/controllers/authentication_controller_spec.cr").should contain("csrf_headers")

      routes = File.read("config/routes.cr")
      routes.should contain(%(post "/register", RegistrationController, :create))
      routes.should contain(%(delete "/session", SessionController, :destroy))
    end
  end

  it "names the authentication model after the argument when one is given" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

      command = AmberCLI::Commands::GenerateCommand.new("generate")
      command.parse_and_execute(["auth", "Member"])

      File.read("src/models/member.cr").should contain("class Member < Grant::Base")
      File.read("src/controllers/session_controller.cr").should contain("Member.authenticate(")
      File.exists?("src/models/user.cr").should be_false
    end
  end
end
