require "../../spec_helper"
require "../../../../src/amber_lsp/rules/specs/spec_existence_rule"

describe AmberLSP::Rules::Specs::SpecExistenceRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Specs::SpecExistenceRule.new)
  end

  describe "#check" do
    it "produces no diagnostics when spec file exists" do
      with_tempdir do |dir|
        controller_dir = File.join(dir, "src", "controllers")
        spec_dir = File.join(dir, "spec", "controllers")
        Dir.mkdir_p(controller_dir)
        Dir.mkdir_p(spec_dir)

        controller_file = File.join(controller_dir, "posts_controller.cr")
        spec_file = File.join(spec_dir, "posts_controller_spec.cr")
        File.write(controller_file, "class PostsController < ApplicationController\nend")
        File.write(spec_file, "describe PostsController do\nend")

        content = File.read(controller_file)
        rule = AmberLSP::Rules::Specs::SpecExistenceRule.new
        diagnostics = rule.check(controller_file, content)
        diagnostics.should be_empty
      end
    end

    it "reports information when spec file is missing" do
      with_tempdir do |dir|
        controller_dir = File.join(dir, "src", "controllers")
        Dir.mkdir_p(controller_dir)

        controller_file = File.join(controller_dir, "posts_controller.cr")
        File.write(controller_file, "class PostsController < ApplicationController\nend")

        content = File.read(controller_file)
        rule = AmberLSP::Rules::Specs::SpecExistenceRule.new
        diagnostics = rule.check(controller_file, content)
        diagnostics.size.should eq(1)
        diagnostics[0].code.should eq("amber/spec-existence")
        diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Information)
        diagnostics[0].message.should contain("spec")
        diagnostics[0].range.start.line.should eq(0)
        diagnostics[0].range.start.character.should eq(0)
      end
    end

    it "skips application_controller.cr" do
      content = <<-CRYSTAL
      class ApplicationController < Amber::Controller::Base
      end
      CRYSTAL

      rule = AmberLSP::Rules::Specs::SpecExistenceRule.new
      diagnostics = rule.check("src/controllers/application_controller.cr", content)
      diagnostics.should be_empty
    end

    it "skips files not in controllers/ directory" do
      content = <<-CRYSTAL
      class SomeModel
      end
      CRYSTAL

      rule = AmberLSP::Rules::Specs::SpecExistenceRule.new
      diagnostics = rule.check("src/models/some_model.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::Specs::SpecExistenceRule.new
      diagnostics = rule.check("src/controllers/empty_controller.cr", "")
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/spec-existence")
    end

    it "correctly derives spec path from controller path" do
      with_tempdir do |dir|
        controller_dir = File.join(dir, "src", "controllers")
        Dir.mkdir_p(controller_dir)

        controller_file = File.join(controller_dir, "users_controller.cr")
        File.write(controller_file, "class UsersController < ApplicationController\nend")

        content = File.read(controller_file)
        rule = AmberLSP::Rules::Specs::SpecExistenceRule.new
        diagnostics = rule.check(controller_file, content)
        diagnostics.size.should eq(1)
        diagnostics[0].message.should contain("users_controller_spec.cr")
      end
    end
  end
end
