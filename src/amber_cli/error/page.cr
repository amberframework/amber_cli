module Error
  class Page
    struct Frame
      property app : String,
        args : String,
        context : String,
        index : Int32,
        file : String,
        line : Int32,
        info : String,
        snippet = [] of Tuple(Int32, String, Bool)

      def initialize(@app, @context, @index, @file, @args, @line, @info, @snippet)
      end
    end

    @params : Hash(String, String)
    @headers : Hash(String, Array(String))
    @session : Hash(String, HTTP::Cookie)
    @method : String
    @path : String
    @message : String
    @query : String
    @reload_code = ""
    @frames = [] of Frame

    def initialize(context : HTTP::Server::Context, @message : String)
      @params = context.request.query_params.to_h
      @headers = context.response.headers.to_h
      @method = context.request.method
      @path = context.request.path
      @url = "#{context.request.host_with_port}#{context.request.path}"
      @query = context.request.query_params.to_s
      @session = context.response.cookies.to_h
    end

    def generate_frames_from(message : String)
      generated_frames = [] of Frame
      if frames = message.scan(/\s([^\s\:]+):(\d+)([^\n]+)/)
        frames.each_with_index do |frame, index|
          snippets = [] of Tuple(Int32, String, Bool)
          file = frame[1]
          filename = file.split('/').last
          linenumber = frame[2].to_i
          linemsg = "#{file}:#{linenumber}#{frame[3]}"
          if File.exists?(file)
            lines = File.read_lines(file)
            lines.each_with_index do |code, codeindex|
              if (codeindex + 1) <= (linenumber + 5) && (codeindex + 1) >= (linenumber - 5)
                highlight = (codeindex + 1 == linenumber) ? true : false
                snippets << {codeindex + 1, code, highlight}
              end
            end
          end
          context = "all"
          app = case file
                when .includes?("/crystal/")
                  "crystal"
                when .includes?("/amber/")
                  "amber"
                when .includes?("lib/")
                  "shards"
                else
                  context = "app"
                  AmberCLI.settings.name.as(String)
                end
          generated_frames << Frame.new(app, context, index, file, linemsg, linenumber, filename, snippets)
        end
      end
      if self.class.name == "ExceptionPageServer"
        generated_frames.reverse
      else
        generated_frames
      end
    end

    ECR.def_to_s "#{__DIR__}/exception_page.ecr"
  end
end