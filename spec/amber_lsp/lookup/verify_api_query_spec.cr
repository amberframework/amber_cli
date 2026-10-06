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

private def probe_method(owner : String, name : String) : AmberLSP::Lookup::APIIndexMethod
  AmberLSP::Lookup::APIIndexMethod.new(
    owner,
    name,
    "instance",
    "",
    "",
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
