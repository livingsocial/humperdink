require 'redis'

module Humperdink
  class ForkSavvyRedis
    def initialize(redis)
      @redis = redis
      @pid = Process.pid
    end

    def method_missing(meth_id, *args, &block)
      reconnect_on_fork
      @redis.send(meth_id, *args, &block)
    end

    def reconnect_on_fork
      if Process.pid != @pid
        @redis.client.reconnect
        @pid = Process.pid
      end
      yield @redis if block_given?
    end
  end
end