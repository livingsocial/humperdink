require File.dirname(__FILE__) + '/spec_helper'
require 'tempfile'
require 'ostruct'

include Humperdink

describe Tracker do
  class TempfileEventListener
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
    listener = TempfileEventListener.new
    fork do
      Tracker.new(:event_listener => listener)
    end
    Process.wait
    listener.tempfile.tap { |f| f.close; f.open; f.read.should == "exit\n"; f.close! }
  end

  it 'should not notify at_exit if configuration says no-no' do
    listener = TempfileEventListener.new
    fork do
      Tracker.new(:event_listener => listener, :trigger_at_exit => false)
    end
    Process.wait
    listener.tempfile.tap { |f| f.close; f.open; f.read.should == ''; f.close! }
  end

  it 'should instantiate with default config' do
    tracker = Tracker.new
    tracker.config[:enabled].should be_true
    tracker.config[:trigger_at_exit].should be_true
    tracker.config[:event_listener].should be_nil
  end

  it 'should be enabled by default' do
    Tracker.new.tracker_enabled.should be_true
  end

  it 'should reset config and enabled' do
    tracker = Tracker.new
    tracker.config[:enabled] = false
    tracker.reset_tracker_config
    tracker.config[:enabled] = true
  end

  it 'should reset_tracker when disabled' do
    tracker = Tracker.new
    def tracker.reset_tracker
      @reset_called = true
    end

    def tracker.reset_called
      @reset_called
    end

    tracker.config[:enabled] = false
    tracker.tracker_enabled
    tracker.reset_called.should be_true
  end

  it 'should shutdown and reset config and disable itself' do
    listener = TestListener.new

    tracker = Tracker.new
    tracker.config[:event_listener] = listener

    tracker.shutdown(Exception.new 'foobar')
    listener.event.should == :shutdown
    listener.message.should == 'foobar'

    tracker.tracker_enabled.should be_false
  end
end