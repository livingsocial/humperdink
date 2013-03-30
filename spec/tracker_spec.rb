require File.dirname(__FILE__) + '/spec_helper'
require 'tempfile'
require 'ostruct'

include Humperdink

describe Tracker do
  class TempfileEventConfig < TrackerConfig
    attr_accessor :tempfile

    def initialize
      super
      @tempfile = Tempfile.new('tempfile.event.txt')
      @tempfile.open
    end

    def on_event(event, message)
      @tempfile.puts(event)
    end
  end

  it 'should notify at_exit' do
    config = TempfileEventConfig.new
    fork do
      Tracker.new(config)
    end
    Process.wait
    config.tempfile.tap { |f| f.close; f.open; f.read.should == "exit\n"; f.close! }
  end

  it 'should not notify at_exit if configuration says no-no' do
    config = TempfileEventConfig.new
    config.trigger_at_exit = false
    fork do
      Tracker.new(config)
    end
    Process.wait
    config.tempfile.tap { |f| f.close; f.open; f.read.should == ''; f.close! }
  end

  it 'should instantiate default config class' do
    Tracker.new.config.should be_a TrackerConfig
  end

  it 'should accept config setter' do
    tracker = Tracker.new
    tracker.config = OpenStruct.new(:trigger_at_exit => false)
    tracker.config.should be_a OpenStruct
  end

  it 'should be enabled by default' do
    Tracker.new.tracker_enabled.should be_true
  end

  it 'should reset config and enabled' do
    tracker = Tracker.new
    tracker.config.enabled = false
    tracker.config = Object.new
    tracker.reset_tracker_config
    tracker.config.should be_a TrackerConfig
    tracker.tracker_enabled.should be_true
  end

  it 'should reset_tracker when disabled' do
    tracker = Tracker.new
    def tracker.reset_tracker
      @reset_called = true
    end

    def tracker.reset_called
      @reset_called
    end

    tracker.config.enabled = false
    tracker.tracker_enabled
    tracker.reset_called.should be_true
  end

  it 'should shutdown and reset config and disable itself' do
    tracker = Tracker.new
    config = tracker.config

    def config.on_event(event, message)
      @last_event = event
      @last_message = message
    end

    def config.last_event
      @last_event
    end

    def config.last_message
      @last_message
    end

    tracker.shutdown(Exception.new 'foobar')
    config.last_event.should == :shutdown
    config.last_message.should == 'foobar'

    tracker.tracker_enabled.should be_false
  end
end