require File.dirname(__FILE__) + '/spec_helper'

include Humperdink

describe 'Tracker with RedisDirtySet' do
  it 'should initialize with default config' do
    config = TrackerRedisConfig.new
    config.persist_threshold.should == 100
    config.persist_interval_in_seconds.should == 300
    config.max_items.should == 4000
    config.exclude_keys.should == []
  end

  it 'should initialize have config setters' do
    config = TrackerRedisConfig.new
    config.persist_threshold = 200
    config.persist_threshold.should == 200
    config.persist_interval_in_seconds = 400
    config.persist_interval_in_seconds.should == 400
    config.max_items = 3
    config.max_items.should == 3
    config.exclude_keys = [:foo]
    config.exclude_keys.should == [:foo]
  end

  it 'should create a set' do # but probably not
    config = TrackerRedisConfig.new
    set = config.create_set
    set.should be_a RedisDirtySet
    set.event_listener.should == config
  end

  it 'should handle events' do
    config = TrackerRedisConfig.new

    def config.state(event_message)
      @event_message = event_message
    end

    def config.event_message
      @event_message
    end

    config.on_event(:foo, 'bar')
    config.event_message.should == :foo
  end
end
