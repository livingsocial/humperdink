module Humperdink
  class RedisStatePersister
    def initialize(redis, base_key, state_ttl=(60 * 15))
      @redis = redis
      @tracker_state_base_key = base_key
      @state_ttl = state_ttl
    end

    def get_all_trackers_state
      result = {}
      trackers = @redis.keys("#{@tracker_state_base_key}:*")
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
      "#{@tracker_state_base_key}:#{`hostname`.chomp}:#{Process.pid}"
    end

    def on_event(event, state_hash, message)
      state = state([event, message].compact.last)
      state.merge!(state_hash)
      ttl = event == :exit ? 30 : @state_ttl

      save_tracker_state(state, ttl)
    end

    def state(event_message)
      {
          :state_as_of => Time.now,
          :state_save_trigger => event_message,
          :execution_root => $0,
      }
    end
  end
end