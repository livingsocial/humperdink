Bundler.require
require File.expand_path('../i18n_util', __FILE__)

class KeyTracker
  def initialize(redis, key)
    redis_set = Humperdink::RedisDirtySet.new(:redis => redis, :key => key, :save_on_clean => true, :max_dirty_items => 9)
    @tracker = Humperdink::Tracker.new(redis_set, :enabled => true)
  end

  def on_translate(locale, key, options = {})
    begin
      if @tracker.tracker_enabled
        requested_key = normalize_requested_key(key, options)
        @tracker.track(requested_key)
      end
    rescue => e
      @tracker.shutdown(e)
    end
  end

  def normalize_requested_key(key, options)
    separator = options[:separator] || I18n.default_separator
    # this is a cheap way to reduce the amount of string manipulation
    # performed inside normalize_keys, based on the presumption that
    # the :scope is infrequently used. If that presumption is not true
    # then there may be some performance concerns with tracking many
    # translate calls in a short period of time.
    if options[:scope]
      requested_key = I18n.normalize_keys(nil, key, options[:scope], separator).join(separator)
    else
      requested_key = key.to_s
    end
    requested_key
  end
end

module KeyTrackerBackend
  def key_tracker
    @key_tracker
  end

  def key_tracker=(value)
    @key_tracker = value
  end

  def translate(locale, key, options = {})
    @key_tracker.on_translate(locale, key, options) if @key_tracker
    super
  end
end

def setup
  I18nFaker.new.load_em_up(:total => 2500, :max_depth => 7)
  @redis = Redis.connect(:url => 'redis://127.0.0.1:6379/8')
  @all_keys = KeyDumper.new.dump_all_fully_qualified_key_names.to_a
  @redis_key = 'humperdink:example:i18n'
  @redis.del(@redis_key)

  tracker = KeyTracker.new(@redis, @redis_key)
  I18n.backend = I18n::Backend::Simple.new
  I18n.backend.class.class_eval { include KeyTrackerBackend }
  I18n.backend.key_tracker = tracker
end

def execute
  @all_keys[0..99].each do |key|
    I18n.translate(key)
  end
end

def verify
  stored = @redis.smembers(@redis_key)
  raise "count mismatch #{stored.length}" unless stored.length == 100
  stored.each do |k|
    raise 'unknown key' unless @all_keys.include?(k)
  end
  puts 'OK'
end

setup
execute
verify