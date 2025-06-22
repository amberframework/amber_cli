# :nodoc:
module AmberCLI::Exceptions
  class TemplateError < Exception
    def initialize(message : String)
      super(message)
    end
  end
end
