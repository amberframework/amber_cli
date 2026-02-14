require "../core/base_command"

# The `generate` command creates models, controllers, migrations, scaffolds,
# jobs, mailers, schemas, and channels for an Amber V2 application.
#
# ## Usage
# ```
# amber generate [TYPE] [NAME] [FIELDS...]
# ```
#
# ## Types
# - `model` - Generate a model with migration
# - `controller` - Generate a controller with actions
# - `scaffold` - Generate model, controller, views, and migration
# - `migration` - Generate a blank migration file
# - `mailer` - Generate a mailer class (Amber::Mailer::Base)
# - `job` - Generate a background job class (Amber::Jobs::Job)
# - `schema` - Generate a schema definition (Amber::Schema::Definition)
# - `channel` - Generate a WebSocket channel (Amber::WebSockets::Channel)
# - `api` - Generate API-only controller with model
# - `auth` - Generate authentication system
#
# ## Examples
# ```
# amber generate model User name:string email:string
# amber generate controller Posts index show create update destroy
# amber generate scaffold Article title:string body:text published:bool
# amber generate migration AddStatusToUsers
# amber generate job SendNotification --queue=mailers --max-retries=5
# amber generate mailer User --actions=welcome,notify
# amber generate schema User name:string email:string:required age:int32
# amber generate channel Chat
# amber generate api Product name:string price:float
# ```
module AmberCLI::Commands
  class GenerateCommand < AmberCLI::Core::BaseCommand
    VALID_TYPES = %w[model controller scaffold migration mailer job schema channel api auth]

    FIELD_TYPE_MAP = {
      "string"    => "String",
      "text"      => "String",
      "integer"   => "Int32",
      "int"       => "Int32",
      "int32"     => "Int32",
      "int64"     => "Int64",
      "float"     => "Float64",
      "float64"   => "Float64",
      "decimal"   => "Float64",
      "bool"      => "Bool",
      "boolean"   => "Bool",
      "time"      => "Time",
      "timestamp" => "Time",
      "reference" => "Int64",
      "uuid"      => "String",
      "email"     => "String",
    }

    # Maps CLI field types to Schema field types with default options
    SCHEMA_TYPE_MAP = {
      "string"    => {type: "String", options: ""},
      "text"      => {type: "String", options: ""},
      "integer"   => {type: "Int32", options: ""},
      "int"       => {type: "Int32", options: ""},
      "int32"     => {type: "Int32", options: ""},
      "int64"     => {type: "Int64", options: ""},
      "float"     => {type: "Float64", options: ""},
      "float64"   => {type: "Float64", options: ""},
      "decimal"   => {type: "Float64", options: ""},
      "bool"      => {type: "Bool", options: ""},
      "boolean"   => {type: "Bool", options: ""},
      "time"      => {type: "Time", options: ", format: \"datetime\""},
      "timestamp" => {type: "Time", options: ", format: \"datetime\""},
      "email"     => {type: "String", options: ", format: \"email\""},
      "uuid"      => {type: "String", options: ", format: \"uuid\""},
    }

    getter generator_type : String = ""
    getter name : String = ""
    getter fields : Array(Tuple(String, String)) = [] of Tuple(String, String)
    getter actions : Array(String) = [] of String

    # Job generator options
    getter queue_name : String = "default"
    getter max_retries : Int32 = 3

    # Mailer generator options
    getter mailer_actions : Array(String) = ["welcome"]

    # Schema generator options
    getter schema_fields : Array(Tuple(String, String, Bool)) = [] of Tuple(String, String, Bool)

    # Channel generator options
    getter topics : Array(String) = [] of String

    def help_description : String
      <<-HELP
      Generate application components for Amber V2

      Usage: amber generate [TYPE] [NAME] [FIELDS...]

      Types:
        model       Generate a model with migration
        controller  Generate a controller with actions
        scaffold    Generate model, schema, controller, views, and migration
        migration   Generate a blank migration file
        mailer      Generate a mailer class (Amber::Mailer::Base)
        job         Generate a background job (Amber::Jobs::Job)
        schema      Generate a schema definition (Amber::Schema::Definition)
        channel     Generate a WebSocket channel (Amber::WebSockets::Channel)
        api         Generate API-only controller with model
        auth        Generate authentication system

      Field format: name:type[:required]
        string, text, integer, int64, float, decimal, bool, time, email, uuid, reference

      Examples:
        amber generate model User name:string email:string
        amber generate controller Posts index show create update destroy
        amber generate scaffold Article title:string body:text published:bool
        amber generate migration AddStatusToUsers
        amber generate job SendNotification --queue=mailers --max-retries=5
        amber generate mailer User --actions=welcome,notify
        amber generate schema User name:string email:string:required age:int32
        amber generate channel Chat
        amber generate api Product name:string price:float
      HELP
    end

    def setup_command_options
      option_parser.separator ""
      option_parser.separator "Options:"

      option_parser.on("--queue=QUEUE", "Default queue name for jobs (default: \"default\")") do |q|
        @queue_name = q
      end

      option_parser.on("--max-retries=N", "Max retry attempts for jobs (default: 3)") do |n|
        @max_retries = n.to_i
      end

      option_parser.on("--actions=ACTIONS", "Comma-separated mailer actions (default: \"welcome\")") do |a|
        @mailer_actions = a.split(",").map(&.strip)
      end

      option_parser.on("--topics=TOPICS", "Comma-separated channel topics") do |t|
        @topics = t.split(",").map(&.strip)
      end
    end

    def validate_arguments
      if remaining_arguments.empty?
        error "Generator type is required"
        puts option_parser
        exit(1)
      end

      @generator_type = remaining_arguments[0].downcase

      unless VALID_TYPES.includes?(@generator_type)
        error "Invalid generator type: #{@generator_type}"
        info "Valid types: #{VALID_TYPES.join(", ")}"
        exit(1)
      end

      if remaining_arguments.size < 2
        error "Name is required"
        puts option_parser
        exit(1)
      end

      @name = remaining_arguments[1]

      # Parse remaining arguments as fields or actions
      remaining_arguments[2..].each do |arg|
        if arg.includes?(":")
          parts = arg.split(":")
          field_name = parts[0]
          field_type = parts[1].downcase
          is_required = parts.size > 2 && parts[2].downcase == "required"

          @fields << {field_name, field_type}
          @schema_fields << {field_name, field_type, is_required}
        else
          @actions << arg
        end
      end
    end

    def execute
      case generator_type
      when "model"
        generate_model
      when "controller"
        generate_controller
      when "scaffold"
        generate_scaffold
      when "migration"
        generate_migration
      when "mailer"
        generate_mailer
      when "job"
        generate_job
      when "schema"
        generate_schema
      when "channel"
        generate_channel
      when "api"
        generate_api
      when "auth"
        generate_auth
      else
        error "Unknown generator type: #{generator_type}"
        exit(1)
      end
    end

    # =========================================================================
    # Job Generator
    # =========================================================================

    private def generate_job
      info "Generating job: #{class_name}"

      job_path = "src/jobs/#{file_name}.cr"
      create_file(job_path, job_template)

      spec_path = "spec/jobs/#{file_name}_spec.cr"
      create_file(spec_path, job_spec_template)

      success "Job #{class_name} generated successfully!"
      puts ""
      info "Next steps:"
      info "  1. Add properties to your job class for the data it needs"
      info "  2. Implement the `perform` method with your job logic"
      info "  3. Register the job: Amber::Jobs.register(#{class_name})"
      info "  4. Enqueue: #{class_name}.new.enqueue"
    end

    private def job_template
      queue_override = if queue_name != "default"
                         <<-QUEUE

  # Queue this job will be enqueued to
  def self.queue : String
    "#{queue_name}"
  end
