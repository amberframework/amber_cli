require "../core/base_command"
require "../config"

# The `generate` command creates models, controllers, migrations, scaffolds,
# jobs, mailers, schemas, and channels for an Amber V2 application.
#
# ## Usage
# ```
# amber generate [TYPE][NAME][FIELDS...]
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
    VALID_TYPES   = %w[model controller scaffold migration mailer job schema channel api auth]
    PREVIEW_TYPES = %w[api auth]

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
      "reference" => {type: "Int64", options: ""},
    }

    DEFAULT_AUTH_MODEL_NAME = "User"

    getter generator_type : String = ""
    getter name : String = ""
    getter fields : Array(Tuple(String, String)) = [] of Tuple(String, String)
    getter actions : Array(String) = [] of String

    # Association names for `name:reference` fields. Each one becomes a
    # `belongs_to` and a `<name>_id` foreign key column.
    getter references : Array(String) = [] of String

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

      if remaining_arguments.size < 2 && generator_type != "auth"
        error "Name is required"
        puts option_parser
        exit(1)
      end

      @name = remaining_arguments[1]? || DEFAULT_AUTH_MODEL_NAME

      # Parse remaining arguments as fields or actions
      (remaining_arguments[2..]? || [] of String).each do |arg|
        if arg.includes?(":")
          parts = arg.split(":")
          field_name = parts[0]
          field_type = parts[1].downcase

          if field_type == "reference"
            association_name = field_name.chomp("_id")
            references << association_name
            field_name = "#{association_name}_id"
          end
          is_required = parts.size > 2 && parts[2].downcase == "required"

          @fields << {field_name, field_type}
          @schema_fields << {field_name, field_type, is_required}
        else
          @actions << arg
        end
      end
    end

    def execute
      if PREVIEW_TYPES.includes?(generator_type)
        warning "#{generator_type} generation is a preview surface in the Amber V2 beta."
        warning "Review the generated authentication or API behavior before production use."
      end

      if File.exists?(".amber.yml") && File.read(".amber.yml").includes?("template: slang")
        warning "Amber V2 supports ECR only; generating ECR output despite the legacy Slang setting."
      end

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
# See: https://github.com/amberframework/amber/blob/v2.0.0-beta.5/docs/guides/background-jobs.md
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
    ECR.render("src/views/#{file_name}_mailer/#{action}.ecr")
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
# See: https://github.com/amberframework/amber/blob/v2.0.0-beta.5/docs/guides/mailer.md
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
      info "  2. Bind it in a controller: schema :create, #{class_name}Schema"
      info "  3. Read typed input: input = validated_as(#{class_name}Schema)"
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
# Bind this contract above an action in its controller:
#   schema :create, #{class_name}Schema
#
# Amber enforces it before the action. Read its request-local typed values with:
#   input = validated_as(#{class_name}Schema)
#
# Direct construction remains useful in this schema's isolated unit spec.
# See: https://amberframework.org/docs/v2/guides/schema-api/
class #{class_name}Schema < Amber::Schema::Definition
#{field_definitions}
end
SCHEMA
    end

    private def schema_spec_template
      # Build valid test data from fields
      schema_field_width = schema_fields.map { |field| field[0].size }.max? || 0
      valid_data_entries = schema_fields.map do |field_name, field_type, _|
        value = case field_type
                when "string", "text", "uuid"  then "\"test_value\""
                when "email"                   then "\"test@example.com\""
                when "integer", "int", "int32" then "1"
                when "int64"                   then "1_i64"
                when "float", "float64"        then "1.0"
                when "decimal"                 then "1.0"
                when "bool", "boolean"         then "false"
                when "time", "timestamp"       then "\"2024-01-01T00:00:00Z\""
                else                                "\"test_value\""
                end
        padding = " " * (schema_field_width - field_name.size)
        "      \"#{field_name}\"#{padding} => JSON::Any.new(#{value}),"
      end.join("\n")

      # Fall back to regular fields if schema_fields is empty
      if valid_data_entries.empty? && !fields.empty?
        field_width = fields.map { |field| field[0].size }.max? || 0
        valid_data_entries = fields.map do |field_name, field_type|
          value = case field_type
                  when "string", "text", "uuid"  then "\"test_value\""
                  when "email"                   then "\"test@example.com\""
                  when "integer", "int", "int32" then "1"
                  when "int64"                   then "1_i64"
                  when "float", "float64"        then "1.0"
                  when "decimal"                 then "1.0"
                  when "bool", "boolean"         then "false"
                  when "time", "timestamp"       then "\"2024-01-01T00:00:00Z\""
                  else                                "\"test_value\""
                  end
          padding = " " * (field_width - field_name.size)
          "      \"#{field_name}\"#{padding} => JSON::Any.new(#{value}),"
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
# See: https://github.com/amberframework/amber/blob/v2.0.0-beta.5/docs/guides/websockets.md
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
# See: https://github.com/amberframework/amber/blob/v2.0.0-beta.5/docs/guides/websockets.md
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

      references.each do |association_name|
        info "#{class_name} belongs_to :#{association_name}; generate the #{association_name.camelcase} model before compiling."
      end

      success "Model #{class_name} generated successfully!"
    end

    private def model_template
      field_definitions = fields.map do |field_name, field_type|
        if field_type == "reference"
          # belongs_to declares the `<name>_id` Int64? foreign key column itself.
          "  belongs_to :#{field_name.chomp("_id")}"
        else
          crystal_type = FIELD_TYPE_MAP[field_type]? || "String"
          crystal_type += "?" unless field_required?(field_name)
          "  column #{field_name} : #{crystal_type}"
        end
      end.join("\n")

      <<-MODEL
