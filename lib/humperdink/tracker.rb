module Humperdink
  class Tracker
    include HasEventListener

    # This is included for backwards compatibility.
    # :on_event should be considered deprecated
    # and will be removed in the future
    alias_method :on_event, :notify_event

    attr_reader :set, :config

    def initialize(set=Set.new, config={})
      if set.is_a? Hash
        @set = Set.new
        @config = set
      else
        @set = set
        @config = default_config.merge(config)
      end
      at_exit { notify_event(:exit) unless @config && !@config[:trigger_at_exit] }
    end

    def track(data)
      @set << data
    end

    def default_config
      {:enabled => true, :trigger_at_exit => true}
    end

    def reset_tracker
      @set.clear
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
        notify_event(:disabled)
      elsif !was_enabled && @enabled
        notify_event(:enabled)
      end

      @enabled
    end

    def state_hash
      {
        :enabled => @config[:enabled],
        :trigger_at_exit => @config[:trigger_at_exit]
      }
    end

    # Anytime an exception happens, we want to skedaddle out of the way
    # and let life roll on without any tracking in the loop.
    def shutdown(exception)
      begin
        notify_event(:shutdown, "#{exception.message}")
      rescue => e
        $stderr.puts([e.message, e.backtrace].join("\n")) rescue nil
      end
      @config = default_config
      @config[:enabled] = false
    end
  end
end