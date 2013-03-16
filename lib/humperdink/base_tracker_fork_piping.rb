module Humperdink
  # For use with Resque or any forking scenario where the child process
  # needs to pipe its requested keys back to the parent, instead of
  # handling it itself. Make sure and include this module _after_
  # KeyTracker.
  module BaseTrackerForkPiping
    def init_fork_piping(ppid=Process.pid, pipe=IO.pipe)
      unless @ppid || !@parent_pipe_method
        @ppid = ppid
        @read, @write = pipe
        Thread.new { pipe_reader }
      end
    end

    def pipe_reader
      remainder = ''
      while true
        outbuf = ''
        if tracker_enabled
          @read.readpartial(32_768, outbuf)
          buffer, _, remainder = remainder.concat(outbuf).rpartition("\n")
          buffer.split("\n").each do |data|
            send @parent_pipe_method, data
          end
          sleep 0.1
        else
          sleep 5.0
        end
      end
    rescue => e
      shutdown(e)
    end

    def not_forked_or_parent_process
      !@ppid || (@ppid && Process.pid == @ppid)
    end

    # TODO: for general use, presuming \n to be a valid delimiter is no bueno
    def write_to_child_pipe(data)
      @write.write("#{data}\n")
    end
  end
end