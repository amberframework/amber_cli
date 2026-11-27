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

      File.read("src/controllers/pet_controller.cr").should contain("Pet.order(id: :desc).limit(ROWS_PER_PAGE + 1)")
      File.read("src/controllers/pet_controller.cr").should_not contain("Pet.all.to_a")
      File.read("src/controllers/api/toy_controller.cr").should contain("Toy.order(id: :desc).to_a")
      File.read("src/controllers/api/toy_controller.cr").should_not contain("Toy.all.to_a")
    end
  end

  it "answers scaffold reads from the page cache and clears exactly what a write changed" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

      AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Pet", "name:string:required", "adopted:bool"])

      controller = File.read("src/controllers/pet_controller.cr")
      controller.should contain(%(page_cache.answer(context, list_page_key(page_number))))
      controller.should contain(%(page_cache.answer(context, show_page_key(record_id))))
      controller.should contain("clear_pages_after_create")
      controller.should contain("clear_pages_after_update(pet)")
      controller.should contain("clear_pages_after_destroy(pet, list_page_number)")
      controller.should contain("clear_pages_numbered_from")
      controller.should contain("clear_fragments(fragment_keys_of(pet))")
      controller.should contain("per-visitor")

      row = File.read("src/views/pet/_row.ecr")
      row.should contain("escape_text(@pet.name)")
      row.should contain("escape_text(@pet.adopted)")
      File.read("src/views/pet/_details.ecr").should contain("escape_text(@pet.name)")
      File.read("src/components/pet_row.cr").should contain("struct PetRow < Components::StatelessView")
      File.read("src/components/pet_details.cr").should contain(%("details:pet:\#{@pet.id}"))

      spec = File.read("spec/controllers/pet_controller_spec.cr")
      spec.should contain("Components::Cache.configure(&.use_memory_cache)")
      spec.should contain("shows the change on the next read of a stored page")
    end
  end

  it "puts scaffold reads on the lean read routes of a tuned application" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")
      Dir.mkdir_p("config")
      File.write("config/routes.cr", <<-CRYSTAL)
      Amber::Server.configure do
        routes :lean_read do
        end

        routes :web do
        end
      end
      CRYSTAL

      AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Pet", "name:string"])

      routes = File.read("config/routes.cr")
      routes.should contain(%(get "/pets", PetController, :index))
      routes.should contain(%(get "/pets/:id", PetController, :show, constraints: {"id" => :numeric}))
      routes.should contain(%(resources "/pets", PetController, except: [:index, :show]))
      routes.index!(%(get "/pets", PetController)).should be < routes.index!("routes :web do")
    end
  end

  it "indexes the foreign key column of a reference field" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

      AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Comment", "post:reference"])

      migration = File.read(Dir.glob("db/migrations/*_create_comments.sql").first)
      migration.should contain("CREATE INDEX IF NOT EXISTS index_comments_on_post_id ON comments (post_id);")
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

      # Grant requires the parent of a belongs_to, so the schema and column do too.
      migration.should contain("post_id BIGINT NOT NULL")
      File.read("src/schemas/comment_schema.cr").should contain("field :post_id, Int64, required: true")
      File.read("src/controllers/comment_controller.cr").should contain("comment.post_id = schema.post_id")
      form = File.read("src/views/comment/_form.ecr")
      form.should contain(%(number_field("post_id", value: @comment.post_id?, required: true, min: 1)))
      form.should_not contain(%(text_field("post")))

      spec = File.read("spec/controllers/comment_controller_spec.cr")
      spec.should contain("def create_parent_post : Post")
      spec.should contain("saved.post_id = create_parent_post.id")
      spec.should contain(%(it "refuses a post that does not exist"))
      spec.should contain(%("post_id" => "0"))
      spec.should contain("assert_response_status(response, 422)")
    end
  end

  it "answers a refused save with 422 and shows the record errors on the form" do
    SpecHelper.within_temp_directory do
      File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

      AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Comment", "post:reference"])

      controller = File.read("src/controllers/comment_controller.cr")
      controller.should contain("@list_of_save_error_messages = [] of String")
      create_action = controller[controller.index!("  def create")...controller.index!("  def edit")]
      create_action.should contain("@list_of_save_error_messages = comment.errors.full_messages")
      create_action.should contain("response.status_code = 422")
      update_action = controller[controller.index!("  def update")...controller.index!("  def destroy")]
      update_action.should contain("@list_of_save_error_messages = comment.errors.full_messages")
      update_action.should contain("response.status_code = 422")

      form = File.read("src/views/comment/_form.ecr")
      form.should contain("<% unless @errors.empty? && @list_of_save_error_messages.empty? %>")
      form.should contain("<% @list_of_save_error_messages.each do |message| %>")
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

  describe "an app made before ApplicationController loaded first" do
    it "adds the explicit require ahead of each controllers glob, once" do
      SpecHelper.within_temp_directory do
        File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")
        Dir.mkdir_p("src/controllers")
        Dir.mkdir_p("spec")
        Dir.mkdir_p("db")
        File.write("src/controllers/application_controller.cr", "class ApplicationController < Amber::Controller::Base\nend\n")
        File.write("src/shop.cr", %(require "../config/*"\nrequire "./controllers/**"\nrequire "./models/**"\n))
        File.write("spec/spec_helper.cr", %(require "spec"\nrequire "../src/controllers/**"\n))
        File.write("db/seeds.cr", %(require "../src/controllers/**"\n))

        2.times do |index|
          AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["controller", "Account#{index}", "index"])
        end

        File.read("src/shop.cr").should eq(%(require "../config/*"\nrequire "./controllers/application_controller"\nrequire "./controllers/**"\nrequire "./models/**"\n))
        File.read("spec/spec_helper.cr").should eq(%(require "spec"\nrequire "../src/controllers/application_controller"\nrequire "../src/controllers/**"\n))
        File.read("db/seeds.cr").should eq(%(require "../src/controllers/application_controller"\nrequire "../src/controllers/**"\n))
      end
    end

    it "leaves the entry files alone when generating a model" do
      SpecHelper.within_temp_directory do
        File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")
        Dir.mkdir_p("src/controllers")
        File.write("src/controllers/application_controller.cr", "class ApplicationController < Amber::Controller::Base\nend\n")
        File.write("src/shop.cr", %(require "./controllers/**"\n))

        AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["model", "Account", "first_name:string"])

        File.read("src/shop.cr").should eq(%(require "./controllers/**"\n))
      end
    end
  end

  describe "exact amount fields" do
    it "lists money and the brace options in the help text" do
      help = AmberCLI::Commands::GenerateCommand.new("generate").help_description
      help.should contain("decimal, money, bool")
      help.should contain("'price:decimal{38,10}'")
      help.should contain("total:money{USD}")
    end

    it "generates Decimal128 and Money columns for a scaffold" do
      SpecHelper.within_temp_directory do
        File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

        AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Product", "price:decimal", "total:money"])

        model = File.read("src/models/product.cr")
        model.should contain("column price : Grant::Decimal128?, precision: 18, scale: 4")
        model.should contain("column total : Grant::Money?, precision: 18, scale: 4")
        model.should_not contain("Float64")
        model.should_not contain("column total_currency")
      end
    end

    it "writes each database's exact storage into the migration" do
      {
        "pg"     => {"price NUMERIC(18,4)", "total NUMERIC(18,4)", "total_currency VARCHAR(3)", "wide NUMERIC(38,10)"},
        "mysql"  => {"price DECIMAL(18,4)", "total DECIMAL(18,4)", "total_currency VARCHAR(3)", "wide DECIMAL(38,10)"},
        "sqlite" => {"price INTEGER", "total INTEGER", "total_currency TEXT", "wide TEXT"},
      }.each do |database, expected_columns|
        SpecHelper.within_temp_directory do
          File.write(".amber.yml", "template: ecr\ndatabase: #{database}\nmodel: grant\n")

          AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["model", "Product", "price:decimal", "total:money", "wide:decimal{38,10}"])

          migration = File.read(Dir.glob("db/migrations/*_create_products.sql").first)
          expected_columns.each { |column_sql| migration.should contain("  #{column_sql},") }
          migration.should_not contain("DECIMAL(10,2)")
        end
      end
    end

    it "stores 18 digits as an INTEGER and 19 as TEXT on SQLite" do
      SpecHelper.within_temp_directory do
        File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

        AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["model", "Ledger", "small:decimal{18,2}", "large:decimal{19,2}"])

        migration = File.read(Dir.glob("db/migrations/*_create_ledgers.sql").first)
        migration.should contain("  small INTEGER,")
        migration.should contain("  large TEXT,")
        File.read("src/models/ledger.cr").should contain("column large : Grant::Decimal128?, precision: 19, scale: 2")
      end
    end

    it "fixes a money currency in the model and drops the currency column" do
      SpecHelper.within_temp_directory do
        File.write(".amber.yml", "template: ecr\ndatabase: pg\nmodel: grant\n")

        AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Order", "total:money{18,2,usd}:required", "fee:money{EUR}"])

        model = File.read("src/models/order.cr")
        model.should contain(%(column total : Grant::Money, precision: 18, scale: 2, currency: "USD"))
        model.should contain(%(column fee : Grant::Money?, precision: 18, scale: 4, currency: "EUR"))

        migration = File.read(Dir.glob("db/migrations/*_create_orders.sql").first)
        migration.should contain("  total NUMERIC(18,2) NOT NULL,")
        migration.should_not contain("_currency")

        controller = File.read("src/controllers/order_controller.cr")
        controller.should contain(%(order.total = exact_money(submitted_text("total"), "USD") || raise(ArgumentError.new("total is required"))))
        controller.should contain(%(order.fee = exact_money(submitted_text("fee"), "EUR")))
        File.read("src/schemas/order_schema.cr").should_not contain("_currency")
      end
    end

    it "requires the currency column of a required money field" do
      SpecHelper.within_temp_directory do
        File.write(".amber.yml", "template: ecr\ndatabase: mysql\nmodel: grant\n")

        AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Order", "total:money:required"])

        migration = File.read(Dir.glob("db/migrations/*_create_orders.sql").first)
        migration.should contain("  total DECIMAL(18,4) NOT NULL,\n  total_currency VARCHAR(3) NOT NULL,")
        schema = File.read("src/schemas/order_schema.cr")
        schema.should contain("field :total, String, required: true\n  field :total_currency, String, required: true")
      end
    end

    it "checks amounts as text in the schema and reads them from the posted text" do
      SpecHelper.within_temp_directory do
        File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

        AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Product", "price:decimal", "total:money"])

        schema = File.read("src/schemas/product_schema.cr")
        schema.should contain("field :price, String\n")
        schema.should contain("field :total, String\n")
        schema.should contain("field :total_currency, String\n")
        schema.should contain("validate :check_exact_amounts")
        schema.should contain("%w[price total].each do |field_name|")
        schema.should contain("Grant::Decimal128.parse?(amount_text)")
        schema.should contain("%w[total_currency].each do |field_name|")
        schema.should contain("Grant::Currency.find?(currency_code)")

        controller = File.read("src/controllers/product_controller.cr")
        controller.should contain(%(product.price = exact_decimal(submitted_text("price"))))
        controller.should contain(%(product.total = exact_money(submitted_text("total"), submitted_text("total_currency"))))
        controller.should contain("request.params.form_params[field_name]?")
        controller.should contain("Grant::Decimal128.parse(trimmed_text)")
        controller.should contain("Grant::Money.new(amount, currency_code.strip.upcase)")
      end
    end

    it "reads API amounts from the JSON schema strings" do
      SpecHelper.within_temp_directory do
        File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

        AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["api", "Invoice", "amount:decimal{38,10}:required", "total:money"])

        File.read("src/schemas/invoice_schema.cr").should contain(%(content_type "application/json"))
        controller = File.read("src/controllers/api/invoice_controller.cr")
        controller.should contain(%(invoice.amount = exact_decimal(schema.amount) || raise(ArgumentError.new("amount is required"))))
        controller.should contain("invoice.total = exact_money(schema.total, schema.total_currency)")
        controller.should_not contain("submitted_text")

        spec = File.read("spec/controllers/api_invoice_controller_spec.cr")
        spec.should contain(%(post_json("/api/invoices", {amount: "19.99", total: "19.99", total_currency: "USD"})))
        spec.should contain(%(saved.amount = Grant::Decimal128.parse("19.99")))
      end
    end

    it "renders a number input stepped to the scale, and a currency input for money" do
      SpecHelper.within_temp_directory do
        File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

        AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Product", "price:decimal{10,2}:required", "total:money"])

        form = File.read("src/views/product/_form.ecr")
        form.should contain(%(<input type="number" name="price" id="price" step="0.01" value="<%= HTML.escape(@product.price?.to_s) %>" required />))
        form.should contain(%(<input type="number" name="total" id="total" step="0.0001" value="<%= HTML.escape(@product.total?.try(&.amount).to_s) %>" />))
        form.should contain(%(text_field("total_currency", value: @product.total?.try(&.currency.code) || "USD", maxlength: 3, required: false)))
        form.should_not contain(%(number_field("price")))
      end
    end

    it "uses exact sample strings in generated specs, never floats" do
      SpecHelper.within_temp_directory do
        File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")

        AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Product", "price:decimal", "total:money"])

        spec = File.read("spec/controllers/product_controller_spec.cr")
        spec.should contain(%(saved.price = Grant::Decimal128.parse("19.99")))
        spec.should contain(%(saved.total = Grant::Money.new(Grant::Decimal128.parse("19.99"), "USD")))
        spec.should contain(%({"price" => "19.99", "total" => "19.99", "total_currency" => "USD"} of String => String))
        spec.should contain(%(it "keeps every digit of the submitted amounts"))
        spec.should contain(%(created.price.should eq(Grant::Decimal128.parse("19.99"))))
        spec.should_not contain("1.5")
      end
    end

    it "uses exact sample strings in schema specs" do
      SpecHelper.within_temp_directory do
        AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["schema", "Payment", "amount:money", "fee:decimal"])

        schema = File.read("src/schemas/payment_schema.cr")
        schema.should contain("field :amount, String\n  field :amount_currency, String\n  field :fee, String")
        spec = File.read("spec/schemas/payment_schema_spec.cr")
        spec.should contain(%("amount"          => JSON::Any.new("19.99")))
        spec.should contain(%("amount_currency" => JSON::Any.new("USD")))
        spec.should contain(%("fee"             => JSON::Any.new("19.99")))
      end
    end

    it "fills a parent's required amount columns in reference specs" do
      SpecHelper.within_temp_directory do
        File.write(".amber.yml", "template: ecr\ndatabase: sqlite\nmodel: grant\n")
        Dir.mkdir_p("src/models")
        File.write("src/models/account.cr", <<-CRYSTAL)
        class Account < Grant::Base
          column balance : Grant::Decimal128, precision: 18, scale: 4
          column limit_amount : Grant::Money, precision: 18, scale: 2, currency: "EUR"
          column note : Grant::Decimal128?, precision: 18, scale: 4
        end
        CRYSTAL

        AmberCLI::Commands::GenerateCommand.new("generate").parse_and_execute(["scaffold", "Payment", "account:reference"])

        spec = File.read("spec/controllers/payment_controller_spec.cr")
        spec.should contain(%(parent.balance = Grant::Decimal128.parse("1")))
        spec.should contain(%(parent.limit_amount = Grant::Money.new(Grant::Decimal128.parse("1"), "EUR")))
        spec.should_not contain("parent.note")
      end
    end
  end
end
