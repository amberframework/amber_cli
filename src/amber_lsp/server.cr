module AmberLSP
  class Server
    getter controller : Controller

    def initialize(@input : IO, @output : IO)
      @running = false
      @controller = Controller.new
    end

    def run : Nil
      @running = true

      while @running
        raw_message = read_message
        break if raw_message.nil?

        response = @controller.handle(raw_message, self)
        write_message(response) if response
      end
    end

    def stop : Nil
      @running = false
    end

    def write_notification(json : String) : Nil
      write_message(json)
    end

    private def read_message : String?
      content_length = -1

      loop do
        line = @input.gets
        return nil if line.nil?

        line = line.chomp
        break if line.empty?

        if line.starts_with?("Content-Length:")
          content_length = line.split(":")[1].strip.to_i
        end
      end

      return nil if content_length < 0

      body = Bytes.new(content_length)
      bytes_read = @input.read_fully(body)
      return nil if bytes_read == 0

      String.new(body)
    rescue IO::EOFError
      nil
    end

    private def write_message(json : String) : Nil
      header = "Content-Length: #{json.bytesize}\r\n\r\n"
      @output.print(header)
      @output.print(json)
      @output.flush
    end
  end
end
