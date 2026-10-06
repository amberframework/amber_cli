process = Process.new("true")
Process.signal(Signal::KILL, process.pid)
