require "./spec_helper"

describe AmberLSP::DocumentStore do
  describe "#update and #get" do
    it "stores and retrieves a document by URI" do
      store = AmberLSP::DocumentStore.new
      store.update("file:///app/src/hello.cr", "puts \"hello\"")

      store.get("file:///app/src/hello.cr").should eq("puts \"hello\"")
    end

    it "overwrites existing content on update" do
      store = AmberLSP::DocumentStore.new
      store.update("file:///app/src/hello.cr", "original")
      store.update("file:///app/src/hello.cr", "updated")

      store.get("file:///app/src/hello.cr").should eq("updated")
    end

    it "returns nil for unknown URIs" do
      store = AmberLSP::DocumentStore.new

      store.get("file:///nonexistent.cr").should be_nil
    end
  end

  describe "#remove" do
    it "removes a stored document" do
      store = AmberLSP::DocumentStore.new
      store.update("file:///app/src/hello.cr", "content")
      store.remove("file:///app/src/hello.cr")

      store.get("file:///app/src/hello.cr").should be_nil
    end

    it "does not raise when removing a nonexistent URI" do
      store = AmberLSP::DocumentStore.new
      store.remove("file:///nonexistent.cr")
    end
  end

  describe "#has?" do
    it "returns true for stored documents" do
      store = AmberLSP::DocumentStore.new
      store.update("file:///app/src/hello.cr", "content")

      store.has?("file:///app/src/hello.cr").should be_true
    end

    it "returns false for missing documents" do
      store = AmberLSP::DocumentStore.new

      store.has?("file:///nonexistent.cr").should be_false
    end

    it "returns false after removal" do
      store = AmberLSP::DocumentStore.new
      store.update("file:///app/src/hello.cr", "content")
      store.remove("file:///app/src/hello.cr")

      store.has?("file:///app/src/hello.cr").should be_false
    end
  end
end
