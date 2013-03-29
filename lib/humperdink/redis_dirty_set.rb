require 'redis'

module Humperdink
  class RedisDirtySet < DirtySet
    attr_accessor :event_listener

    def initialize(initial_content=[], config=RedisDirtySetConfig.new)
      unless initial_content.is_a?(Array)
        initial_content, config = [[], initial_content]
      end
      if config.is_a?(Hash)
        config = RedisDirtySetConfig.new(config)
      end
      super(initial_content, config)
      at_exit { clean! if @config.clean_at_exit }
    end

    def redis
      @config.redis
    end

    def clean!
      to_save = super
      save(to_save) if @config.save_on_clean
    end

    def load
      @clean.merge(redis.smembers(@config.key))
    end

    def save(to_save=@clean)
      # Redis 2.3.9+ supports sadd with multiple arguments, but the 2.x redis gem
      # doesn't support it at the topmost interface, we need to dive beneath the
      # covers a layer to pull it off ourselves. This works with both hiredis
      # connection and the default connection. NOTE: this version check on the
      # next line is checking the _gem_ version, not the version of Redis we're
      # connected to.
      redis.reconnect_on_fork do |unwrapped_redis|
        unless to_save.empty?
          if Redis::VERSION.split('.')[0].to_i < 3
            unwrapped_redis.synchronize do
              unwrapped_redis.client.call([:sadd, @config.key, *to_save.to_a])
            end
          else
            unwrapped_redis.sadd(@config.key, to_save.to_a)
          end
        end
        message = "Saved #{to_save.length} keys to RedisPersister: #{unwrapped_redis.client.id}"
        notify_event(:save, message)
      end
    end

    def notify_event(event, message=nil)
      @event_listener.on_event(event, message) if @event_listener
    end

    def state_hash
      {
          :max_items => @config.max_clean_items,
          :persist_threshold => @config.max_dirty_items,
          :persist_interval_in_seconds => @config.clean_timeout,

          :requested_keys_clean_count => @clean.length,
          :requested_keys_dirty_count => @dirty.length,
          :time_to_persist => @time_to_clean,
      }
    end
  end

  class DirtySetConfig
    attr_accessor :clean_timeout,
                  :max_clean_items,
                  :max_dirty_items,
                  :exclude_from_clean

    def initialize(settings={})
      @clean_timeout = settings[:clean_timeout]
      @max_clean_items = settings[:max_clean_items]
      @max_dirty_items = settings[:max_dirty_items]
      @exclude_from_clean = settings[:exclude_from_clean]
    end

    def to_hash
      {:clean_timeout => @clean_timeout,
       :max_clean_items => @max_clean_items,
       :max_dirty_items => @max_dirty_items,
       :exclude_from_clean => @exclude_from_clean}
    end
  end

  class RedisDirtySetConfig < DirtySetConfig
    attr_accessor :key, :redis, :save_on_clean, :clean_at_exit

    def initialize(settings={})
      super(settings)
      @key = settings[:key]
      redis = settings[:redis]
      redis = redis.is_a?(Redis) ? redis : Redis.connect(:url => redis)
      @redis = ForkSavvyRedis.new(redis)
      @save_on_clean = settings[:save_on_clean]
      @clean_at_exit = settings[:clean_at_exit]
    end

    def to_hash
      super.merge(:key => @key, :redis => @redis.client.id, :save_on_clean => @save_on_clean)
    end
  end
end