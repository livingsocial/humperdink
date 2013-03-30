module Humperdink
  class Tracker
    attr_reader :current_set, :config

    def initialize(config={})
      @config = default_config.merge(config)
      at_exit { on_event(:exit) unless @config && !@config[:trigger_at_exit] }
    end

    def default_config
      {:enabled => true, :trigger_at_exit => true}
    end

    def reset_tracker
    end

    def reset_tracker_config
      @config = default_config
      @enabled = nil
    end

    def tracker_enabled
      was_enabled = @enabled
      @enabled = @config[:enabled]

      if (was_enabled || was_enabled.nil?) && !@enabled
        reset_tracker
        on_event(:disabled)
      elsif !was_enabled && @enabled
        on_event(:enabled)
      end

      @enabled
    end

    def on_event(event, message=nil)
      @config[:event_listener].on_event(event, message) if @config[:event_listener]
    end

    # Anytime an exception happens, we want to skedaddle out of the way
    # and let life roll on without any tracking in the loop.
    def shutdown(exception)
      begin
        on_event(:shutdown, "#{exception.message}")
      rescue => e
        $stderr.puts([e.message, e.backtrace].join("\n")) rescue nil
      end
      @config = default_config
      @config[:enabled] = false
    end
    
    def create_set
      @current_set = Set.new
    end
  end
end