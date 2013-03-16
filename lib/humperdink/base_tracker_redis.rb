module Humperdink
  class BaseTrackerRedisConfig < BaseTrackerConfig
    attr_accessor :current_set, :tracker_state, :state_ttl

    def initialize(settings={})
      super(settings)

      base_key = settings[:key]
      config_settings = settings.merge({:max_clean_items => settings[:max_items] || 4000,
                                        :max_dirty_items => settings[:persist_threshold] || 100,
                                        :clean_timeout => settings[:persist_interval_in_seconds] || 300,
                                        :exclude_from_clean => settings[:exclude_keys] || [],
                                        :save_on_clean => true,
                                        :key => base_key})
      @redis_set_config = RedisDirtySetConfig.new(config_settings)

      @state_ttl = settings[:state_ttl] || (60 * 15)
      @tracker_state = RedisStatePersister.new(@redis_set_config.redis, "#{base_key}:trackers", @state_ttl)
    end

    def persist_threshold
      @redis_set_config.max_dirty_items
    end

    def persist_threshold=(value)
      @redis_set_config.max_dirty_items = value
    end

    def persist_interval_in_seconds
      @redis_set_config.clean_timeout
    end

    def persist_interval_in_seconds=(value)
      @redis_set_config.clean_timeout = value
    end

    def max_items
      @redis_set_config.max_clean_items
    end

    def max_items=(value)
      @redis_set_config.max_clean_items = value
    end

    def exclude_keys
      @redis_set_config.exclude_from_clean
    end

    def exclude_keys=(value)
      @redis_set_config.exclude_from_clean = value
    end

    def create_set
      @current_set = Humperdink::RedisDirtySet.new(@redis_set_config)
      @current_set.event_listener = self
      @current_set.load
      @current_set
    end

    def on_event(event, message)
      $callers ||= Set.new
      $callers << caller[0..2] if event == :exit
      raise 'on_event :exit!' if event == :exit
      state = state([event, message].compact.last)
      ttl = event == :exit ? 30 : @state_ttl

      @tracker_state.save_tracker_state(state, ttl)
    end

    def state(event_message)
      state = {
          :state_as_of => Time.now,
          :state_save_trigger => event_message,
          :execution_root => $0,
          :enabled => self.enabled
      }
      state.merge!(@current_set.state_hash) if @current_set
      state
    end
  end

  class RedisStatePersister
    def initialize(redis, base_key, state_ttl)
      @redis = redis
      @tracker_state_base_key = base_key
      @state_ttl = state_ttl
    end

    def get_all_trackers_state
      result = {}
      trackers = @redis.keys("#@tracker_state_base_key:*")
      trackers.each do |tracker|
        hostname, pid = tracker.split(':')[-2], tracker.split(':')[-1]
        result[hostname] ||= {}
        result[hostname][pid] = @redis.hgetall(tracker)
      end
      result
    end

    # Saved per hostname.pid with a TTL of :state_ttl option (default 15 minutes)
    def save_tracker_state(hash, state_ttl=@state_ttl)
      @redis.hmset(this_process_tracker_state_key, *hash.to_a.flatten)
      @redis.expireat(this_process_tracker_state_key, (hash[:state_as_of] + state_ttl).to_i)
    end

    def this_process_tracker_state_key
      "#@tracker_state_base_key:#{`hostname`.chomp}:#{Process.pid}"
    end
  end

end