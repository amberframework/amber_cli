require "../../spec_helper"
require "../../../../src/amber_lsp/rules/file_naming/directory_structure_rule"

describe AmberLSP::Rules::FileNaming::DirectoryStructureRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FileNaming::DirectoryStructureRule.new)
  end

  describe "#check" do
    it "produces no diagnostics when controller is in correct directory" do
      content = <<-CRYSTAL
      class PostsController < ApplicationController
        def index
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/controllers/posts_controller.cr", content)
      diagnostics.should be_empty
    end

    it "reports warning when controller is in wrong directory" do
      content = <<-CRYSTAL
      class PostsController < ApplicationController
        def index
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/models/posts_controller.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/directory-structure")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Warning)
      diagnostics[0].message.should contain("src/controllers/")
    end

    it "produces no diagnostics when job is in correct directory" do
      content = <<-CRYSTAL
      class EmailJob < Amber::Jobs::Job
        def perform
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/jobs/email_job.cr", content)
      diagnostics.should be_empty
    end

    it "reports warning when job is in wrong directory" do
      content = <<-CRYSTAL
      class EmailJob < Amber::Jobs::Job
        def perform
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/services/email_job.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("src/jobs/")
    end

    it "produces no diagnostics when mailer is in correct directory" do
      content = <<-CRYSTAL
      class WelcomeMailer < Amber::Mailer::Base
        def html_body
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/mailers/welcome_mailer.cr", content)
      diagnostics.should be_empty
    end

    it "reports warning when mailer is in wrong directory" do
      content = <<-CRYSTAL
      class WelcomeMailer < Amber::Mailer::Base
        def html_body
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/services/welcome_mailer.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("src/mailers/")
    end

    it "produces no diagnostics when channel is in correct directory" do
      content = <<-CRYSTAL
      class ChatChannel < Amber::WebSockets::Channel
        def handle_message
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/channels/chat_channel.cr", content)
      diagnostics.should be_empty
    end

    it "reports warning when channel is in wrong directory" do
      content = <<-CRYSTAL
      class ChatChannel < Amber::WebSockets::Channel
        def handle_message
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/models/chat_channel.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("src/channels/")
    end

    it "produces no diagnostics when schema is in correct directory" do
      content = <<-CRYSTAL
      class UserSchema < Amber::Schema::Definition
        field :name, String
      end
      CRYSTAL

      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/schemas/user_schema.cr", content)
      diagnostics.should be_empty
    end

    it "reports warning when schema is in wrong directory" do
      content = <<-CRYSTAL
      class UserSchema < Amber::Schema::Definition
        field :name, String
      end
      CRYSTAL

      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/models/user_schema.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("src/schemas/")
    end

    it "produces no diagnostics when socket is in correct directory" do
      content = <<-CRYSTAL
      struct UserSocket < Amber::WebSockets::ClientSocket
        channel "chat:*", ChatChannel
      end
      CRYSTAL

      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/sockets/user_socket.cr", content)
      diagnostics.should be_empty
    end

    it "reports warning when socket is in wrong directory" do
      content = <<-CRYSTAL
      struct UserSocket < Amber::WebSockets::ClientSocket
        channel "chat:*", ChatChannel
      end
      CRYSTAL

      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/models/user_socket.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("src/sockets/")
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/models/empty.cr", "")
      diagnostics.should be_empty
    end

    it "produces no diagnostics for regular classes" do
      content = <<-CRYSTAL
      class UserService
        def call
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::FileNaming::DirectoryStructureRule.new
      diagnostics = rule.check("src/services/user_service.cr", content)
      diagnostics.should be_empty
    end
  end
end
