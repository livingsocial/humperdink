module Humperdink
  class BaseTracker
    def initialize(tracker_config=nil)
      @config = tracker_config
      at_exit { on_event(:exit) unless @config && !@config.trigger_at_exit }
    end

    def default_tracker_config_class
      BaseTrackerConfig
    end

    def config
      @config ||= default_tracker_config_class.new
    end

    def config=(value)
      @config = value
    end

    def reset_tracker
    end

    def reset_tracker_config
      @config = nil
      @enabled = nil
    end

    def tracker_enabled
      was_enabled = @enabled
      @enabled = config.enabled

      if (was_enabled || was_enabled.nil?) && !@enabled
        reset_tracker
        on_event(:disabled)
      elsif !was_enabled && @enabled
        on_event(:enabled)
      end

      @enabled
    end

    def on_event(event, message=nil)
      config.on_event(event, message)
    end

    # Anytime an exception happens, we want to skedaddle out of the way
    # and let life roll on without any tracking in the loop.
    def shutdown(exception)
      begin
        on_event(:shutdown, "#{exception.message}")
      rescue => e
        $stderr.puts([e.message, e.backtrace].join("\n")) rescue nil
      end
      @config = default_tracker_config_class.new
      @config.enabled = false
    end
  end

  class BaseTrackerConfig
    attr_accessor :enabled, :current_set, :trigger_at_exit

    def initialize(settings={})
      @enabled = settings.keys.include?(:enabled) ? settings[:enabled] : true
      @trigger_at_exit = settings.keys.include?(:trigger_at_exit) ? settings[:trigger_at_exit] : true
    end

    def on_event(event, message)
    end

    def create_set
      @current_set = Set.new
    end
  end
end