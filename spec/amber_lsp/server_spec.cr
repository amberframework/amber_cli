require "./spec_helper"

describe AmberLSP::Server do
  describe "#run" do
    it "reads a JSON-RPC message and writes a response" do
      request = {"jsonrpc" => "2.0", "id" => 1, "method" => "shutdown"}
      input_data = format_lsp_message(request)
      input = IO::Memory.new(input_data)
      output = IO::Memory.new

      server = AmberLSP::Server.new(input, output)
      server.run

      output.rewind
      header = output.gets
      header.should_not be_nil
      header.not_nil!.should start_with("Content-Length:")

      # Read blank line
      output.gets

      length = header.not_nil!.split(":")[1].strip.to_i
      body = Bytes.new(length)
      output.read_fully(body)
      json = JSON.parse(String.new(body))

      json["jsonrpc"].as_s.should eq("2.0")
      json["id"].as_i.should eq(1)
      json["result"].raw.should be_nil
    end

    it "stops on exit message" do
      messages = [
        {"jsonrpc" => "2.0", "id" => 1, "method" => "shutdown"},
        {"jsonrpc" => "2.0", "method" => "exit"},
      ]

      input_data = messages.map { |m| format_lsp_message(m) }.join
      input = IO::Memory.new(input_data)
      output = IO::Memory.new

      server = AmberLSP::Server.new(input, output)
      server.run

      # Server should have stopped cleanly
      output.rewind
      output.size.should be > 0
    end

    it "handles empty input gracefully" do
      input = IO::Memory.new("")
      output = IO::Memory.new

      server = AmberLSP::Server.new(input, output)
      server.run

      output.rewind
      output.size.should eq(0)
    end
  end

  describe "#write_notification" do
    it "writes a pre-serialized JSON notification with Content-Length header" do
      input = IO::Memory.new("")
      output = IO::Memory.new

      server = AmberLSP::Server.new(input, output)
      notification = {"jsonrpc" => "2.0", "method" => "test"}.to_json
      server.write_notification(notification)

      output.rewind
      header = output.gets
      header.should_not be_nil
      header.not_nil!.should start_with("Content-Length: #{notification.bytesize}")
    end
  end
end
