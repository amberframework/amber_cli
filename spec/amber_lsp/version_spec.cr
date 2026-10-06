require "./spec_helper"

describe AmberLSP do
  describe "USAGE" do
    it "names every command-line mode" do
      ["lookup QUERY", "hint", "--check FILE.cr", "context", "--version"].each do |mode|
        AmberLSP::USAGE.should contain("amber-lsp #{mode}")
      end
    end
  end

  describe ".version_line" do
    it "names the server version, the amber_cli release, and the build commit" do
      AmberLSP.version_line.should eq(
        "amber-lsp #{AmberLSP::VERSION} (amber_cli #{AmberLSP::RELEASE}, commit #{AmberLSP::BUILD_COMMIT})"
      )
    end

    it "reads the amber_cli release from shard.yml" do
      shard_version = File.read(File.join(__DIR__, "..", "..", "shard.yml"))[/^version:\s*(\S+)/m, 1]
      AmberLSP::RELEASE.should eq(shard_version)
    end

    it "stamps a git commit when built from a checkout" do
      AmberLSP::BUILD_COMMIT.should match(/\A[0-9a-f]{12}\z/)
    end
  end
end