class #{class_name} < Grant::Base
  connection primary
  table #{table_name}

  column id : Int64, primary: true

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
  it "uses the #{table_name} table" do
    #{variable_name} = #{class_name}.new
    #{variable_name}.class.table_name.should eq("#{table_name}")
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
               when "index"   then "/#{controller_resource_name}"
               when "show"    then "/#{controller_resource_name}/1"
               when "new"     then "/#{controller_resource_name}/new"
               when "edit"    then "/#{controller_resource_name}/1/edit"
               when "create"  then "/#{controller_resource_name}"
               when "update"  then "/#{controller_resource_name}/1"
               when "destroy" then "/#{controller_resource_name}/1"
               else                "/#{controller_resource_name}"
               end

        <<-SPEC_BLOCK
  pending "add #{verb} #{path} to config/routes.cr, then enable its request spec"
SPEC_BLOCK
      end.join("\n\n")

      <<-SPEC
require "../spec_helper"

describe #{controller_name} do
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
      add_resource_route

      success "Scaffold #{class_name} generated successfully!"
      puts ""
      info "Added resources \"/#{plural_name}\", #{controller_name} to config/routes.cr"
      info "Run 'amber database migrate' before opening /#{plural_name}."
    end

    private def generate_scaffold_schema(content_type = "application/x-www-form-urlencoded")
      schema_path = "src/schemas/#{file_name}_schema.cr"

      field_definitions = schema_fields.map do |field_name, field_type, is_required|
        schema_info = SCHEMA_TYPE_MAP[field_type]? || {type: "String", options: ""}
        crystal_type = schema_info[:type]
        extra_options = schema_info[:options]
        required_option = is_required ? ", required: true" : ""
        "  field :#{field_name}, #{crystal_type}#{required_option}#{extra_options}"
      end.join("\n")

      content = <<-SCHEMA
# Schema for validating #{class_name} create/update parameters.
#
# Used by #{controller_name} for request validation.
#
# See: https://amberframework.org/docs/v2/guides/schema-api/
class #{class_name}Schema < Amber::Schema::Definition
  content_type "#{content_type}"

#{field_definitions}
end
SCHEMA

      create_file(schema_path, content)
    end

    private def generate_controller_for_scaffold
      controller_path = "src/controllers/#{file_name}_controller.cr"
      create_file(controller_path, scaffold_controller_template)

      create_file("spec/support/csrf_helpers.cr", csrf_helpers_template)

      spec_path = "spec/controllers/#{file_name}_controller_spec.cr"
      create_file(spec_path, scaffold_spec_template)
    end

    private def scaffold_controller_template
      template_ext = detect_template_extension

      schema_field_assignments = fields.map do |field_name, _|
        suffix = field_required?(field_name) ? ".not_nil!" : ""
        "    #{variable_name}.#{field_name} = schema.#{field_name}#{suffix}"
      end.join("\n")

      update_field_assignments = fields.map do |field_name, _|
        suffix = field_required?(field_name) ? ".not_nil!" : ""
        "      #{variable_name}.#{field_name} = schema.#{field_name}#{suffix}"
      end.join("\n")

      <<-CONTROLLER
