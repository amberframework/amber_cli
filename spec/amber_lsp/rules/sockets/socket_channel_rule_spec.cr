require "../../spec_helper"
require "../../../../src/amber_lsp/rules/sockets/socket_channel_rule"

describe AmberLSP::Rules::Sockets::SocketChannelRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Sockets::SocketChannelRule.new)
  end

  describe "#check" do
    it "produces no diagnostics when socket has channel macro" do
      content = <<-CRYSTAL
      struct UserSocket < Amber::WebSockets::ClientSocket
        channel "chat:*", ChatChannel
      end
      CRYSTAL

      rule = AmberLSP::Rules::Sockets::SocketChannelRule.new
      diagnostics = rule.check("src/sockets/user_socket.cr", content)
      diagnostics.should be_empty
    end

    it "reports warning when socket has no channel macro" do
      content = <<-CRYSTAL
      struct UserSocket < Amber::WebSockets::ClientSocket
        def on_connect
          true
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Sockets::SocketChannelRule.new
      diagnostics = rule.check("src/sockets/user_socket.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/socket-channel-macro")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Warning)
      diagnostics[0].message.should contain("UserSocket")
      diagnostics[0].message.should contain("channel")
    end

    it "produces no diagnostics with multiple channel macros" do
      content = <<-CRYSTAL
      struct UserSocket < Amber::WebSockets::ClientSocket
        channel "chat:*", ChatChannel
        channel "notifications:*", NotificationChannel
      end
      CRYSTAL

      rule = AmberLSP::Rules::Sockets::SocketChannelRule.new
      diagnostics = rule.check("src/sockets/user_socket.cr", content)
      diagnostics.should be_empty
    end

    it "skips files not in sockets/ directory" do
      content = <<-CRYSTAL
      struct UserSocket < Amber::WebSockets::ClientSocket
        def on_connect
          true
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Sockets::SocketChannelRule.new
      diagnostics = rule.check("src/models/user_socket.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::Sockets::SocketChannelRule.new
      diagnostics = rule.check("src/sockets/user_socket.cr", "")
      diagnostics.should be_empty
    end

    it "produces no diagnostics for files without socket structs" do
      content = <<-CRYSTAL
      class Helper
        def connect
          true
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Sockets::SocketChannelRule.new
      diagnostics = rule.check("src/sockets/helper.cr", content)
      diagnostics.should be_empty
    end

    it "handles channel names with colons and wildcards" do
      content = <<-CRYSTAL
      struct AppSocket < Amber::WebSockets::ClientSocket
        channel "room:lobby:*", LobbyChannel
      end
      CRYSTAL

      rule = AmberLSP::Rules::Sockets::SocketChannelRule.new
      diagnostics = rule.check("src/sockets/app_socket.cr", content)
      diagnostics.should be_empty
    end

    it "correctly positions the diagnostic range on the struct name" do
      content = "struct UserSocket < Amber::WebSockets::ClientSocket\nend"
      rule = AmberLSP::Rules::Sockets::SocketChannelRule.new
      diagnostics = rule.check("src/sockets/user_socket.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].range.start.line.should eq(0)
    end
  end
end
