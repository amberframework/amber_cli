require "spec"
require "json"
require "../../src/amber_cli/fsdd_docs/parser"

FSDD_FIXTURE_JSON = <<-JSON
  {
    "repository_name": "TestProject",
    "body": "",
    "program": {
      "html_id": "",
      "path": "",
      "kind": "module",
      "full_name": "TestProject",
      "name": "TestProject",
      "abstract": false,
      "types": [
        {
          "html_id": "auth-service",
          "name": "AuthService",
          "full_name": "AuthService",
          "kind": "class",
          "summary": "Authentication service",
          "doc": "**Personas:** Developer, QA\\n**Requires:** User model exists\\n**Since:** v1.0\\n**Ramp:** Basic → Advanced\\n**Use:** `authenticate(email, password)`\\n**Result:** Returns JWT token on success\\n\\nRefined story: As a Developer, I want to authenticate users so they can access protected resources.",
          "locations": [{"filename": "src/auth_service.cr", "line_number": 1, "url": null}],
          "instance_methods": [
            {
              "html_id": "authenticate",
              "name": "authenticate",
              "abstract": false,
              "args_string": "(email : String, password : String)",
              "doc": "**Personas:** Developer\\n**Use:** `service.authenticate(email, password)`\\n**Result:** Returns Bool",
              "summary": "Authenticate a user by email and password",
              "location": {"filename": "src/auth_service.cr", "line_number": 10, "url": null},
              "def": {
                "name": "authenticate",
                "args": [],
                "return_type": "Bool",
                "visibility": "Public",
                "body": ""
              }
            },
            {
              "html_id": "logout",
              "name": "logout",
              "abstract": false,
              "args_string": "(session_id : String)",
              "doc": null,
              "summary": null,
              "location": {"filename": "src/auth_service.cr", "line_number": 20, "url": null},
              "def": {
                "name": "logout",
                "args": [],
                "return_type": "Nil",
                "visibility": "Public",
                "body": ""
              }
            }
          ],
          "class_methods": [
            {
              "html_id": "create",
              "name": "create",
              "abstract": false,
              "args_string": "(config : Hash(String, String))",
              "doc": null,
              "summary": null,
              "location": {"filename": "src/auth_service.cr", "line_number": 5, "url": null},
              "def": {
                "name": "create",
                "args": [],
                "return_type": "AuthService",
                "visibility": "Public",
                "body": ""
              }
            }
          ],
          "types": []
        },
        {
          "html_id": "plain-module",
          "name": "Helpers",
          "full_name": "Helpers",
          "kind": "module",
          "summary": "Utility helpers",
          "doc": null,
          "locations": [],
          "instance_methods": [],
          "class_methods": [],
          "types": []
        }
      ]
    }
  }
  JSON

