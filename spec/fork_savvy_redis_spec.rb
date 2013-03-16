require File.dirname(__FILE__) + '/spec_helper'

describe Humperdink::ForkSavvyRedis do
  it 'should reconnect on fork' do
    redis = Redis.connect(:url => 'redis://127.0.0.1/8')
    fork_savvy_redis = Humperdink::ForkSavvyRedis.new(redis)
    Process.stub(:pid).and_return(11)
    redis.client.should_receive(:reconnect)
    fork_savvy_redis.keys
  end

  it 'should support block format to group redis calls in a single reconnect check' do
    redis = Redis.connect(:url => 'redis://127.0.0.1/8')
    fork_savvy_redis = Humperdink::ForkSavvyRedis.new(redis)
    Process.stub(:pid).and_return(11)
    fork_savvy_redis.should_receive(:method_missing).never
    @keys = []
    fork_savvy_redis.reconnect_on_fork do |check_free_redis|
      30.times {
        @keys << check_free_redis.keys
      }
    end
    @keys.should_not be_empty
  end

end