require "../../spec_helper"
require "../../../../src/amber_lsp/rules/routing/controller_action_existence_rule"

describe AmberLSP::Rules::Routing::ControllerActionExistenceRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Routing::ControllerActionExistenceRule.new)
  end

  describe "#check" do
    it "produces no diagnostics when controller file exists" do
      with_tempdir do |dir|
        config_dir = File.join(dir, "config")
        controller_dir = File.join(dir, "src", "controllers")
        Dir.mkdir_p(config_dir)
        Dir.mkdir_p(controller_dir)

        File.write(File.join(controller_dir, "posts_controller.cr"), "class PostsController < ApplicationController\nend")

        routes_file = File.join(config_dir, "routes.cr")
        routes_content = %(  get "/posts", PostsController, :index\n)
        File.write(routes_file, routes_content)

        rule = AmberLSP::Rules::Routing::ControllerActionExistenceRule.new
        diagnostics = rule.check(routes_file, routes_content)
        diagnostics.should be_empty
      end
    end

    it "reports warning when controller file is missing" do
      with_tempdir do |dir|
        config_dir = File.join(dir, "config")
        Dir.mkdir_p(config_dir)
        Dir.mkdir_p(File.join(dir, "src", "controllers"))

        routes_file = File.join(config_dir, "routes.cr")
        routes_content = %(  get "/posts", PostsController, :index\n)
        File.write(routes_file, routes_content)

        rule = AmberLSP::Rules::Routing::ControllerActionExistenceRule.new
        diagnostics = rule.check(routes_file, routes_content)
        diagnostics.size.should eq(1)
        diagnostics[0].code.should eq("amber/route-controller-exists")
        diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Warning)
        diagnostics[0].message.should contain("PostsController")
        diagnostics[0].message.should contain("posts_controller.cr")
      end
    end

    it "handles resources declarations" do
      with_tempdir do |dir|
        config_dir = File.join(dir, "config")
        Dir.mkdir_p(config_dir)
        Dir.mkdir_p(File.join(dir, "src", "controllers"))

        routes_file = File.join(config_dir, "routes.cr")
        routes_content = %(  resources "/users", UsersController\n)
        File.write(routes_file, routes_content)

        rule = AmberLSP::Rules::Routing::ControllerActionExistenceRule.new
        diagnostics = rule.check(routes_file, routes_content)
        diagnostics.size.should eq(1)
        diagnostics[0].message.should contain("UsersController")
      end
    end

    it "handles multiple route declarations" do
      with_tempdir do |dir|
        config_dir = File.join(dir, "config")
        controller_dir = File.join(dir, "src", "controllers")
        Dir.mkdir_p(config_dir)
        Dir.mkdir_p(controller_dir)

        File.write(File.join(controller_dir, "posts_controller.cr"), "class PostsController\nend")

        routes_file = File.join(config_dir, "routes.cr")
        routes_content = <<-CRYSTAL
          get "/posts", PostsController, :index
          post "/comments", CommentsController, :create
          resources "/users", UsersController
        CRYSTAL
        File.write(routes_file, routes_content)

        rule = AmberLSP::Rules::Routing::ControllerActionExistenceRule.new
        diagnostics = rule.check(routes_file, routes_content)
        diagnostics.size.should eq(2)
      end
    end

    it "handles various HTTP verbs" do
      with_tempdir do |dir|
        config_dir = File.join(dir, "config")
        Dir.mkdir_p(config_dir)
        Dir.mkdir_p(File.join(dir, "src", "controllers"))

        routes_file = File.join(config_dir, "routes.cr")
        routes_content = <<-CRYSTAL
          post "/items", ItemsController, :create
          put "/items/:id", ItemsController, :update
          patch "/items/:id", ItemsController, :patch
          delete "/items/:id", ItemsController, :destroy
        CRYSTAL
        File.write(routes_file, routes_content)

        rule = AmberLSP::Rules::Routing::ControllerActionExistenceRule.new
        diagnostics = rule.check(routes_file, routes_content)
        diagnostics.size.should eq(4)
        diagnostics.all? { |d| d.message.includes?("ItemsController") }.should be_true
      end
    end

    it "skips files not named routes.cr" do
      content = %(  get "/posts", PostsController, :index\n)

      rule = AmberLSP::Rules::Routing::ControllerActionExistenceRule.new
      diagnostics = rule.check("src/some_file.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::Routing::ControllerActionExistenceRule.new
      diagnostics = rule.check("config/routes.cr", "")
      diagnostics.should be_empty
    end

    it "converts PascalCase to snake_case correctly" do
      with_tempdir do |dir|
        config_dir = File.join(dir, "config")
        Dir.mkdir_p(config_dir)
        Dir.mkdir_p(File.join(dir, "src", "controllers"))

        routes_file = File.join(config_dir, "routes.cr")
        routes_content = %(  get "/admin/user-settings", AdminUserSettingsController, :index\n)
        File.write(routes_file, routes_content)

        rule = AmberLSP::Rules::Routing::ControllerActionExistenceRule.new
        diagnostics = rule.check(routes_file, routes_content)
        diagnostics.size.should eq(1)
        diagnostics[0].message.should contain("admin_user_settings_controller.cr")
      end
    end
  end
end