class #{controller_name} < ApplicationController
  schema :create, #{class_name}Schema
  schema :update, #{class_name}Schema

  @#{plural_variable_name} = [] of #{class_name}
  @#{variable_name} = #{class_name}.new
  @errors = [] of Amber::Schema::Error

  def index
    @#{plural_variable_name} = #{class_name}.order(id: :desc).to_a
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
    schema = validated_as(#{class_name}Schema)
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
      schema = validated_as(#{class_name}Schema)
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

  protected def handle_schema_validation_failure(
    action : Symbol,
    result : Amber::Schema::LegacyResult,
  ) : Nil
    @errors = result.errors
    error = result.errors.first?
    response.status_code = error.is_a?(Amber::Schema::RequestParseError) ? error.http_status : 422
    response.content_type = "text/html"
    flash[:danger] = "Validation failed"

    case action
    when :create
      @#{variable_name} = #{class_name}.new
      context.content = render("new.#{template_ext}")
    when :update
      if #{variable_name} = #{class_name}.find(params[:id])
        @#{variable_name} = #{variable_name}
        context.content = render("edit.#{template_ext}")
      else
        flash[:danger] = "#{class_name} not found"
        redirect_to "/#{plural_name}"
      end
    else
      super
    end
  end
end
CONTROLLER
    end

    private def scaffold_spec_template
      changed_field = fields.find { |_, type| %w[string text email].includes?(type) }
      sample_hash = form_hash_literal
      updated_hash = changed_field ? form_hash_literal(changed_field[0], "Updated") : sample_hash

      update_check = if changed_field
                       <<-CHECK

      if reloaded = #{class_name}.find(saved.id)
        reloaded.#{changed_field[0]}.should eq("Updated")
      else
        fail "#{class_name} disappeared after the update"
      end
CHECK
                     else
                       ""
                     end

      <<-SPEC
require "../spec_helper"
require "../support/csrf_helpers"

#{parent_helpers_source}def create_sample_#{variable_name} : #{class_name}
  saved = #{class_name}.new
#{fields.map { |field_name, field_type| "  saved.#{field_name} = #{sample_expression(field_name, field_type)}" }.join("\n")}
  saved.save.should be_true
  saved
end

describe #{controller_name} do
  before_each do
    #{class_name}.clear
#{parent_clear_source}  end

  describe "GET /#{plural_name}" do
    it "responds successfully" do
      response = get("/#{plural_name}")
      assert_response_success(response)
    end

    it "lists the newest #{plural_name} first" do
      older = create_sample_#{variable_name}
      newer = create_sample_#{variable_name}
      #{class_name}.order(id: :desc).to_a.map(&.id).should eq([newer.id, older.id])
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
      saved = create_sample_#{variable_name}
      response = get("/#{plural_name}/\#{saved.id}")
      assert_response_success(response)
    end
  end

  describe "GET /#{plural_name}/:id/edit" do
    it "responds successfully" do
      saved = create_sample_#{variable_name}
      response = get("/#{plural_name}/\#{saved.id}/edit")
      assert_response_success(response)
    end
  end

  describe "POST /#{plural_name}" do
    it "creates a new #{class_name.underscore}" do
      headers = csrf_headers("/#{plural_name}/new")
      response = post("/#{plural_name}", body: HTTP::Params.encode(#{sample_hash}), headers: headers)
      assert_response_redirect(response)
      #{class_name}.all.to_a.size.should eq(1)
    end

    it "rejects a request without a CSRF token" do
      headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}
      response = post("/#{plural_name}", body: HTTP::Params.encode(#{sample_hash}), headers: headers)
      assert_response_status(response, 403)
      #{class_name}.all.to_a.size.should eq(0)
    end
  end

  describe "PUT /#{plural_name}/:id" do
    it "updates the #{class_name.underscore}" do
      saved = create_sample_#{variable_name}
      headers = csrf_headers("/#{plural_name}/\#{saved.id}/edit")
      response = put("/#{plural_name}/\#{saved.id}", body: HTTP::Params.encode(#{updated_hash}), headers: headers)
      assert_response_redirect(response)
#{update_check}
    end
  end

  describe "DELETE /#{plural_name}/:id" do
    it "deletes the #{class_name.underscore}" do
      saved = create_sample_#{variable_name}
      headers = csrf_headers("/#{plural_name}/\#{saved.id}/edit")
      response = delete("/#{plural_name}/\#{saved.id}", headers: headers)
      assert_response_redirect(response)
      #{class_name}.find(saved.id).should be_nil
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

-- +micrate Up
-- Add SQL to apply the migration here.

-- +micrate Down
-- Add SQL to roll the migration back here.

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
      generate_scaffold_schema("application/json")

      # API controller (JSON only)
      api_dir = "src/controllers/api"
      Dir.mkdir_p(api_dir) unless Dir.exists?(api_dir)

      api_controller_path = "#{api_dir}/#{file_name}_controller.cr"
      create_file(api_controller_path, api_controller_template)

      spec_path = "spec/controllers/api_#{file_name}_controller_spec.cr"
      create_file(spec_path, api_spec_template)

      add_api_route

      success "API #{class_name} generated successfully!"
      puts ""
      info "Added resources \"/#{plural_name}\", Api::#{controller_name} under /api in config/routes.cr"
      info "Run 'amber database migrate' before calling /api/#{plural_name}."
    end

    private def api_controller_template
      schema_field_assignments = fields.map do |field_name, _|
        suffix = field_required?(field_name) ? ".not_nil!" : ""
        "      #{variable_name}.#{field_name} = schema.#{field_name}#{suffix}"
      end.join("\n")

      update_field_assignments = fields.map do |field_name, _|
        suffix = field_required?(field_name) ? ".not_nil!" : ""
        "        #{variable_name}.#{field_name} = schema.#{field_name}#{suffix}"
      end.join("\n")

      <<-CONTROLLER
module Api
  class #{controller_name} < ApplicationController
    schema :create, #{class_name}Schema
    schema :update, #{class_name}Schema

    def index
      #{plural_variable_name} = #{class_name}.order(id: :desc).to_a
      respond_with { json #{plural_variable_name}.to_json }
    end

    def show
      if #{variable_name} = #{class_name}.find(params[:id])
        respond_with { json #{variable_name}.to_json }
      else
        respond_with(404) { json({error: "#{class_name} not found"}.to_json) }
      end
    end

    def create
      schema = validated_as(#{class_name}Schema)
      #{variable_name} = #{class_name}.new
#{schema_field_assignments}

      if #{variable_name}.save
        respond_with(201) { json #{variable_name}.to_json }
      else
        respond_with(422) { json({error: "Could not create #{class_name}"}.to_json) }
      end
    end

    def update
      if #{variable_name} = #{class_name}.find(params[:id])
        schema = validated_as(#{class_name}Schema)
#{update_field_assignments}

        if #{variable_name}.save
          respond_with { json #{variable_name}.to_json }
        else
          respond_with(422) { json({error: "Could not update #{class_name}"}.to_json) }
        end
      else
        respond_with(404) { json({error: "#{class_name} not found"}.to_json) }
      end
    end

    def destroy
      if #{variable_name} = #{class_name}.find(params[:id])
        #{variable_name}.destroy
        respond_with { json({message: "#{class_name} deleted"}.to_json) }
      else
        respond_with(404) { json({error: "#{class_name} not found"}.to_json) }
      end
    end
  end
end
CONTROLLER
    end

    private def api_spec_template
      sample_json = fields.map { |field_name, field_type| "#{field_name}: #{sample_expression(field_name, field_type)}" }.join(", ")
      changed_field = fields.find { |_, type| %w[string text email].includes?(type) }
      updated_json = fields.map do |field_name, field_type|
        value = changed_field && changed_field[0] == field_name ? "\"Updated\"" : sample_expression(field_name, field_type)
        "#{field_name}: #{value}"
      end.join(", ")

      update_check = if changed_field
                       "      assert_json_body(response)[\"#{changed_field[0]}\"].as_s.should eq(\"Updated\")"
                     else
                       ""
                     end

      <<-SPEC
require "../spec_helper"

#{parent_helpers_source}def create_sample_#{variable_name} : #{class_name}
  saved = #{class_name}.new
#{fields.map { |field_name, field_type| "  saved.#{field_name} = #{sample_expression(field_name, field_type)}" }.join("\n")}
  saved.save.should be_true
  saved
end

describe Api::#{controller_name} do
  before_each do
    #{class_name}.clear
#{parent_clear_source}  end

  describe "GET /api/#{plural_name}" do
    it "responds with a JSON list, newest first" do
      older = create_sample_#{variable_name}
      newer = create_sample_#{variable_name}
      response = get("/api/#{plural_name}")
      assert_response_success(response)
      assert_json_content_type(response)
      response.json.as_a.map { |row| row["id"].as_i64 }.should eq([newer.id, older.id])
    end
  end

  describe "GET /api/#{plural_name}/:id" do
    it "responds with the record" do
      saved = create_sample_#{variable_name}
      response = get("/api/#{plural_name}/\#{saved.id}")
      assert_response_success(response)
      assert_json_content_type(response)
      response.json["id"].as_i64.should eq(saved.id)
    end

    it "responds with 404 for an unknown id" do
      response = get("/api/#{plural_name}/0")
      assert_response_not_found(response)
      assert_json_content_type(response)
    end
  end

  describe "POST /api/#{plural_name}" do
    it "creates a new #{class_name.underscore}" do
      response = post_json("/api/#{plural_name}", {#{sample_json}})
      assert_response_status(response, 201)
      assert_json_content_type(response)
      #{class_name}.all.to_a.size.should eq(1)
    end
  end

  describe "PUT /api/#{plural_name}/:id" do
    it "updates the #{class_name.underscore}" do
      saved = create_sample_#{variable_name}
      response = put_json("/api/#{plural_name}/\#{saved.id}", {#{updated_json}})
      assert_response_success(response)
#{update_check}
    end
  end

  describe "DELETE /api/#{plural_name}/:id" do
    it "deletes the #{class_name.underscore}" do
      saved = create_sample_#{variable_name}
      response = delete("/api/#{plural_name}/\#{saved.id}")
      assert_response_success(response)
      #{class_name}.find(saved.id).should be_nil
    end
  end
end
SPEC
    end

    # =========================================================================
    # Auth Generator (V2)
    # =========================================================================

    private def generate_auth
      info "Generating authentication system for #{class_name}"

      template_ext = detect_template_extension

      # The model declares password_digest and email itself; the migration
      # needs them as required columns.
      @fields = [{"email", "string"}, {"password_digest", "string"}]
      @schema_fields = [{"email", "string", true}, {"password_digest", "string", true}]

      create_file("src/models/#{file_name}.cr", auth_model_template)
      generate_migration_for_model
      create_file("spec/models/#{file_name}_spec.cr", auth_model_spec_template)

      create_file("src/controllers/session_controller.cr", session_controller_template(template_ext))
      create_file("src/controllers/registration_controller.cr", registration_controller_template(template_ext))

      create_file("src/views/session/new.#{template_ext}", login_view_template)
      create_file("src/views/registration/new.#{template_ext}", register_view_template)

      create_file("spec/support/csrf_helpers.cr", csrf_helpers_template)
      create_file("spec/controllers/authentication_controller_spec.cr", auth_controller_spec_template)

      add_routes([
        "    get \"/login\", SessionController, :new",
        "    post \"/session\", SessionController, :create",
        "    delete \"/session\", SessionController, :destroy",
        "    get \"/register\", RegistrationController, :new",
        "    post \"/register\", RegistrationController, :create",
      ])

      success "Authentication system generated!"
      puts ""
      info "Added login, logout, and registration routes to config/routes.cr"
      info "Run 'amber database migrate' before opening /register."
    end

    private def auth_model_template
      <<-MODEL
require "crypto/bcrypt/password"

class #{class_name} < Grant::Base
  connection primary
  table #{table_name}

  MINIMUM_PASSWORD_LENGTH = 8

  column id : Int64, primary: true
  column email : String?
  column password_digest : String?

  timestamps

  # The plain-text password is only held in memory. Only its bcrypt digest
  # is stored.
  getter password : String?

  def password=(value : String) : String
    @password = value
    self.password_digest = Crypto::Bcrypt::Password.create(value).to_s
    value
  end

  validate :email, "can't be blank" do |#{variable_name}|
    !#{variable_name}.email.to_s.strip.empty?
  end

  validate :email, "is already taken" do |#{variable_name}|
    email = #{variable_name}.email.to_s
    existing = #{class_name}.find_by(email: email)
    existing.nil? || existing.id == #{variable_name}.id
  end

  validate :password_digest, "can't be blank" do |#{variable_name}|
    !#{variable_name}.password_digest.to_s.empty?
  end

  validate :password, "is too short" do |#{variable_name}|
    plain_text = #{variable_name}.password
    plain_text.nil? || plain_text.size >= MINIMUM_PASSWORD_LENGTH
  end

  # Returns the #{variable_name} when the email and password match, otherwise nil.
  def self.authenticate(email : String?, password : String?) : #{class_name}?
    return nil if email.nil? || password.nil?

    #{variable_name} = find_by(email: email)
    return nil if #{variable_name}.nil?

    digest = #{variable_name}.password_digest
    return nil if digest.nil?

    #{variable_name} if Crypto::Bcrypt::Password.new(digest).verify(password)
  rescue Crypto::Bcrypt::Error
    nil
  end
end
MODEL
    end

    private def auth_model_spec_template
      <<-SPEC
require "../spec_helper"

def create_#{variable_name}(email = "person@example.com", password = "correct horse") : #{class_name}
  #{variable_name} = #{class_name}.new
  #{variable_name}.email = email
  #{variable_name}.password = password
  #{variable_name}.save.should be_true
  #{variable_name}
end

describe #{class_name} do
  before_each do
    #{class_name}.clear
  end

  it "uses the #{table_name} table" do
    #{class_name}.table_name.should eq("#{table_name}")
  end

  it "stores a bcrypt digest and never the plain-text password" do
    #{variable_name} = create_#{variable_name}
    #{variable_name}.password_digest.to_s.should_not contain("correct horse")
    #{variable_name}.password_digest.to_s.should start_with("$2")
  end

  it "authenticates with the right email and password" do
    created = create_#{variable_name}
    found = #{class_name}.authenticate("person@example.com", "correct horse")
    found.should_not be_nil
    found.try(&.id).should eq(created.id)
  end

  it "rejects a wrong password" do
    create_#{variable_name}
    #{class_name}.authenticate("person@example.com", "wrong password").should be_nil
  end

  it "rejects an unknown email" do
    #{class_name}.authenticate("nobody@example.com", "correct horse").should be_nil
  end

  it "rejects a missing email or password" do
    #{class_name}.authenticate(nil, "correct horse").should be_nil
    #{class_name}.authenticate("person@example.com", nil).should be_nil
  end

  it "does not save a duplicate email" do
    create_#{variable_name}
    duplicate = #{class_name}.new
    duplicate.email = "person@example.com"
    duplicate.password = "another password"
    duplicate.save.should be_false
  end

  it "does not save a password that is too short" do
    #{variable_name} = #{class_name}.new
    #{variable_name}.email = "short@example.com"
    #{variable_name}.password = "short"
    #{variable_name}.save.should be_false
  end
end
SPEC
    end

    private def session_controller_template(template_ext : String)
      <<-CONTROLLER
class SessionController < ApplicationController
  def new
    render("new.#{template_ext}")
  end

  def create
    #{variable_name} = #{class_name}.authenticate(params["email"]?, params["password"]?)

    if #{variable_name}
      session[:#{variable_name}_id] = #{variable_name}.id.to_s
      flash[:success] = "Welcome back!"
      redirect_to "/"
    else
      response.status_code = 401
      flash[:danger] = "Invalid email or password"
      render("new.#{template_ext}")
    end
  end

  def destroy
    session.delete(:#{variable_name}_id)
    flash[:info] = "You have been logged out"
    redirect_to "/"
  end
end
CONTROLLER
    end

    private def registration_controller_template(template_ext : String)
      <<-CONTROLLER
class RegistrationController < ApplicationController
  def new
    render("new.#{template_ext}")
  end

  def create
    password = params["password"]?.to_s

    #{variable_name} = #{class_name}.new
    #{variable_name}.email = params["email"]?.to_s
    #{variable_name}.password = password if password == params["password_confirmation"]?.to_s

    if #{variable_name}.save
      session[:#{variable_name}_id] = #{variable_name}.id.to_s
      flash[:success] = "Welcome! Your account has been created."
      redirect_to "/"
    else
      response.status_code = 422
      flash[:danger] = "Could not create account"
      render("new.#{template_ext}")
    end
  end
end
CONTROLLER
    end

    private def login_view_template
      <<-VIEW
<h1>Login</h1>

<form action="/session" method="POST">
  <%= csrf_tag %>
  <div class="form-group">
    <%= label("email") %>
    <%= email_field("email") %>
  </div>
  <div class="form-group">
    <%= label("password") %>
    <%= password_field("password") %>
  </div>
  <%= submit_button("Login") %>
</form>
VIEW
    end

    private def register_view_template
      <<-VIEW
<h1>Create Account</h1>

<form action="/register" method="POST">
  <%= csrf_tag %>
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
</form>
VIEW
    end

    private def auth_controller_spec_template
      <<-SPEC
require "../spec_helper"
require "../support/csrf_helpers"

describe SessionController do
  before_each do
    #{class_name}.clear
  end

  describe "GET /login" do
    it "renders the login form" do
      response = get("/login")
      assert_response_success(response)
      assert_body_contains(response, "Login")
    end
  end

  describe "POST /session" do
    it "logs in with the right password" do
      #{variable_name} = #{class_name}.new
      #{variable_name}.email = "person@example.com"
      #{variable_name}.password = "correct horse"
      #{variable_name}.save.should be_true

      headers = csrf_headers("/login")
      body = HTTP::Params.encode({"email" => "person@example.com", "password" => "correct horse"})
      response = post("/session", body: body, headers: headers)
      assert_redirect_to(response, "/")
    end

    it "rejects a wrong password" do
      headers = csrf_headers("/login")
      body = HTTP::Params.encode({"email" => "person@example.com", "password" => "wrong password"})
      response = post("/session", body: body, headers: headers)
      assert_response_status(response, 401)
    end

    it "rejects a request without a CSRF token" do
      body = HTTP::Params.encode({"email" => "person@example.com", "password" => "correct horse"})
      headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}
      response = post("/session", body: body, headers: headers)
      assert_response_status(response, 403)
    end
  end

  describe "DELETE /session" do
    it "logs out" do
      headers = csrf_headers("/login")
      response = delete("/session", headers: headers)
      assert_redirect_to(response, "/")
    end
  end
end

describe RegistrationController do
  before_each do
    #{class_name}.clear
  end

  describe "GET /register" do
    it "renders the registration form" do
      response = get("/register")
      assert_response_success(response)
      assert_body_contains(response, "Create Account")
    end
  end

  describe "POST /register" do
    it "creates an account" do
      headers = csrf_headers("/register")
      body = HTTP::Params.encode({
        "email"                 => "new@example.com",
        "password"              => "correct horse",
        "password_confirmation" => "correct horse",
      })
      response = post("/register", body: body, headers: headers)
      assert_redirect_to(response, "/")
      #{class_name}.all.to_a.size.should eq(1)
    end

    it "does not create an account when the confirmation differs" do
      headers = csrf_headers("/register")
      body = HTTP::Params.encode({
        "email"                 => "new@example.com",
        "password"              => "correct horse",
        "password_confirmation" => "different",
      })
      response = post("/register", body: body, headers: headers)
      assert_response_status(response, 422)
      #{class_name}.all.to_a.size.should eq(0)
    end
  end
end
SPEC
    end

    # =========================================================================
    # SQL Migration Templates
    # =========================================================================

    private def create_table_migration
      column_definitions = fields.map do |field_name, field_type|
        sql_type = case field_type
                   when "string", "email"         then "VARCHAR(255)"
                   when "uuid"                    then database_type == "pg" ? "UUID" : "VARCHAR(36)"
                   when "text"                    then "TEXT"
                   when "integer", "int", "int32" then "INTEGER"
                   when "int64", "reference"      then "BIGINT"
                   when "float", "float64"        then "DOUBLE PRECISION"
                   when "decimal"                 then "DECIMAL(10,2)"
                   when "bool", "boolean"         then "BOOLEAN DEFAULT FALSE"
                   when "time", "timestamp"       then "TIMESTAMP"
                   else                                "VARCHAR(255)"
                   end
        nullability = field_required?(field_name) ? " NOT NULL" : ""
        "  #{field_name} #{sql_type}#{nullability}"
      end.join(",\n")

      field_sql = column_definitions.empty? ? "" : "#{column_definitions},\n"

      <<-SQL
-- +micrate Up
-- Create #{table_name} table
CREATE TABLE IF NOT EXISTS #{table_name} (
  #{primary_key_sql},
#{field_sql}  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- +micrate Down
DROP TABLE IF EXISTS #{table_name};
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

== render(partial: "_form.slang")

a href="/#{plural_name}" Back
VIEW
      else
        <<-VIEW
<h1>New #{class_name}</h1>

<%= render(partial: "_form.ecr") %>

<a href="/#{plural_name}">Back</a>
VIEW
      end
    end

    private def edit_view_template(ext : String)
      if ext == "slang"
        <<-VIEW
h1 Edit #{class_name}

== render(partial: "_form.slang")

a href="/#{plural_name}" Back
VIEW
      else
        <<-VIEW
<h1>Edit #{class_name}</h1>

<%= render(partial: "_form.ecr") %>

<a href="/#{plural_name}">Back</a>
VIEW
      end
    end

    private def form_partial_template(ext : String)
      if ext == "slang"
        form_fields = fields.map do |field_name, field_type|
          input_type = case field_type
                       when "text"                                                              then "textarea"
                       when "bool", "boolean"                                                   then "checkbox"
                       when "integer", "int", "int32", "int64", "reference", "float", "decimal" then "number"
                       else                                                                          "text"
                       end

          if input_type == "textarea"
            <<-FIELD
  .form-group
    label for="#{field_name}" #{field_name.camelcase}
    textarea id="#{field_name}" name="#{field_name}" = @#{variable_name}.try(&.#{field_name})
FIELD
          elsif input_type == "checkbox"
            <<-FIELD
  .form-group
    label for="#{field_name}"
      input id="#{field_name}" type="checkbox" name="#{field_name}" checked=@#{variable_name}.try(&.#{field_name})
      | #{field_name.camelcase}
FIELD
          else
            <<-FIELD
  .form-group
    label for="#{field_name}" #{field_name.camelcase}
    input id="#{field_name}" type="#{input_type}" name="#{field_name}" value=@#{variable_name}.try(&.#{field_name})
FIELD
          end
        end.join("\n")

        <<-VIEW
- form_action = @#{variable_name}.persisted? ? "/#{plural_name}/\#{@#{variable_name}.id}" : "/#{plural_name}"
== form(action: form_action, method: "post") do
  - if @#{variable_name}.persisted?
    input type="hidden" name="_method" value="PATCH"
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
    <%= text_area("#{field_name}", value: @#{variable_name}.#{field_name}?) %>
  </div>
FIELD
          when "bool", "boolean"
            <<-FIELD
  <div class="form-group">
    <%= checkbox("#{field_name}", checked: @#{variable_name}.#{field_name}? || false, value: "true") %>
    <%= label("#{field_name}") %>
  </div>
FIELD
          when "email"
            <<-FIELD
  <div class="form-group">
    <%= label("#{field_name}") %>
    <%= email_field("#{field_name}", value: @#{variable_name}.#{field_name}?) %>
  </div>
FIELD
          when "time", "timestamp"
            <<-FIELD
  <div class="form-group">
    <%= label("#{field_name}") %>
    <%= text_field("#{field_name}", value: @#{variable_name}.#{field_name}?.try(&.to_rfc3339)) %>
  </div>
FIELD
          when "integer", "int", "int32", "int64", "reference", "float", "float64", "decimal"
            <<-FIELD
  <div class="form-group">
    <%= label("#{field_name}") %>
    <%= number_field("#{field_name}", value: @#{variable_name}.#{field_name}?) %>
  </div>
FIELD
          else
            <<-FIELD
  <div class="form-group">
    <%= label("#{field_name}") %>
    <%= text_field("#{field_name}", value: @#{variable_name}.#{field_name}?) %>
  </div>
FIELD
          end
        end.join("\n")

        <<-VIEW
<% unless @errors.empty? %>
  <div class="form-errors" role="alert">
    <p>Please correct the following:</p>
    <ul>
      <% @errors.each do |error| %>
        <li><%= error.field %>: <%= error.message || "is invalid" %></li>
      <% end %>
    </ul>
  </div>
<% end %>

<form action="<%= @#{variable_name}.persisted? ? "/#{plural_name}/\#{@#{variable_name}.id}" : "/#{plural_name}" %>" method="POST">
  <%= csrf_tag %>
  <% if @#{variable_name}.persisted? %>
    <%= hidden_field("_method", "PATCH") %>
  <% end %>
#{form_fields}
  <%= submit_button("Save") %>
</form>
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

    # Controller names are conventionally plural (for example `Posts`). Avoid
    # turning an already-plural resource into `postses` in route guidance.
    private def controller_resource_name
      file_name.ends_with?("s") ? file_name : plural_name
    end

    private def default_actions
      %w[index show new create edit update destroy]
    end

    private def field_required?(field_name : String) : Bool
      schema_fields.find { |field| field[0] == field_name }.try(&.[2]) || false
    end

    private def database_type : String
      Amber::CLI.config.database
    end

    private def primary_key_sql : String
      case database_type
      when "pg"
        "id BIGSERIAL PRIMARY KEY"
      when "mysql"
        "id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY"
      else
        "id INTEGER PRIMARY KEY AUTOINCREMENT"
      end
    end

    private def csrf_helpers_template
      <<-SUPPORT
require "../spec_helper"

class CsrfTokenNotFound < Exception
end

# Amber's CSRF pipe rejects POST, PUT, PATCH, and DELETE requests unless they
# carry the token stored in the session. These helpers work the way a browser
# does: request a page that renders a form, then send the session cookie and
# the token from that page with the next request.
module CsrfSpecHelpers
  # Headers that make a write request pass the CSRF pipe. `form_path` must be
  # a page that renders `csrf_tag`, such as a new or edit form.
  def csrf_headers(form_path : String, content_type : String = "application/x-www-form-urlencoded") : HTTP::Headers
    page = get(form_path)
    token_match = page.body.match(/name="_csrf" value="([^"]+)"/)
    raise CsrfTokenNotFound.new("No CSRF token found in GET \#{form_path}; render csrf_tag in that page") if token_match.nil?

    headers = HTTP::Headers{"X-CSRF-TOKEN" => token_match[1], "Content-Type" => content_type}
    set_cookies = page.headers.get?("Set-Cookie")
    unless set_cookies.nil?
      headers["Cookie"] = set_cookies.map { |cookie| cookie.split(';').first }.join("; ")
    end
    headers
  end
end

include CsrfSpecHelpers
SUPPORT
    end

    # A Crystal Hash(String, String) literal of sample form values, used to
    # build request bodies in generated specs.
    private def form_hash_literal(override_field : String? = nil, override_value : String? = nil) : String
      pairs = fields.map do |field_name, field_type|
        value = if field_name == override_field
                  override_value.to_s.inspect
                elsif field_type == "reference"
                  "create_parent_#{field_name.chomp("_id")}.id.to_s"
                else
                  sample_form_value(field_type).inspect
                end
        "#{field_name.inspect} => #{value}"
      end
      "{#{pairs.join(", ")}} of String => String"
    end

    # Crystal source for a typed sample value of one field.
    private def sample_expression(field_name : String, field_type : String) : String
      if field_type == "reference"
        "create_parent_#{field_name.chomp("_id")}.id"
      else
        sample_literal(field_type)
      end
    end

    # Spec helpers that create the parent record of each `belongs_to`.
    # Grant validates that the parent exists, so a child cannot be saved
    # without one. Required (non-nilable) columns of an existing parent model
    # are filled in from its source file.
    private def parent_helpers_source : String
      references.map do |association_name|
        parent_class = association_name.camelcase
        assignments = required_column_assignments(association_name).map { |line| "  #{line}\n" }.join
        "def create_parent_#{association_name} : #{parent_class}\n" \
        "  parent = #{parent_class}.new\n" \
        "#{assignments}" \
        "  parent.save(validate: false).should be_true\n" \
        "  parent\n" \
        "end\n\n"
      end.join
    end

    private def parent_clear_source : String
      references.map { |association_name| "    #{association_name.camelcase}.clear\n" }.join
    end

    private def required_column_assignments(association_name : String) : Array(String)
      model_path = "src/models/#{association_name.underscore}.cr"
      return [] of String unless File.exists?(model_path)

      File.read_lines(model_path).compact_map do |line|
        match = line.match(/^\s*column (\w+) : (String|Int32|Int64|Float64|Bool|Time)\s*$/)
        next if match.nil?

        literal = case match[2]
                  when "String"  then "\"Sample\""
                  when "Int32"   then "1"
                  when "Int64"   then "1_i64"
                  when "Float64" then "1.5"
                  when "Bool"    then "true"
                  else                "Time.utc(2026, 1, 1)"
                  end
        "parent.#{match[1]} = #{literal}"
      end
    end

    private def sample_form_value(field_type : String) : String
      case field_type
      when "text"                                          then "Sample text"
      when "email"                                         then "sample@example.com"
      when "integer", "int", "int32", "int64", "reference" then "1"
      when "float", "float64", "decimal"                   then "1.5"
      when "bool", "boolean"                               then "true"
      when "time", "timestamp"                             then "2026-01-01T00:00:00Z"
      when "uuid"                                          then "3f2b8c1e-5d4a-4e6f-9b7a-1c2d3e4f5a6b"
      else                                                      "Sample"
      end
    end

    # Crystal source for a typed sample value, used to build records in specs.
    private def sample_literal(field_type : String) : String
      case field_type
      when "integer", "int", "int32"     then "1"
      when "int64", "reference"          then "1_i64"
      when "float", "float64", "decimal" then "1.5"
      when "bool", "boolean"             then "true"
      when "time", "timestamp"           then "Time.utc(2026, 1, 1)"
      else                                    sample_form_value(field_type).inspect
      end
    end

    private def add_resource_route
      add_routes(["    resources \"/#{plural_name}\", #{controller_name}"])
    end

    private def add_api_route
      routes_path = "config/routes.cr"
      unless File.exists?(routes_path)
        warning "Could not add the API route because #{routes_path} does not exist."
        return
      end

      content = File.read(routes_path)
      route = "    resources \"/#{plural_name}\", Api::#{controller_name}, except: [:new, :edit]"
      return if content.includes?(route)

      newline = content.includes?("\r\n") ? "\r\n" : "\n"
      active_anchor = "  routes :api, \"/api\" do"
      commented_block = /(?:^  # API routes must stay[^\n]*\n  # would otherwise[^\n]*\n)?^  # routes :api do\r?\n  # end\r?\n(?:\r?\n)?/m
      static_anchor = "  routes :static do"
      api_block = "#{active_anchor}#{newline}#{route}#{newline}  end#{newline}#{newline}"

      if content.includes?(active_anchor)
        File.write(routes_path, content.sub(active_anchor, "#{active_anchor}#{newline}#{route}"))
      elsif content.includes?(static_anchor)
        # The static block ends in a wildcard GET route, so the API routes
        # must be declared before it or GET /api/... falls through to it.
        File.write(routes_path, content.sub(commented_block, "").sub(static_anchor, "#{api_block}#{static_anchor}"))
      else
        warning "Could not find a place for the API routes block in #{routes_path}."
        info "Add this before the static routes in config/routes.cr:"
        info "  routes :api, \"/api\" do"
        info route
        info "  end"
      end
    end

    private def add_routes(route_lines : Array(String))
      routes_path = "config/routes.cr"
      unless File.exists?(routes_path)
        warning "Could not add routes because #{routes_path} does not exist."
        return
      end

      content = File.read(routes_path)
      anchor = "  routes :web do"
      unless content.includes?(anchor)
        warning "Could not find the web routes block in #{routes_path}."
        return
      end

      newline = content.includes?("\r\n") ? "\r\n" : "\n"
      missing = route_lines.reject { |line| content.includes?(line) }
      return if missing.empty?

      File.write(routes_path, content.sub(anchor, "#{anchor}#{newline}#{missing.join(newline)}"))
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
      "ecr"
    end

    private def create_file(path : String, content : String)
      dir = File.dirname(path)
      Dir.mkdir_p(dir) unless Dir.exists?(dir)

      if File.exists?(path)
        warning "Skipped (exists): #{path}"
      else
        File.write(path, content.ends_with?("\n") ? content : "#{content}\n")
        info "Created: #{path}"
      end
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("generate", ["g"], AmberCLI::Commands::GenerateCommand)
