require "./spec_helper"

describe AmberCLI::MCP::Server do
  describe "classic 2025-11-25 flow" do
    it "completes initialize -> initialized -> tools/list -> tools/call" do
      with_mcp_server do |client|
        initialize_response = client.post(
          "/mcp",
          headers: legacy_headers,
          body: {
            jsonrpc: "2.0",
            id:      1,
            method:  "initialize",
            params:  {
              protocolVersion: "2025-11-25",
              capabilities:    {} of String => String,
              clientInfo:      {name: "claude-desktop-spec", version: "1.0.0"},
            },
          }.to_json
        )

        initialize_response.status_code.should eq(200)
        initialize_response.headers["Content-Type"].should eq("application/json")

        body = parse_body(initialize_response)
        body["jsonrpc"].as_s.should eq("2.0")
        body["id"].as_i.should eq(1)
        body["result"]["protocolVersion"].as_s.should eq("2025-11-25")
        body["result"]["serverInfo"]["name"].as_s.should eq("amber-cli")
        body["result"]["serverInfo"]["version"].as_s.should eq(AmberCLI::VERSION)
        body["result"]["capabilities"]["tools"].should_not be_nil
        # `resultType` belongs to 2026-07-28; a legacy result must not carry it.
        body["result"]["resultType"]?.should be_nil

        initialized = client.post(
          "/mcp",
          headers: legacy_headers,
          body: {jsonrpc: "2.0", method: "notifications/initialized"}.to_json
        )
        initialized.status_code.should eq(202)
        initialized.body.should be_empty

        list_response = client.post(
          "/mcp",
          headers: legacy_headers,
          body: {jsonrpc: "2.0", id: 2, method: "tools/list", params: {} of String => String}.to_json
        )
        list_response.status_code.should eq(200)

        tools = parse_body(list_response)["result"]["tools"].as_a
        names = tools.map(&.["name"].as_s)
        names.should contain("amber_version")
        names.should contain("project_info")
        names.should contain("list_routes")
        names.should contain("list_generators")
        names.should contain("search_docs")
        names.should contain("read_doc")
        names.should contain("create_new_app")
        names.should contain("generate_component")

        call_response = client.post(
          "/mcp",
          headers: legacy_headers,
          body: {
            jsonrpc: "2.0",
            id:      3,
            method:  "tools/call",
            params:  {name: "amber_version", arguments: {} of String => String},
          }.to_json
        )
        call_response.status_code.should eq(200)

        result = parse_body(call_response)["result"]
        result["isError"]?.try(&.as_bool?).should be_falsey
        result["content"][0]["type"].as_s.should eq("text")
        result["content"][0]["text"].as_s.should contain(AmberCLI::VERSION)
        result["structuredContent"]["cliVersion"].as_s.should eq(AmberCLI::VERSION)
      end
    end

    it "does not mint a session id" do
      with_mcp_server do |client|
        response = client.post(
          "/mcp",
          headers: legacy_headers,
          body: {
            jsonrpc: "2.0",
            id:      1,
            method:  "initialize",
            params:  {protocolVersion: "2025-11-25", capabilities: {} of String => String},
          }.to_json
        )

        response.headers["Mcp-Session-Id"]?.should be_nil
      end
    end
  end

  describe "stateless 2026-07-28 flow" do
    it "serves tools/call with no prior initialize" do
      with_mcp_server do |client|
        response = client.post(
          "/mcp",
          headers: modern_headers("tools/call", "amber_version"),
          body: {
            jsonrpc: "2.0",
            id:      7,
            method:  "tools/call",
            params:  {
              name:      "amber_version",
              arguments: {} of String => String,
              _meta:     modern_meta,
            },
          }.to_json
        )

        response.status_code.should eq(200)
        body = parse_body(response)
        body["id"].as_i.should eq(7)
        # REQUIRED on every 2026-07-28 result.
        body["result"]["resultType"].as_s.should eq("complete")
        body["result"]["_meta"]["io.modelcontextprotocol/serverInfo"]["name"].as_s.should eq("amber-cli")
        body["result"]["content"][0]["text"].as_s.should contain("Amber CLI")
      end
    end

    it "answers server/discover with every supported version and cache hints" do
      with_mcp_server do |client|
        response = client.post(
          "/mcp",
          headers: modern_headers("server/discover"),
          body: {
            jsonrpc: "2.0",
            id:      1,
            method:  "server/discover",
            params:  {_meta: modern_meta},
          }.to_json
        )

        response.status_code.should eq(200)
        result = parse_body(response)["result"]
        result["supportedVersions"].as_a.map(&.as_s).should eq(["2026-07-28", "2025-11-25", "2025-06-18"])
        result["resultType"].as_s.should eq("complete")
        result["cacheScope"].as_s.should eq("public")
        result["ttlMs"].as_i64.should be > 0
        result["capabilities"]["tools"].should_not be_nil
      end
    end

    it "puts cache hints on tools/list" do
      with_mcp_server do |client|
        response = client.post(
          "/mcp",
          headers: modern_headers("tools/list"),
          body: {jsonrpc: "2.0", id: 2, method: "tools/list", params: {_meta: modern_meta}}.to_json
        )

        result = parse_body(response)["result"]
        result["resultType"].as_s.should eq("complete")
        result["ttlMs"].as_i64.should eq(3_600_000)
        result["cacheScope"].as_s.should eq("public")
      end
    end

    it "rejects a request whose Mcp-Method header disagrees with the body" do
      with_mcp_server do |client|
        headers = modern_headers("tools/list")
        response = client.post(
          "/mcp",
          headers: headers,
          body: {
            jsonrpc: "2.0",
            id:      3,
            method:  "tools/call",
            params:  {name: "amber_version", arguments: {} of String => String, _meta: modern_meta},
          }.to_json
        )

        response.status_code.should eq(400)
        parse_body(response)["error"]["code"].as_i.should eq(-32020)
      end
    end

    it "rejects a request whose Mcp-Name header disagrees with the body" do
      with_mcp_server do |client|
        response = client.post(
          "/mcp",
          headers: modern_headers("tools/call", "project_info"),
          body: {
            jsonrpc: "2.0",
            id:      4,
            method:  "tools/call",
            params:  {name: "amber_version", arguments: {} of String => String, _meta: modern_meta},
          }.to_json
        )

        response.status_code.should eq(400)
        error = parse_body(response)["error"]
        error["code"].as_i.should eq(-32020)
        error["message"].as_s.should contain("Mcp-Name")
      end
    end

    it "rejects a modern request missing the required _meta fields" do
      with_mcp_server do |client|
        response = client.post(
          "/mcp",
          headers: modern_headers("tools/list"),
          body: {jsonrpc: "2.0", id: 5, method: "tools/list", params: {} of String => String}.to_json
        )

        response.status_code.should eq(400)
        parse_body(response)["error"]["code"].as_i.should eq(-32602)
      end
    end

    it "accepts a Base64 sentinel encoded Mcp-Name" do
      with_mcp_server do |client|
        headers = modern_headers("tools/call")
        headers["Mcp-Name"] = "=?base64?#{Base64.strict_encode("amber_version")}?="

        response = client.post(
          "/mcp",
          headers: headers,
          body: {
            jsonrpc: "2.0",
            id:      6,
            method:  "tools/call",
            params:  {name: "amber_version", arguments: {} of String => String, _meta: modern_meta},
          }.to_json
        )

        response.status_code.should eq(200)
      end
    end

    it "returns 404 with -32601 for an unimplemented method" do
      with_mcp_server do |client|
        response = client.post(
          "/mcp",
          headers: modern_headers("resources/list"),
          body: {jsonrpc: "2.0", id: 8, method: "resources/list", params: {_meta: modern_meta}}.to_json
        )

        response.status_code.should eq(404)
        parse_body(response)["error"]["code"].as_i.should eq(-32601)
      end
    end
  end

  describe "version negotiation" do
    it "rejects an unknown protocol version with -32022 and lists what it supports" do
      with_mcp_server do |client|
        headers = legacy_headers
        headers["MCP-Protocol-Version"] = "1900-01-01"

        response = client.post(
          "/mcp",
          headers: headers,
          body: {jsonrpc: "2.0", id: 9, method: "tools/list", params: {} of String => String}.to_json
        )

        response.status_code.should eq(400)
        error = parse_body(response)["error"]
        error["code"].as_i.should eq(-32022)
        error["data"]["requested"].as_s.should eq("1900-01-01")
        error["data"]["supported"].as_a.map(&.as_s).should eq(["2026-07-28", "2025-11-25", "2025-06-18"])
      end
    end

    it "rejects a version that the shard names but no longer negotiates" do
      with_mcp_server do |client|
        headers = legacy_headers
        headers["MCP-Protocol-Version"] = "2025-03-26"

        response = client.post(
          "/mcp",
          headers: headers,
          body: {jsonrpc: "2.0", id: 10, method: "tools/list", params: {} of String => String}.to_json
        )

        response.status_code.should eq(400)
        parse_body(response)["error"]["code"].as_i.should eq(-32022)
      end
    end

    it "rejects a header that disagrees with the body version" do
      with_mcp_server do |client|
        headers = modern_headers("tools/list")
        headers["MCP-Protocol-Version"] = "2025-11-25"

        response = client.post(
          "/mcp",
          headers: headers,
          body: {jsonrpc: "2.0", id: 11, method: "tools/list", params: {_meta: modern_meta}}.to_json
        )

        response.status_code.should eq(400)
        parse_body(response)["error"]["code"].as_i.should eq(-32020)
      end
    end

    it "answers initialize on the newest handshake revision when asked for the stateless one" do
      with_mcp_server do |client|
        response = client.post(
          "/mcp",
          headers: legacy_headers,
          body: {
            jsonrpc: "2.0",
            id:      12,
            method:  "initialize",
            params:  {protocolVersion: "2026-07-28", capabilities: {} of String => String},
          }.to_json
        )

        response.status_code.should eq(200)
        parse_body(response)["result"]["protocolVersion"].as_s.should eq("2025-11-25")
      end
    end
  end

  describe "transport rules" do
    it "refuses GET on the MCP endpoint" do
      with_mcp_server do |client|
        response = client.get("/mcp")
        response.status_code.should eq(405)
        response.headers["Allow"].should eq("POST")
      end
    end

    it "refuses DELETE on the MCP endpoint" do
      with_mcp_server do |client|
        response = client.delete("/mcp")
        response.status_code.should eq(405)
      end
    end

    it "serves the health check" do
      with_mcp_server do |client|
        response = client.get("/healthz")
        response.status_code.should eq(200)
        response.body.should eq("ok")
      end
    end

    it "wraps the response in SSE when the client asks only for an event stream" do
      with_mcp_server do |client|
        headers = modern_headers("tools/list")
        headers["Accept"] = "text/event-stream"

        response = client.post(
          "/mcp",
          headers: headers,
          body: {jsonrpc: "2.0", id: 13, method: "tools/list", params: {_meta: modern_meta}}.to_json
        )

        response.status_code.should eq(200)
        response.headers["Content-Type"].should eq("text/event-stream")
        response.headers["X-Accel-Buffering"].should eq("no")
        response.body.should start_with("event: message\ndata: ")

        payload = JSON.parse(response.body.lines[1].lchop("data: "))
        payload["result"]["tools"].as_a.size.should eq(8)
      end
    end

    it "returns JSON when the client accepts both, as conforming clients do" do
      with_mcp_server do |client|
        response = client.post(
          "/mcp",
          headers: modern_headers("tools/list"),
          body: {jsonrpc: "2.0", id: 14, method: "tools/list", params: {_meta: modern_meta}}.to_json
        )

        response.headers["Content-Type"].should eq("application/json")
      end
    end

    it "ignores a session id from an older client instead of echoing it" do
      with_mcp_server do |client|
        headers = legacy_headers
        headers["Mcp-Session-Id"] = "abc123"

        response = client.post(
          "/mcp",
          headers: headers,
          body: {jsonrpc: "2.0", id: 15, method: "tools/list", params: {} of String => String}.to_json
        )

        response.status_code.should eq(200)
        response.headers["Mcp-Session-Id"]?.should be_nil
      end
    end

    it "rejects a cross-origin browser request" do
      with_mcp_server do |client|
        headers = legacy_headers
        headers["Origin"] = "https://evil.example.com"

        response = client.post(
          "/mcp",
          headers: headers,
          body: {jsonrpc: "2.0", id: 16, method: "tools/list", params: {} of String => String}.to_json
        )

        response.status_code.should eq(403)
      end
    end

    it "accepts a localhost origin" do
      with_mcp_server do |client, port|
        headers = legacy_headers
        headers["Origin"] = "http://localhost:#{port}"

        response = client.post(
          "/mcp",
          headers: headers,
          body: {jsonrpc: "2.0", id: 17, method: "tools/list", params: {} of String => String}.to_json
        )

        response.status_code.should eq(200)
      end
    end

    it "reports a malformed body as a parse error" do
      with_mcp_server do |client|
        response = client.post("/mcp", headers: legacy_headers, body: "{not json")
        response.status_code.should eq(400)
        parse_body(response)["error"]["code"].as_i.should eq(-32700)
      end
    end

    it "correlates an error response with the request id" do
      with_mcp_server do |client|
        response = client.post(
          "/mcp",
          headers: modern_headers("tools/list"),
          body: {jsonrpc: "2.0", id: 99, method: "tools/list", params: {} of String => String}.to_json
        )

        response.status_code.should eq(400)
        parse_body(response)["id"].as_i.should eq(99)
      end
    end
  end
end
