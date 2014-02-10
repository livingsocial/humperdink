Humperdink
==========

<i>"He can track a falcon on a cloudy day." -- Princess Buttercup</i>

## About

Humperdink is a tool to track finite data sets in high performance
environments. Want to know what translation keys or Rails views are
actually in use at runtime? Humperdink's your man.

Humperdink includes two core classes: `DirtySet` and `Tracker`. The
design of `DirtySet` is to track what items in the finite set being
tracked have been persisted and which ones have not. At a configurable
size and/or duration, the `DirtySet` will persist any dirty items. The
goal is to use memory to store everything and infrequently persist, to
cause as little disruption as possible to the performance of your
application.

To a similar end, the `Tracker` class provides some infrastructure to
allow plugging in different persistence instances and some error
handling to ensure that if something goes wrong, the tracking will
quickly shut itself down and get out of the way.

At this early stage of development, Humperdink is designed to be a
generic tracking mechanism that will still need some integration work
depending on what data you want to track, and only provides Redis
persistence.

It also supports configuration options that will allow for easy tracking
within long running processes (e.g. Unicorn), short running processes
(e.g. cron jobs or Rake tasks) or more unique forking setups (e.g.
Resque).

## Example - i18n Keys

Included in the source is an example of one way to integrate a Tracker
into the I18n gem and track all keys being passed into the translate
method.

[examples/i18n/key_tracker.rb](https://github.com/livingsocial/humperdink/blob/master/examples/i18n/key_tracker.rb)

```ruby
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
```

## Configuration Options

Humperdink provides many different options to allow flexible control
over the timing and frequency of potentially expensive persistence
calls.

The `DirtySet` can be configured with these options:

- `:clean_timeout` - number of seconds to wait between write calls.
- `:max_dirty_items` - threshold on count of items needing to be persisted.
- `:exclude_from_clean` - a regular expression to filter out items to be persisted.
- `:max_clean_items` - caps the amount of already persisted data, to restrict memory usage in exchange for potential redundant persistence. 

The `RedisDirtySet` adds an additional option:

- `:clean_at_exit` to persist when the process exits.

### Different Configuration Contexts

For a long running process, it should be sufficient to configure either
`max_dirty_items` or `clean_timeout` if not both. 

For short running processes, only the `clean_at_exit` option may be of
any value.

For Resque, which runs events in a child process and bypasses any
`at_exit` blocks, we came up with a `ForkSavvyRedis` wrapper and
`ForkPiping` mixin which will ensure tracked items from child processes
are piped up to the parent process and persisted through it.

## Future Plans

The design of Humperdink is expected to evolve as its original design
within LivingSocial was terribly coupled to I18n concepts. The 0.0.x
versions here are a first shot at re-use, but there still is some
confusion and inconsistency within the classes in regards to
configuration and event listeners. In addition, it would be nice to add
support for other persistence layers and ready-to-go options for
tracking specific data sets, like i18n keys, Rails views or whatever
others uses can be found.

If anyone in the community finds this tooling useful, we welcome your
input.


## FAQ

- _You misspelt "Humperdinck"_

  Yeah, well, you know, that's just, like, your opinion, man.