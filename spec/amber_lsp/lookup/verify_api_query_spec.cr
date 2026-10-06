require "../spec_helper"
require "../../../src/amber_lsp/lookup/verify_api_query"

describe AmberLSP::Lookup::VerifyAPIQuery do
  it "upgrades unknown instance and inherited class methods to present" do
    with_probe_project do |project|
      instance_result = verify_query(project, "ProbeAPI::Child#inherited_api")
      class_result = verify_query(project, "ProbeAPI::Child.inherited_class_api")
      extension_result = verify_query(project, "ProbeAPI::Child.extended_class_api")
      instance_result.status.should eq("present")
      class_result.status.should eq("present")
      extension_result.status.should eq("present")
      instance_result.elapsed_milliseconds.should be >= 0
    end
  end

  it "upgrades unknown methods and missing types to absent" do
    with_probe_project do |project|
      method_result = verify_query(project, "ProbeAPI::Child#missing_api")
      type_result = verify_query(project, "ProbeAPI::MissingType")

      method_result.status.should eq("absent")
      method_result.output.should contain("AMBER_LSP_PROBE_ABSENT")
      type_result.status.should eq("absent")
    end
  end

  it "narrows bare method candidates to the first verified owner" do
    with_probe_project do |project|
      absent_candidate = probe_method("ProbeAPI::FirstCandidate", "where")
      present_candidate = probe_method("ProbeAPI::SecondCandidate", "where")
      resolution = AmberLSP::Lookup::APIResolution.new(
        "where",
        "bare_method",
        nil,
        [absent_candidate, present_candidate],
      )

      result = AmberLSP::Lookup::VerifyAPIQuery.new(project, "where", resolution).perform

      result.status.should eq("present")
      result.verified_entry.should_not be_nil
      result.verified_entry.not_nil!.owner.should eq("ProbeAPI::SecondCandidate")
    end
  end

  it "reports the compiler return type for an indexed overload with an unknown docs type" do
    with_probe_project do |project|
      entry = probe_method("ProbeAPI::Child", "select", "class", "()", "unknown")
      resolution = AmberLSP::Lookup::APIResolution.new(
        "ProbeAPI::Child.select",
        "class_method",
        nil,
        [entry],
      )

      result = AmberLSP::Lookup::VerifyAPIQuery.new(project, resolution.query, resolution).perform

      result.status.should eq("present")
      result.output.should contain("verified type: String")
    end
  end

  it "reports a reason when an overload cannot be type checked because it has a splat" do
    with_probe_project do |project|
      entry = probe_method("ProbeAPI::Child", "choices", "class", "(*fields : String)", "unknown")
      resolution = AmberLSP::Lookup::APIResolution.new(
        "ProbeAPI::Child.choices",
        "class_method",
        nil,
        [entry],
      )

      result = AmberLSP::Lookup::VerifyAPIQuery.new(project, resolution.query, resolution).perform

      result.output.should contain("type check skipped: splat parameters are unsupported")
      result.status.should eq("present")
    end
  end

  it "builds a typed call from declared parameter types" do
    with_probe_project do |project|
      entry = probe_method("ProbeAPI::Child", "convert", "instance", "(value : String)", "unknown")
      resolution = AmberLSP::Lookup::APIResolution.new(
        "ProbeAPI::Child#convert",
        "instance_method",
        nil,
        [entry],
      )

      result = AmberLSP::Lookup::VerifyAPIQuery.new(project, resolution.query, resolution).perform

      result.status.should eq("present")
      result.verified_return_type.should eq("String")
      result.list_of_verified_entries.first.verified_return_type.should eq("String")
    end
  end

  it "skips block and untyped parameters with a reason" do
    with_probe_project do |project|
      untyped_entry = probe_method("ProbeAPI::Child", "untyped_parameter", "class", "(value)", "unknown")
      untyped_resolution = AmberLSP::Lookup::APIResolution.new(
        "ProbeAPI::Child.untyped_parameter",
        "class_method",
        nil,
        [untyped_entry],
      )
      block_entry = probe_method("ProbeAPI::Child", "transform", "class", "(&block : String -> Bool)", "unknown")
      block_resolution = AmberLSP::Lookup::APIResolution.new(
        "ProbeAPI::Child.transform",
        "class_method",
        nil,
        [block_entry],
      )

      untyped_result = AmberLSP::Lookup::VerifyAPIQuery.new(project, untyped_resolution.query, untyped_resolution).perform
      block_result = AmberLSP::Lookup::VerifyAPIQuery.new(project, block_resolution.query, block_resolution).perform

      untyped_result.output.should contain("type check skipped: parameters without declared types are unsupported")
      block_result.output.should contain("type check skipped: block parameters are unsupported")
    end
  end

  it "returns unavailable when the query cannot be represented safely" do
    with_probe_project do |project|
      result = verify_query(project, "ProbeAPI::Child#safe_name; puts 1")

      result.status.should eq("unavailable")
    end
  end
end

private def verify_query(project : String, query : String) : AmberLSP::Lookup::APIProbeResult
  resolution = AmberLSP::Lookup::APIResolution.new(query, "unknown")
  AmberLSP::Lookup::VerifyAPIQuery.new(project, query, resolution).perform
end

private def probe_method(
  owner : String,
  name : String,
  method_kind : String = "instance",
  args_string : String = "",
  declared_return_type : String = "",
) : AmberLSP::Lookup::APIIndexMethod
  AmberLSP::Lookup::APIIndexMethod.new(
    owner,
    name,
    method_kind,
    args_string,
    declared_return_type,
    nil,
    "src/probe_api.cr",
    1,
    "fixture",
    false,
    false,
  )
end

private def with_probe_project(&)
  with_tempdir do |project|
    Dir.mkdir_p(File.join(project, "src"))
    File.write(File.join(project, "shard.yml"), <<-YAML)
      name: amber_lsp_probe_fixture
      version: 0.1.0
      targets:
        amber_lsp_probe_fixture:
          main: src/amber_lsp_probe_fixture.cr
    YAML
    File.write(File.join(project, "src", "amber_lsp_probe_fixture.cr"), <<-CRYSTAL)
      module ProbeAPI
        module ClassExtensions
          def extended_class_api
          end
        end

        module InstanceExtensions
          def where
          end
        end

        class Parent
          def inherited_api
          end

          def self.inherited_class_api
          end
        end

        class Child < Parent
          extend ClassExtensions

          def self.select : String
            "selected"
          end

          def self.choices(*fields : String) : Array(String)
            fields.to_a
          end

          def self.untyped_parameter(value)
            value.to_s
          end

          def self.transform(&block : String -> Bool) : String
            block.call("value") ? "yes" : "no"
          end

          def convert(value : String) : String
            value
          end
        end

        class FirstCandidate
        end

        class SecondCandidate
          include InstanceExtensions
        end
      end
    CRYSTAL
    yield project
  end
end