QUEUE
                       else
                         <<-QUEUE

  # Override to customize queue (default: "default")
  # def self.queue : String
  #   "#{queue_name}"
  # end
QUEUE
                       end

      retries_override = if max_retries != 3
                           <<-RETRIES

  # Maximum retry attempts before job is marked as dead
  def self.max_retries : Int32
    #{max_retries}
  end
RETRIES
                         else
                           <<-RETRIES

  # Override to customize max retries (default: 3)
  # def self.max_retries : Int32
  #   3
  # end
RETRIES
                         end

      <<-JOB
# Background job for #{class_name.underscore.gsub("_", " ")}.
#
# Enqueue this job:
#   #{class_name}.new.enqueue
#   #{class_name}.new.enqueue(delay: 5.minutes)
#   #{class_name}.new.enqueue(queue: "critical")
#
# See: https://docs.amberframework.org/amber/guides/jobs
class #{class_name} < Amber::Jobs::Job
  include JSON::Serializable

  # Add your job properties here
  # property user_id : Int64

  def initialize
  end

  def perform
    # Implement your job logic here
  end
#{queue_override}
#{retries_override}
end

# Register the job for deserialization
Amber::Jobs.register(#{class_name})
JOB
    end

    private def job_spec_template
      expected_queue = queue_name

      <<-SPEC
require "../spec_helper"

describe #{class_name} do
  it "can be instantiated" do
    job = #{class_name}.new
    job.should_not be_nil
  end

  it "can be enqueued" do
    job = #{class_name}.new
    envelope = job.enqueue
    envelope.job_class.should eq("#{class_name}")
    envelope.queue.should eq("#{expected_queue}")
  end
end
SPEC
    end

    # =========================================================================
    # Mailer Generator (V2 - Amber::Mailer::Base)
    # =========================================================================

    private def generate_mailer
      info "Generating mailer: #{class_name}Mailer"

      mailer_path = "src/mailers/#{file_name}_mailer.cr"
      create_file(mailer_path, mailer_template)

      # Create mailer view directory and templates for each action
      views_dir = "src/views/#{file_name}_mailer"
      mailer_actions.each do |action|
        create_file("#{views_dir}/#{action}.ecr", mailer_view_template(action))
      end

      spec_path = "spec/mailers/#{file_name}_mailer_spec.cr"
      create_file(spec_path, mailer_spec_template)

      success "Mailer #{class_name}Mailer generated successfully!"
      puts ""
      info "Next steps:"
      info "  1. Customize the mailer methods and templates"
      info "  2. Configure the mail adapter in config/application.cr"
      info "  3. Send mail: #{class_name}Mailer.new(\"Alice\", \"alice@example.com\")"
      info "       .to(\"alice@example.com\")"
      info "       .from(\"noreply@example.com\")"
      info "       .subject(\"Welcome!\")"
      info "       .deliver"
    end

    private def mailer_template
      action_methods = mailer_actions.map do |action|
        <<-METHOD
  # Renders the #{action} email HTML body.
  # Template: src/views/#{file_name}_mailer/#{action}.ecr
  def #{action}_html_body : String?
    render("src/views/#{file_name}_mailer/#{action}.ecr")
  end
METHOD
      end.join("\n\n")

      first_action = mailer_actions.first

      <<-MAILER
# Mailer for #{class_name.underscore.gsub("_", " ")} related emails.
#
# Usage:
#   #{class_name}Mailer.new("Alice", "alice@example.com")
#     .to("alice@example.com")
#     .from("noreply@example.com")
#     .subject("Welcome!")
#     .deliver
#
# See: https://docs.amberframework.org/amber/guides/mailers
class #{class_name}Mailer < Amber::Mailer::Base
  def initialize(@user_name : String, @user_email : String)
  end

  def html_body : String?
    #{first_action}_html_body
  end

  def text_body : String?
    "Hello, \#{@user_name}!"
  end

#{action_methods}
end
MAILER
    end

    private def mailer_view_template(action : String)
      <<-VIEW
<h1>Welcome, <%= HTML.escape(@user_name) %>!</h1>
<p>Thank you for signing up.</p>
VIEW
    end

    private def mailer_spec_template
      first_action = mailer_actions.first

      <<-SPEC
require "../spec_helper"

describe #{class_name}Mailer do
  it "can build a #{first_action} email" do
    mailer = #{class_name}Mailer.new("Alice", "alice@example.com")
    email = mailer
      .to("alice@example.com")
      .from("noreply@example.com")
      .subject("Welcome!")
      .build

    email.to.should eq(["alice@example.com"])
    email.subject.should eq("Welcome!")
    email.html_body.should_not be_nil
  end
end
SPEC
    end

    # =========================================================================
    # Schema Generator
    # =========================================================================

    private def generate_schema
      info "Generating schema: #{class_name}Schema"

      schema_path = "src/schemas/#{file_name}_schema.cr"
      create_file(schema_path, schema_template)

      spec_path = "spec/schemas/#{file_name}_schema_spec.cr"
      create_file(spec_path, schema_spec_template)

      success "Schema #{class_name}Schema generated successfully!"
      puts ""
      info "Next steps:"
      info "  1. Customize field validations (min_length, max_length, format, etc.)"
      info "  2. Use in controllers: schema = #{class_name}Schema.new(merge_request_data)"
      info "  3. Check result: result = schema.validate"
    end

    private def schema_template
      field_definitions = schema_fields.map do |field_name, field_type, is_required|
        schema_info = SCHEMA_TYPE_MAP[field_type]? || {type: "String", options: ""}
        crystal_type = schema_info[:type]
        extra_options = schema_info[:options]

        required_str = is_required ? ", required: true" : ""

        "  field :#{field_name}, #{crystal_type}#{required_str}#{extra_options}"
      end.join("\n")

      # If no fields were parsed from schema_fields, use regular fields
      if field_definitions.empty? && !fields.empty?
        field_definitions = fields.map do |field_name, field_type|
          schema_info = SCHEMA_TYPE_MAP[field_type]? || {type: "String", options: ""}
          crystal_type = schema_info[:type]
          extra_options = schema_info[:options]

          "  field :#{field_name}, #{crystal_type}#{extra_options}"
        end.join("\n")
      end

      <<-SCHEMA
# Schema definition for validating #{class_name.underscore.gsub("_", " ")} data.
#
# Usage:
#   data = {"name" => JSON::Any.new("value")}
#   schema = #{class_name}Schema.new(data)
#   result = schema.validate
#   if result.success?
#     # Access validated fields: schema.name
#   else
#     # Handle errors: result.errors
#   end
#
# See: https://docs.amberframework.org/amber/guides/schemas
class #{class_name}Schema < Amber::Schema::Definition
#{field_definitions}
end
SCHEMA
    end

    private def schema_spec_template
      # Build valid test data from fields
      valid_data_entries = schema_fields.map do |field_name, field_type, _|
        value = case field_type
                when "string", "text", "uuid"    then "\"test_value\""
                when "email"                     then "\"test@example.com\""
                when "integer", "int", "int32"   then "1"
                when "int64"                     then "1_i64"
                when "float", "float64"          then "1.0"
                when "decimal"                   then "1.0"
                when "bool", "boolean"           then "false"
                when "time", "timestamp"         then "\"2024-01-01T00:00:00Z\""
                else                                  "\"test_value\""
                end
        "    \"#{field_name}\" => JSON::Any.new(#{value}),"
      end.join("\n")

      # Fall back to regular fields if schema_fields is empty
      if valid_data_entries.empty? && !fields.empty?
        valid_data_entries = fields.map do |field_name, field_type|
          value = case field_type
                  when "string", "text", "uuid"    then "\"test_value\""
                  when "email"                     then "\"test@example.com\""
                  when "integer", "int", "int32"   then "1"
                  when "int64"                     then "1_i64"
                  when "float", "float64"          then "1.0"
                  when "decimal"                   then "1.0"
                  when "bool", "boolean"           then "false"
                  when "time", "timestamp"         then "\"2024-01-01T00:00:00Z\""
                  else                                  "\"test_value\""
                  end
          "    \"#{field_name}\" => JSON::Any.new(#{value}),"
        end.join("\n")
      end

      <<-SPEC
require "../spec_helper"

describe #{class_name}Schema do
  it "validates with valid data" do
    data = {
#{valid_data_entries}
    }
    schema = #{class_name}Schema.new(data)
    result = schema.validate
    result.success?.should be_true
  end

  it "fails validation when required fields are missing" do
    data = {} of String => JSON::Any
    schema = #{class_name}Schema.new(data)
    result = schema.validate
    # If you have required fields, this should fail:
    # result.failure?.should be_true
    result.should_not be_nil
  end
end
SPEC
    end

    # =========================================================================
    # Channel Generator
    # =========================================================================

    private def generate_channel
      info "Generating channel: #{class_name}Channel"

      channel_path = "src/channels/#{file_name}_channel.cr"
      create_file(channel_path, channel_template)

      socket_path = "src/sockets/#{file_name}_socket.cr"
      create_file(socket_path, socket_template)

      spec_path = "spec/channels/#{file_name}_channel_spec.cr"
      create_file(spec_path, channel_spec_template)

      success "Channel #{class_name}Channel generated successfully!"
      puts ""
      info "Next steps:"
      info "  1. Implement handle_message with your channel logic"
      info "  2. Configure the socket in config/routes.cr:"
      info "     websocket \"/#{file_name}\", #{class_name}Socket"
      info "  3. Connect from the client using JavaScript WebSocket API"
    end

    private def channel_template
      topic_name = file_name

      <<-CHANNEL
# WebSocket channel for #{class_name.underscore.gsub("_", " ")} communication.
#
# Clients subscribe to this channel through a ClientSocket.
# Messages sent to this channel are handled by `handle_message`.
#
# See: https://docs.amberframework.org/amber/guides/websockets
class #{class_name}Channel < Amber::WebSockets::Channel
  # Called when a client subscribes to this channel.
  # Use this for authorization or sending initial state.
  def handle_joined(client_socket, message)
  end

  # Called when a client unsubscribes from this channel.
  def handle_leave(client_socket)
  end

  # Called when a client sends a message to this channel.
  # Implement your message handling logic here.
  def handle_message(client_socket, msg)
    # Rebroadcast to all subscribers:
    rebroadcast!(msg)
  end
end
CHANNEL
    end

    private def socket_template
      <<-SOCKET
# ClientSocket for #{class_name.underscore.gsub("_", " ")} WebSocket connections.
#
# Maps authenticated users to WebSocket connections and registers
# channels that clients can subscribe to.
#
# Configure in config/routes.cr:
#   websocket "/#{file_name}", #{class_name}Socket
#
# See: https://docs.amberframework.org/amber/guides/websockets
struct #{class_name}Socket < Amber::WebSockets::ClientSocket
  channel "#{file_name}:*", #{class_name}Channel

  # Optional: implement authentication
  def on_connect : Bool
    # Return true to allow connection, false to reject.
    # Example: check session or token
    #   return get_bearer_token? != nil
    true
  end
end
SOCKET
    end

    private def channel_spec_template
      <<-SPEC
require "../spec_helper"

describe #{class_name}Channel do
  it "can be instantiated" do
    channel = #{class_name}Channel.new("#{file_name}:lobby")
    channel.should_not be_nil
  end
end
SPEC
    end

    # =========================================================================
    # Model Generator
    # =========================================================================

    private def generate_model
      info "Generating model: #{class_name}"

      model_path = "src/models/#{file_name}.cr"
      create_file(model_path, model_template)

      generate_migration_for_model

      spec_path = "spec/models/#{file_name}_spec.cr"
      create_file(spec_path, model_spec_template)

      success "Model #{class_name} generated successfully!"
    end

    private def model_template
      field_definitions = fields.map do |field_name, field_type|
        crystal_type = FIELD_TYPE_MAP[field_type]? || "String"
        "  column #{field_name} : #{crystal_type}"
      end.join("\n")

      <<-MODEL
class #{class_name} < Grant::Model
  table :#{table_name}

  primary_key id : Int64

#{field_definitions}

  timestamps

  # Add validations here:
  # validate :name, "can't be blank" do |model|
  #   !model.name.to_s.empty?
  # end
end
MODEL
    end

    private def model_spec_template
      <<-SPEC
require "../spec_helper"

describe #{class_name} do
  it "can be created" do
    #{variable_name} = #{class_name}.new
    #{variable_name}.should_not be_nil
  end
end
SPEC
    end

    # =========================================================================
    # Controller Generator (V2)
    # =========================================================================

    private def generate_controller
      info "Generating controller: #{controller_name}"

      controller_path = "src/controllers/#{file_name}_controller.cr"
      create_file(controller_path, controller_template)

      # Generate view files for each action
      template_ext = detect_template_extension
      view_actions = if actions.empty?
                       %w[index]
                     else
                       actions
                     end

      view_actions.each do |action|
        view_path = "src/views/#{file_name}/#{action}.#{template_ext}"
        create_file(view_path, controller_view_template(action, template_ext))
      end

      spec_path = "spec/controllers/#{file_name}_controller_spec.cr"
      create_file(spec_path, controller_spec_template)

      success "Controller #{controller_name} generated successfully!"
      info "Don't forget to add routes to config/routes.cr"
    end

    private def controller_template
      action_methods = if actions.empty?
                         %w[index]
                       else
                         actions
                       end

      template_ext = detect_template_extension

      methods = action_methods.map do |action|
        <<-METHOD
  def #{action}
    render("#{action}.#{template_ext}")
  end
METHOD
      end.join("\n\n")

      <<-CONTROLLER
class #{controller_name} < ApplicationController
#{methods}
end
CONTROLLER
    end

    private def controller_view_template(action : String, ext : String)
      if ext == "slang"
        <<-VIEW
h1 #{class_name} - #{action.capitalize}
p This is the #{action} action for #{controller_name}.
VIEW
      else
        <<-VIEW
<h1>#{class_name} - #{action.capitalize}</h1>
<p>This is the #{action} action for #{controller_name}.</p>
VIEW
      end
    end

    private def controller_spec_template
      action_methods = if actions.empty?
                         %w[index]
                       else
                         actions
                       end

      action_specs = action_methods.map do |action|
        verb = case action
               when "index", "show", "new", "edit" then "GET"
               when "create"                       then "POST"
               when "update"                       then "PUT"
               when "destroy"                      then "DELETE"
               else                                     "GET"
               end

        path = case action
               when "index"   then "/#{plural_name}"
               when "show"    then "/#{plural_name}/1"
               when "new"     then "/#{plural_name}/new"
               when "edit"    then "/#{plural_name}/1/edit"
               when "create"  then "/#{plural_name}"
               when "update"  then "/#{plural_name}/1"
               when "destroy" then "/#{plural_name}/1"
               else                "/#{plural_name}"
               end

        <<-SPEC_BLOCK
  describe "#{verb} #{path}" do
    it "responds successfully" do
      response = #{verb.downcase}("#{path}")
      assert_response_success(response)
    end
  end
SPEC_BLOCK
      end.join("\n\n")

      <<-SPEC
require "../spec_helper"

describe #{controller_name} do
  include Amber::Testing::RequestHelpers
  include Amber::Testing::Assertions

#{action_specs}
end
SPEC
    end

    # =========================================================================
    # Scaffold Generator (V2)
    # =========================================================================

    private def generate_scaffold
      info "Generating scaffold: #{class_name}"

      generate_model
      generate_scaffold_schema
      generate_controller_for_scaffold
      generate_views

      success "Scaffold #{class_name} generated successfully!"
      puts ""
      info "Don't forget to add routes to config/routes.cr:"
      info "  resources \"/#{plural_name}\", #{controller_name}"
    end

    private def generate_scaffold_schema
      schema_path = "src/schemas/#{file_name}_schema.cr"

      field_definitions = fields.map do |field_name, field_type|
        schema_info = SCHEMA_TYPE_MAP[field_type]? || {type: "String", options: ""}
        crystal_type = schema_info[:type]
        extra_options = schema_info[:options]
        "  field :#{field_name}, #{crystal_type}, required: true#{extra_options}"
      end.join("\n")

      content = <<-SCHEMA
# Schema for validating #{class_name} create/update parameters.
#
# Used by #{controller_name} for request validation.
#
# See: https://docs.amberframework.org/amber/guides/schemas
class #{class_name}Schema < Amber::Schema::Definition
#{field_definitions}
end
SCHEMA

      create_file(schema_path, content)
    end

    private def generate_controller_for_scaffold
      controller_path = "src/controllers/#{file_name}_controller.cr"
      create_file(controller_path, scaffold_controller_template)

      spec_path = "spec/controllers/#{file_name}_controller_spec.cr"
      create_file(spec_path, scaffold_spec_template)
    end

    private def scaffold_controller_template
      template_ext = detect_template_extension

      schema_field_assignments = fields.map do |field_name, _|
        "      #{variable_name}.#{field_name} = schema.#{field_name}.not_nil!"
      end.join("\n")

      update_field_assignments = fields.map do |field_name, _|
        "        #{variable_name}.#{field_name} = schema.#{field_name}.not_nil!"
      end.join("\n")

      <<-CONTROLLER
class #{controller_name} < ApplicationController
  def index
    @#{plural_variable_name} = #{class_name}.all
    render("index.#{template_ext}")
  end

  def show
    if #{variable_name} = #{class_name}.find(params[:id])
      @#{variable_name} = #{variable_name}
      render("show.#{template_ext}")
    else
      flash[:danger] = "#{class_name} not found"
      redirect_to "/#{plural_name}"
    end
  end

  def new
    @#{variable_name} = #{class_name}.new
    render("new.#{template_ext}")
  end

  def create
    # Schema-based parameter validation
    schema = #{class_name}Schema.new(merge_request_data)
    result = schema.validate

    if result.success?
      #{variable_name} = #{class_name}.new
#{schema_field_assignments}

      if #{variable_name}.save
        flash[:success] = "#{class_name} created successfully"
        redirect_to "/#{plural_name}/\#{#{variable_name}.id}"
      else
        @#{variable_name} = #{variable_name}
        flash[:danger] = "Could not create #{class_name}"
        render("new.#{template_ext}")
      end
    else
      @#{variable_name} = #{class_name}.new
      @errors = result.errors
      flash[:danger] = "Validation failed"
      render("new.#{template_ext}")
    end
  end

  def edit
    if #{variable_name} = #{class_name}.find(params[:id])
      @#{variable_name} = #{variable_name}
      render("edit.#{template_ext}")
    else
      flash[:danger] = "#{class_name} not found"
      redirect_to "/#{plural_name}"
    end
  end

  def update
    if #{variable_name} = #{class_name}.find(params[:id])
      schema = #{class_name}Schema.new(merge_request_data)
      result = schema.validate

      if result.success?
#{update_field_assignments}

        if #{variable_name}.save
          flash[:success] = "#{class_name} updated successfully"
          redirect_to "/#{plural_name}/\#{#{variable_name}.id}"
        else
          @#{variable_name} = #{variable_name}
          flash[:danger] = "Could not update #{class_name}"
          render("edit.#{template_ext}")
        end
      else
        @#{variable_name} = #{variable_name}
        @errors = result.errors
        flash[:danger] = "Validation failed"
        render("edit.#{template_ext}")
      end
    else
      flash[:danger] = "#{class_name} not found"
      redirect_to "/#{plural_name}"
    end
  end

  def destroy
    if #{variable_name} = #{class_name}.find(params[:id])
      #{variable_name}.destroy
      flash[:success] = "#{class_name} deleted successfully"
    else
      flash[:danger] = "#{class_name} not found"
    end
    redirect_to "/#{plural_name}"
  end
end
CONTROLLER
    end

    private def scaffold_spec_template
      <<-SPEC
require "../spec_helper"

describe #{controller_name} do
  include Amber::Testing::RequestHelpers
  include Amber::Testing::Assertions

  describe "GET /#{plural_name}" do
    it "responds successfully" do
      response = get("/#{plural_name}")
      assert_response_success(response)
    end
  end

  describe "GET /#{plural_name}/new" do
    it "responds successfully" do
      response = get("/#{plural_name}/new")
      assert_response_success(response)
    end
  end

  describe "GET /#{plural_name}/:id" do
    it "responds successfully" do
      response = get("/#{plural_name}/1")
      # assert_response_success(response)
    end
  end

  describe "GET /#{plural_name}/:id/edit" do
    it "responds successfully" do
      response = get("/#{plural_name}/1/edit")
      # assert_response_success(response)
    end
  end

  describe "POST /#{plural_name}" do
    it "creates a new #{class_name.underscore}" do
      response = post("/#{plural_name}")
      # assert_response_redirect(response)
    end
  end

  describe "DELETE /#{plural_name}/:id" do
    it "deletes the #{class_name.underscore}" do
      response = delete("/#{plural_name}/1")
      # assert_response_redirect(response)
    end
  end
end
SPEC
    end

    private def generate_views
      views_dir = "src/views/#{file_name}"

      template_ext = detect_template_extension

      create_file("#{views_dir}/index.#{template_ext}", index_view_template(template_ext))
      create_file("#{views_dir}/show.#{template_ext}", show_view_template(template_ext))
      create_file("#{views_dir}/new.#{template_ext}", new_view_template(template_ext))
      create_file("#{views_dir}/edit.#{template_ext}", edit_view_template(template_ext))
      create_file("#{views_dir}/_form.#{template_ext}", form_partial_template(template_ext))
    end

    # =========================================================================
    # Migration Generator
    # =========================================================================

    private def generate_migration
      timestamp = Time.utc.to_s("%Y%m%d%H%M%S%3N")
      migration_name = name.underscore
      migration_path = "db/migrations/#{timestamp}_#{migration_name}.sql"

      Dir.mkdir_p("db/migrations") unless Dir.exists?("db/migrations")

      if fields.empty?
        content = <<-SQL
-- Migration: #{migration_name}
-- Created: #{Time.utc}

-- Add your migration SQL here

SQL
      else
        content = create_table_migration
      end

      create_file(migration_path, content)
      success "Migration created: #{migration_path}"
    end

    private def generate_migration_for_model
      timestamp = Time.utc.to_s("%Y%m%d%H%M%S%3N")
      migration_path = "db/migrations/#{timestamp}_create_#{table_name}.sql"

      Dir.mkdir_p("db/migrations") unless Dir.exists?("db/migrations")
      create_file(migration_path, create_table_migration)
    end

    # =========================================================================
    # API Generator
    # =========================================================================

    private def generate_api
      info "Generating API: #{class_name}"

      generate_model

      # Generate schema for API validation
      generate_scaffold_schema

      # API controller (JSON only)
      api_dir = "src/controllers/api"
      Dir.mkdir_p(api_dir) unless Dir.exists?(api_dir)

      api_controller_path = "#{api_dir}/#{file_name}_controller.cr"
      create_file(api_controller_path, api_controller_template)

      spec_path = "spec/controllers/api_#{file_name}_controller_spec.cr"
      create_file(spec_path, api_spec_template)

      success "API #{class_name} generated successfully!"
      puts ""
      info "Don't forget to add routes to config/routes.cr:"
      info "  routes :api do"
      info "    resources \"/#{plural_name}\", Api::#{controller_name}"
      info "  end"
    end

    private def api_controller_template
      schema_field_assignments = fields.map do |field_name, _|
        "      #{variable_name}.#{field_name} = schema.#{field_name}.not_nil!"
      end.join("\n")

      update_field_assignments = fields.map do |field_name, _|
        "        #{variable_name}.#{field_name} = schema.#{field_name}.not_nil!"
      end.join("\n")

      <<-CONTROLLER
module Api
  class #{controller_name} < ApplicationController
    def index
      #{plural_variable_name} = #{class_name}.all
      render json: #{plural_variable_name}.to_json
    end

    def show
      if #{variable_name} = #{class_name}.find(params[:id])
        render json: #{variable_name}.to_json
      else
        render json: {error: "#{class_name} not found"}.to_json, status: 404
      end
    end

    def create
      schema = #{class_name}Schema.new(merge_request_data)
      result = schema.validate

      if result.success?
        #{variable_name} = #{class_name}.new
#{schema_field_assignments}

        if #{variable_name}.save
          render json: #{variable_name}.to_json, status: 201
        else
          render json: {error: "Could not create #{class_name}"}.to_json, status: 422
        end
      else
        render json: {errors: result.errors.map(&.to_h)}.to_json, status: 422
      end
    end

    def update
      if #{variable_name} = #{class_name}.find(params[:id])
        schema = #{class_name}Schema.new(merge_request_data)
        result = schema.validate

        if result.success?
#{update_field_assignments}

          if #{variable_name}.save
            render json: #{variable_name}.to_json
          else
            render json: {error: "Could not update #{class_name}"}.to_json, status: 422
          end
        else
          render json: {errors: result.errors.map(&.to_h)}.to_json, status: 422
        end
      else
        render json: {error: "#{class_name} not found"}.to_json, status: 404
      end
    end

    def destroy
      if #{variable_name} = #{class_name}.find(params[:id])
        #{variable_name}.destroy
        render json: {message: "#{class_name} deleted"}.to_json
      else
        render json: {error: "#{class_name} not found"}.to_json, status: 404
      end
    end
  end
end
CONTROLLER
    end

    private def api_spec_template
      <<-SPEC
require "../spec_helper"

describe Api::#{controller_name} do
  include Amber::Testing::RequestHelpers
  include Amber::Testing::Assertions

  describe "GET /api/#{plural_name}" do
    it "responds with JSON" do
      response = get("/api/#{plural_name}")
      assert_response_success(response)
      assert_json_content_type(response)
    end
  end

  describe "POST /api/#{plural_name}" do
    it "creates a new #{class_name.underscore}" do
      # response = post_json("/api/#{plural_name}", {})
      # assert_response_status(response, 201)
    end
  end
end
SPEC
    end

    # =========================================================================
    # Auth Generator (V2)
    # =========================================================================

    private def generate_auth
      info "Generating authentication system"

      template_ext = detect_template_extension

      # Generate User model
      @fields = [{"email", "string"}, {"hashed_password", "string"}]
      @name = "User"
      generate_model

      # Generate session controller
      session_controller = <<-CONTROLLER
class SessionController < ApplicationController
  def new
    render("new.#{template_ext}")
  end

  def create
    if user = User.authenticate(params[:email], params[:password])
      session[:user_id] = user.id.to_s
      flash[:success] = "Welcome back!"
      redirect_to "/"
    else
      flash[:danger] = "Invalid email or password"
      render("new.#{template_ext}")
    end
  end

  def destroy
    session.delete(:user_id)
    flash[:info] = "You have been logged out"
    redirect_to "/"
  end
end
CONTROLLER

      create_file("src/controllers/session_controller.cr", session_controller)

      # Generate registration controller
      registration_controller = <<-CONTROLLER
class RegistrationController < ApplicationController
  def new
    @user = User.new
    render("new.#{template_ext}")
  end

  def create
    user = User.new
    user.email = params[:email]
    user.password = params[:password]

    if user.save
      session[:user_id] = user.id.to_s
      flash[:success] = "Welcome! Your account has been created."
      redirect_to "/"
    else
      @user = user
      flash[:danger] = "Could not create account"
      render("new.#{template_ext}")
    end
  end
end
CONTROLLER

      create_file("src/controllers/registration_controller.cr", registration_controller)

      # Create view directories and views
      if template_ext == "ecr"
        login_view = <<-VIEW
<h1>Login</h1>

<%= form_for("/session", method: "POST") { %>
  <div class="form-group">
    <%= label("email") %>
    <%= email_field("email") %>
  </div>
  <div class="form-group">
    <%= label("password") %>
    <%= password_field("password") %>
  </div>
  <%= submit_button("Login") %>
<% } %>
VIEW

        register_view = <<-VIEW
<h1>Create Account</h1>

<%= form_for("/register", method: "POST") { %>
  <div class="form-group">
    <%= label("email") %>
    <%= email_field("email") %>
  </div>
  <div class="form-group">
    <%= label("password") %>
    <%= password_field("password") %>
  </div>
  <div class="form-group">
    <%= label("password_confirmation", text: "Confirm Password") %>
    <%= password_field("password_confirmation") %>
  </div>
  <%= submit_button("Create Account") %>
<% } %>
VIEW
      else
        login_view = <<-VIEW
h1 Login
== form(action: "/session", method: "post") do
  .form-group
    label Email
    input type="email" name="email" required=true
  .form-group
    label Password
    input type="password" name="password" required=true
  button type="submit" Login
VIEW

        register_view = <<-VIEW
h1 Create Account
== form(action: "/register", method: "post") do
  .form-group
    label Email
    input type="email" name="email" required=true
  .form-group
    label Password
    input type="password" name="password" required=true
  .form-group
    label Confirm Password
    input type="password" name="password_confirmation" required=true
  button type="submit" Create Account
VIEW
      end

      create_file("src/views/session/new.#{template_ext}", login_view)
      create_file("src/views/registration/new.#{template_ext}", register_view)

      success "Authentication system generated!"
      puts ""
      info "Add these routes to config/routes.cr:"
      info "  get \"/login\", SessionController, :new"
      info "  post \"/session\", SessionController, :create"
      info "  delete \"/session\", SessionController, :destroy"
      info "  get \"/register\", RegistrationController, :new"
      info "  post \"/register\", RegistrationController, :create"
    end

    # =========================================================================
    # SQL Migration Templates
    # =========================================================================

    private def create_table_migration
      column_definitions = fields.map do |field_name, field_type|
        sql_type = case field_type
                   when "string", "uuid", "email" then "VARCHAR(255)"
                   when "text"                    then "TEXT"
                   when "integer", "int", "int32" then "INTEGER"
                   when "int64", "reference"      then "BIGINT"
                   when "float", "float64"        then "DOUBLE PRECISION"
                   when "decimal"                 then "DECIMAL(10,2)"
                   when "bool", "boolean"         then "BOOLEAN DEFAULT FALSE"
                   when "time", "timestamp"       then "TIMESTAMP"
                   else                                "VARCHAR(255)"
                   end
        "  #{field_name} #{sql_type}"
      end.join(",\n")

      <<-SQL
-- Create #{table_name} table
CREATE TABLE IF NOT EXISTS #{table_name} (
  id BIGSERIAL PRIMARY KEY,
#{column_definitions},
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SQL
    end

    # =========================================================================
    # View Templates (V2 with form helpers)
    # =========================================================================

    private def index_view_template(ext : String)
      if ext == "slang"
        <<-VIEW
h1 #{plural_class_name}

a href="/#{plural_name}/new" New #{class_name}

table
  thead
    tr
      th ID
#{fields.map { |f, _| "      th #{f.camelcase}" }.join("\n")}
      th Actions
  tbody
    - @#{plural_variable_name}.each do |#{variable_name}|
      tr
        td = #{variable_name}.id
#{fields.map { |f, _| "        td = #{variable_name}.#{f}" }.join("\n")}
        td
          a href="/#{plural_name}/\#{#{variable_name}.id}" Show
          a href="/#{plural_name}/\#{#{variable_name}.id}/edit" Edit
VIEW
      else
        <<-VIEW
<h1>#{plural_class_name}</h1>

<a href="/#{plural_name}/new">New #{class_name}</a>

<table>
  <thead>
    <tr>
      <th>ID</th>
#{fields.map { |f, _| "      <th>#{f.camelcase}</th>" }.join("\n")}
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <% @#{plural_variable_name}.each do |#{variable_name}| %>
      <tr>
        <td><%= #{variable_name}.id %></td>
#{fields.map { |f, _| "        <td><%= #{variable_name}.#{f} %></td>" }.join("\n")}
        <td>
          <a href="/#{plural_name}/<%= #{variable_name}.id %>">Show</a>
          <a href="/#{plural_name}/<%= #{variable_name}.id %>/edit">Edit</a>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
VIEW
      end
    end

    private def show_view_template(ext : String)
      if ext == "slang"
        <<-VIEW
h1 #{class_name}

dl
#{fields.map { |f, _| "  dt #{f.camelcase}\n  dd = @#{variable_name}.#{f}" }.join("\n")}

a href="/#{plural_name}" Back
a href="/#{plural_name}/\#{@#{variable_name}.id}/edit" Edit
VIEW
      else
        <<-VIEW
<h1>#{class_name}</h1>

<dl>
#{fields.map { |f, _| "  <dt>#{f.camelcase}</dt>\n  <dd><%= @#{variable_name}.#{f} %></dd>" }.join("\n")}
</dl>

<a href="/#{plural_name}">Back</a>
<a href="/#{plural_name}/<%= @#{variable_name}.id %>/edit">Edit</a>
VIEW
      end
    end

    private def new_view_template(ext : String)
      if ext == "slang"
        <<-VIEW
h1 New #{class_name}

== render("_form.slang")

a href="/#{plural_name}" Back
VIEW
      else
        <<-VIEW
<h1>New #{class_name}</h1>

<%= render("_form.ecr") %>

<a href="/#{plural_name}">Back</a>
VIEW
      end
    end

    private def edit_view_template(ext : String)
      if ext == "slang"
        <<-VIEW
h1 Edit #{class_name}

== render("_form.slang")

a href="/#{plural_name}" Back
VIEW
      else
        <<-VIEW
<h1>Edit #{class_name}</h1>

<%= render("_form.ecr") %>

<a href="/#{plural_name}">Back</a>
VIEW
      end
    end

    private def form_partial_template(ext : String)
      if ext == "slang"
        form_fields = fields.map do |field_name, field_type|
          input_type = case field_type
                       when "text"               then "textarea"
                       when "bool", "boolean"    then "checkbox"
                       when "integer", "int", "int32", "int64", "float", "decimal" then "number"
                       else "text"
                       end

          if input_type == "textarea"
            <<-FIELD
  .form-group
    label #{field_name.camelcase}
    textarea name="#{field_name}" = @#{variable_name}.try(&.#{field_name})
FIELD
          elsif input_type == "checkbox"
            <<-FIELD
  .form-group
    label
      input type="checkbox" name="#{field_name}" checked=@#{variable_name}.try(&.#{field_name})
      | #{field_name.camelcase}
FIELD
          else
            <<-FIELD
  .form-group
    label #{field_name.camelcase}
    input type="#{input_type}" name="#{field_name}" value=@#{variable_name}.try(&.#{field_name})
FIELD
          end
        end.join("\n")

        <<-VIEW
== form(action: "/#{plural_name}", method: "post") do
#{form_fields}
  button type="submit" Save
VIEW
      else
        form_fields = fields.map do |field_name, field_type|
          case field_type
          when "text"
            <<-FIELD
  <div class="form-group">
    <%= label("#{field_name}") %>
    <%= text_area("#{field_name}", value: @#{variable_name}.try(&.#{field_name})) %>
  </div>
FIELD
          when "bool", "boolean"
            <<-FIELD
  <div class="form-group">
    <%= checkbox("#{field_name}", checked: @#{variable_name}.try(&.#{field_name}) || false) %>
    <%= label("#{field_name}") %>
  </div>
FIELD
          when "email"
            <<-FIELD
  <div class="form-group">
    <%= label("#{field_name}") %>
    <%= email_field("#{field_name}", value: @#{variable_name}.try(&.#{field_name})) %>
  </div>
FIELD
          when "integer", "int", "int32", "int64", "float", "float64", "decimal"
            <<-FIELD
  <div class="form-group">
    <%= label("#{field_name}") %>
    <%= number_field("#{field_name}", value: @#{variable_name}.try(&.#{field_name})) %>
  </div>
FIELD
          else
            <<-FIELD
  <div class="form-group">
    <%= label("#{field_name}") %>
    <%= text_field("#{field_name}", value: @#{variable_name}.try(&.#{field_name})) %>
  </div>
FIELD
          end
        end.join("\n")

        <<-VIEW
<%= form_for("/#{plural_name}", method: "POST") { %>
#{form_fields}
  <%= submit_button("Save") %>
<% } %>
VIEW
      end
    end

    # =========================================================================
    # Helper Methods
    # =========================================================================

    private def class_name
      name.camelcase
    end

    private def plural_class_name
      pluralize(class_name)
    end

    private def controller_name
      "#{class_name}Controller"
    end

    private def file_name
      name.underscore
    end

    private def table_name
      pluralize(name.underscore)
    end

    private def variable_name
      name.underscore
    end

    private def plural_variable_name
      pluralize(name.underscore)
    end

    private def plural_name
      pluralize(name.underscore)
    end

    private def default_actions
      %w[index show new create edit update destroy]
    end

    private def field_assignments
      fields.map do |field_name, _|
        "    #{variable_name}.#{field_name} = params[:#{field_name}]"
      end.join("\n")
    end

    private def field_assignments_with_prefix
      fields.map do |field_name, _|
        "      #{variable_name}.#{field_name} = params[:#{field_name}]"
      end.join("\n")
    end

    private def pluralize(word : String) : String
      return word if word.empty?

      if word.ends_with?("y") && !%w[a e i o u].includes?(word[-2].to_s)
        word[0..-2] + "ies"
      elsif word.ends_with?("s") || word.ends_with?("x") || word.ends_with?("z") ||
            word.ends_with?("ch") || word.ends_with?("sh")
        word + "es"
      elsif word.ends_with?("f")
        word[0..-2] + "ves"
      elsif word.ends_with?("fe")
        word[0..-3] + "ves"
      else
        word + "s"
      end
    end

    private def detect_template_extension
      if File.exists?(".amber.yml")
        content = File.read(".amber.yml")
        if content.includes?("template: slang")
          "slang"
        else
          "ecr"
        end
      else
        "ecr"
      end
    end

    private def create_file(path : String, content : String)
      dir = File.dirname(path)
      Dir.mkdir_p(dir) unless Dir.exists?(dir)

      if File.exists?(path)
        warning "Skipped (exists): #{path}"
      else
        File.write(path, content)
        info "Created: #{path}"
      end
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("generate", ["g"], AmberCLI::Commands::GenerateCommand)
