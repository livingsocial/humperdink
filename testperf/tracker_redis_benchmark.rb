Bundler.require
require 'benchmark'
require 'pp'

def setup
  @redis = Redis.connect(:url => 'redis://127.0.0.1:6379/8')
  @data = [].tap { |a| 4000.times { a << rand(100_000_000**2).to_s * 5 } }
  puts "@data.length = #{@data.length}"
  @redis.flushdb
  GC.start
end

def reset_backend
  @redis.flushdb

  base_key = 'runtime_metrics:tracker:benchmarks'
  @state_persister = Humperdink::RedisStatePersister.new(@redis, "#{base_key}:trackers")
  @redis_dirty_set = Humperdink::RedisDirtySet.new(
    :key => base_key,
    :redis => @redis,
    :event_listener => @state_persister
  )
  @tracker = Humperdink::Tracker.new(@redis_dirty_set, :event_listener => @state_persister)

  def @tracker.shutdown(e)
    raise e
  end
end

def persist_threshold_zero_100_keys_only
  @redis_dirty_set.config[:max_dirty_items] = 0
  @data[0..99].each do |key|
    @tracker.track(key)
  end
end

def persist_threshold_100
  @redis_dirty_set.config[:max_dirty_items] = 100
  @data.each do |key|
    @tracker.track(key)
  end
end

def persist_threshold_1000
  @redis_dirty_set.config[:max_dirty_items] = 1000
  @data.each do |key|
    @tracker.track(key)
  end
end

def persist_threshold_100_with_regexes
  @redis_dirty_set.config[:exclude_from_clean] = [/#{rand(1_000_000**2)}/]
  @redis_dirty_set.config[:max_dirty_items] = 100
  @data.each do |key|
    @tracker.track(key)
  end
end

def persist_threshold_100_with_heavy_regexes
  ex = [].tap { |a| 100.times { a << /#{rand(1_000_000**2)}/ }}
  @redis_dirty_set.config[:exclude_from_clean] = ex
  @redis_dirty_set.config[:max_dirty_items] = 100
  @data.each do |key|
    @tracker.track(key)
  end
end

def get_trackers_state_and_reset
  state = @state_persister.get_all_trackers_state.dup
  unless state.empty?
    inner_state = state.first.last.first.last
    raise "nil keys count #{inner_state.inspect}" if inner_state['requested_keys_clean_count'].nil? || inner_state['requested_keys_dirty_count'].nil?
    raise "state_save_trigger not Saved: <#{inner_state.inspect}>" if inner_state['state_save_trigger'] !~ /Saved/
    state
  else
    puts 'WARNING: state empty'
  end
end

def warmup
  puts 'warming up...'
  reset_backend
  3.times { persist_threshold_100_with_heavy_regexes }
end

setup
warmup
Benchmark.bm(40) do |x|
  post_states = {}
  methods = [:persist_threshold_1000, :persist_threshold_100,
             :persist_threshold_100_with_regexes, :persist_threshold_100_with_heavy_regexes,
             :persist_threshold_zero_100_keys_only]
  methods.each do |method|
    reset_backend
    x.report(method.to_s) { send(method) }
    post_states[method.to_s] = get_trackers_state_and_reset
  end

  # TODO: measure these automagically to detect when things start running much longer
  #
  #                                               user     system      total        real
  # persist_threshold_1000                    0.010000   0.020000   0.040000 (  0.052572)
  # persist_threshold_100                     0.030000   0.180000   0.380000 (  0.457349)
  # persist_threshold_100_with_regexes        0.050000   0.200000   0.430000 (  0.477503)
  # persist_threshold_100_with_heavy_regexes  0.170000   0.220000   0.570000 (  0.627657)
  # persist_threshold_zero_100_keys_only      0.050000   0.520000   1.000000 (  1.134126)
end