describe AmberCLI::FSDDDocs::Parser do
  describe ".parse_json" do
    it "returns a list of ParsedType from valid JSON" do
      json = JSON.parse(FSDD_FIXTURE_JSON)
      types = AmberCLI::FSDDDocs::Parser.parse_json(json)
      types.size.should eq(2)
    end

    it "captures the type name, full_name, and kind" do
      json = JSON.parse(FSDD_FIXTURE_JSON)
      types = AmberCLI::FSDDDocs::Parser.parse_json(json)
      auth = types.find { |t| t.name == "AuthService" }
      auth.should_not be_nil
      auth = auth.not_nil!
      auth.full_name.should eq("AuthService")
      auth.kind.should eq("class")
    end

    it "captures the summary" do
      json = JSON.parse(FSDD_FIXTURE_JSON)
      types = AmberCLI::FSDDDocs::Parser.parse_json(json)
      auth = types.find { |t| t.name == "AuthService" }.not_nil!
      auth.summary.should eq("Authentication service")
    end

    it "captures source locations" do
      json = JSON.parse(FSDD_FIXTURE_JSON)
      types = AmberCLI::FSDDDocs::Parser.parse_json(json)
      auth = types.find { |t| t.name == "AuthService" }.not_nil!
      auth.locations.should eq(["src/auth_service.cr:1"])
    end

    it "parses instance methods" do
      json = JSON.parse(FSDD_FIXTURE_JSON)
      types = AmberCLI::FSDDDocs::Parser.parse_json(json)
      auth = types.find { |t| t.name == "AuthService" }.not_nil!
      instance_methods = auth.methods.select { |m| !m.is_class_method }
      instance_methods.size.should eq(2)
      names = instance_methods.map(&.name)
      names.should contain("authenticate")
      names.should contain("logout")
    end

    it "parses class methods" do
      json = JSON.parse(FSDD_FIXTURE_JSON)
      types = AmberCLI::FSDDDocs::Parser.parse_json(json)
      auth = types.find { |t| t.name == "AuthService" }.not_nil!
      class_methods = auth.methods.select(&.is_class_method)
      class_methods.size.should eq(1)
      class_methods.first.name.should eq("create")
    end

    it "captures method args_string and return_type" do
      json = JSON.parse(FSDD_FIXTURE_JSON)
      types = AmberCLI::FSDDDocs::Parser.parse_json(json)
      auth = types.find { |t| t.name == "AuthService" }.not_nil!
      m = auth.methods.find { |m| m.name == "authenticate" }.not_nil!
      m.args_string.should eq("(email : String, password : String)")
      m.return_type.should eq("Bool")
      m.visibility.should eq("Public")
    end

    it "builds the full method signature" do
      json = JSON.parse(FSDD_FIXTURE_JSON)
      types = AmberCLI::FSDDDocs::Parser.parse_json(json)
      auth = types.find { |t| t.name == "AuthService" }.not_nil!
      m = auth.methods.find { |m| m.name == "authenticate" }.not_nil!
      m.signature.should eq("authenticate(email : String, password : String) : Bool")
    end

    it "captures method source location" do
      json = JSON.parse(FSDD_FIXTURE_JSON)
      types = AmberCLI::FSDDDocs::Parser.parse_json(json)
      auth = types.find { |t| t.name == "AuthService" }.not_nil!
      m = auth.methods.find { |m| m.name == "authenticate" }.not_nil!
      m.location.should eq("src/auth_service.cr:10")
    end

    it "handles missing program gracefully" do
      json = JSON.parse("{}")
      types = AmberCLI::FSDDDocs::Parser.parse_json(json)
      types.should be_empty
    end

    it "generates a safe slug by replacing :: with -" do
      json = JSON.parse(<<-JSON2)
        {"repository_name":"T","body":"","program":{"types":[{"name":"Foo","full_name":"AmberCLI::Commands::Foo","kind":"class","summary":null,"doc":null,"locations":[],"instance_methods":[],"class_methods":[],"types":[]}]}}
        JSON2
      types = AmberCLI::FSDDDocs::Parser.parse_json(json)
      types.first.slug.should eq("AmberCLI-Commands-Foo")
    end
  end

  describe ".extract_fsdd_sections" do
    it "extracts all FSDD labels from a doc comment" do
      doc = "**Personas:** Developer, QA\n**Requires:** User model\n**Since:** v1.0\n**Ramp:** Basic → Advanced\n**Use:** `authenticate(email, password)`\n**Result:** Returns Bool\n\nRefined story: As a Developer, I want to do something."
      sections = AmberCLI::FSDDDocs::Parser.extract_fsdd_sections(doc)
      sections.personas.should eq("Developer, QA")
      sections.requires.should eq("User model")
      sections.since_version.should eq("v1.0")
      sections.ramp.should eq("Basic → Advanced")
      sections.use.should eq("`authenticate(email, password)`")
      sections.result.should eq("Returns Bool")
      sections.story.should_not be_nil
      sections.story.not_nil!.should contain("As a Developer")
    end

    it "returns empty FSDDSections for nil doc" do
      sections = AmberCLI::FSDDDocs::Parser.extract_fsdd_sections(nil)
      sections.has_fsdd_content?.should be_false
    end

    it "returns empty FSDDSections for empty doc" do
      sections = AmberCLI::FSDDDocs::Parser.extract_fsdd_sections("")
      sections.has_fsdd_content?.should be_false
    end

    it "returns nil for labels not present in doc" do
      doc = "**Personas:** Developer"
      sections = AmberCLI::FSDDDocs::Parser.extract_fsdd_sections(doc)
      sections.personas.should eq("Developer")
      sections.requires.should be_nil
      sections.since_version.should be_nil
      sections.ramp.should be_nil
      sections.use.should be_nil
      sections.result.should be_nil
      sections.story.should be_nil
    end

    it "detects has_fsdd_content? correctly" do
      doc = "**Personas:** Developer"
      sections = AmberCLI::FSDDDocs::Parser.extract_fsdd_sections(doc)
      sections.has_fsdd_content?.should be_true
    end

    it "extracts the Refined story block" do
      doc = "Some preamble.\n\nRefined story: As a Developer, I want to authenticate users so they can access protected resources."
      sections = AmberCLI::FSDDDocs::Parser.extract_fsdd_sections(doc)
      sections.story.should_not be_nil
      sections.story.not_nil!.should contain("As a Developer")
    end

    it "extracts summary as first non-label line" do
      doc = "Handles user authentication.\n**Personas:** Developer"
      sections = AmberCLI::FSDDDocs::Parser.extract_fsdd_sections(doc)
      sections.summary.should eq("Handles user authentication.")
    end

    it "skips label lines when extracting summary" do
      doc = "**Personas:** Developer\nHandles user authentication."
      sections = AmberCLI::FSDDDocs::Parser.extract_fsdd_sections(doc)
      sections.summary.should eq("Handles user authentication.")
    end
  end

  describe "ParsedMethod#kind_label" do
    it "returns 'instance' for instance methods" do
      sections = AmberCLI::FSDDDocs::FSDDSections.new
      m = AmberCLI::FSDDDocs::ParsedMethod.new("foo", "()", "Nil", "Public", nil, nil, sections, false)
      m.kind_label.should eq("instance")
    end

    it "returns 'class' for class methods" do
      sections = AmberCLI::FSDDDocs::FSDDSections.new
      m = AmberCLI::FSDDDocs::ParsedMethod.new("foo", "()", "Nil", "Public", nil, nil, sections, true)
      m.kind_label.should eq("class")
    end
  end

  describe "ParsedType#slug" do
    it "converts namespaced name to flat slug" do
      types = AmberCLI::FSDDDocs::Parser.parse_json(JSON.parse(FSDD_FIXTURE_JSON))
      auth = types.find { |t| t.name == "AuthService" }.not_nil!
      auth.slug.should eq("AuthService")
    end
  end
end
