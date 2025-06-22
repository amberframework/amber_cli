# :nodoc:
require "../../support/file_encryptor"
require "../../environment"
require "file_utils"
require "yaml"
require "colorize"

require "base64"

require "random/secure"
require "../helpers/helpers"
require "./fetcher"
require "./settings"

module Amber::Plugins
  class Plugin
    Log = ::Log.for(self)
    getter name : String
    getter directory : String
    getter args : Array(String)

    def self.can_generate?(name : String)
      template = Fetcher.new(name).fetch
      !(template.nil?)
    end

    def initialize(name : String, directory : String, @args : Array(String))
      @name = name

      @directory = File.join(directory)
      unless Dir.exists?(@directory)
        Dir.mkdir_p(@directory)
      end
    end

    def generate(action : String, options = nil)
      case action
      when "install"
        log_message "Adding plugin #{name}"
        # TODO: Implement new plugin installation system
        log_message "Plugin installation not yet implemented in new architecture"
      else
        Log.error { "Invalid plugin command".colorize(:light_red) }
      end
    end

    def log_message(msg)
      Log.info { msg.colorize(:light_cyan) }
    end
  end
end
