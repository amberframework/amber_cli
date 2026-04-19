require "../../spec_helper"
require "../../../../src/amber_lsp/rules/channels/handle_message_rule"

describe AmberLSP::Rules::Channels::HandleMessageRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Channels::HandleMessageRule.new)
  end

  describe "#check" do
    it "produces no diagnostics when channel defines handle_message" do
      content = <<-CRYSTAL
      class ChatChannel < Amber::WebSockets::Channel
        def handle_message(msg)
          rebroadcast!(msg)
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Channels::HandleMessageRule.new
      diagnostics = rule.check("src/channels/chat_channel.cr", content)
      diagnostics.should be_empty
    end

    it "reports error when channel is missing handle_message" do
      content = <<-CRYSTAL
      class ChatChannel < Amber::WebSockets::Channel
        def on_connect
          true
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Channels::HandleMessageRule.new
      diagnostics = rule.check("src/channels/chat_channel.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/channel-handle-message")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Error)
      diagnostics[0].message.should contain("ChatChannel")
      diagnostics[0].message.should contain("handle_message")
    end

    it "skips abstract channel classes" do
      content = <<-CRYSTAL
      abstract class BaseChannel < Amber::WebSockets::Channel
      end
      CRYSTAL

      rule = AmberLSP::Rules::Channels::HandleMessageRule.new
      diagnostics = rule.check("src/channels/base_channel.cr", content)
      diagnostics.should be_empty
    end

    it "skips files not in channels/ directory" do
      content = <<-CRYSTAL
      class ChatChannel < Amber::WebSockets::Channel
        def on_connect
          true
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Channels::HandleMessageRule.new
      diagnostics = rule.check("src/models/chat.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::Channels::HandleMessageRule.new
      diagnostics = rule.check("src/channels/chat_channel.cr", "")
      diagnostics.should be_empty
    end

    it "produces no diagnostics for files without channel classes" do
      content = <<-CRYSTAL
      class Helper
        def help
          "not a channel"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Channels::HandleMessageRule.new
      diagnostics = rule.check("src/channels/helper.cr", content)
      diagnostics.should be_empty
    end

    it "handles handle_message with typed parameters" do
      content = <<-CRYSTAL
      class ChatChannel < Amber::WebSockets::Channel
        def handle_message(msg : String)
          rebroadcast!(msg)
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Channels::HandleMessageRule.new
      diagnostics = rule.check("src/channels/chat_channel.cr", content)
      diagnostics.should be_empty
    end
  end
end
