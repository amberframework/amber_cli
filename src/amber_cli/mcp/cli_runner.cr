# :nodoc:
require "process"

module AmberCLI::MCP
  # Runs the `amber` CLI as a child process on behalf of the mutating tools.
  #
  # The scaffolding commands cannot be called in-process. `NewCommand` and
  # `GenerateCommand` report every validation failure with `exit(1)` — fine for a
  # one-shot CLI, fatal for a long-running server, where a single bad tool call
  # would terminate the process and drop every other client. Re-invoking the same
  # binary as a child also gives each call its own working directory, so
  # concurrent requests scaffolding different applications cannot interfere.
  class CliRunner
    # `amber new` shells out to `shards install` unless told otherwise, so the
    # ceiling has to accommodate a cold dependency fetch.
    DEFAULT_TIMEOUT = 10.minutes

    # Reported when the child is killed for exceeding its deadline.
    TIMEOUT_EXIT_CODE = -1

    # The outcome of one child invocation.
    struct Outcome
      getter exit_code : Int32
      getter stdout : String
      getter stderr : String
      getter? timed_out : Bool

      def initialize(@exit_code : Int32, @stdout : String, @stderr : String, @timed_out : Bool = false)
      end

      def success? : Bool
        @exit_code == 0
      end

      # stdout and stderr joined for display, blank sections dropped.
      def combined_output : String
        [@stdout, @stderr].reject(&.blank?).join("\n").strip
      end
    end

    getter executable : String

    # *executable* defaults to the running binary so the server always drives the
    # same CLI build it was launched from. Specs inject a stub instead.
    def initialize(executable : String? = nil, @timeout : Time::Span = DEFAULT_TIMEOUT)
      @executable = executable || Process.executable_path || "amber"
    end

    # Runs `amber <args>` with *chdir* as the working directory.
    def run(args : Array(String), chdir : String) : Outcome
      process = Process.new(
        @executable,
        args,
        chdir: chdir,
        input: Process::Redirect::Close,
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Pipe,
      )

      # stdout and stderr are drained in their own fibers: a child that fills a
      # pipe buffer blocks forever if nobody is reading the other end, which no
      # timeout on `wait` alone would catch.
      stdout_channel = Channel(String).new(1)
      stderr_channel = Channel(String).new(1)
      status_channel = Channel(Process::Status).new(1)

      spawn { stdout_channel.send(read_stream(process.output)) }
      spawn { stderr_channel.send(read_stream(process.error)) }
      spawn { status_channel.send(process.wait) }

      select
      when status = status_channel.receive
        Outcome.new(status.exit_code, stdout_channel.receive, stderr_channel.receive)
      when timeout(@timeout)
        kill(process)
        status_channel.receive
        Outcome.new(
          TIMEOUT_EXIT_CODE,
          stdout_channel.receive,
          stderr_channel.receive,
          timed_out: true,
        )
      end
    rescue ex : IO::Error | RuntimeError
      Outcome.new(TIMEOUT_EXIT_CODE, "", "Could not run #{@executable}: #{ex.message}")
    end

    private def read_stream(io : IO) : String
      io.gets_to_end
    rescue IO::Error
      ""
    end

    private def kill(process : Process)
      process.signal(Signal::KILL)
    rescue
      # Already gone; `wait` still reaps it.
    end
  end
end
