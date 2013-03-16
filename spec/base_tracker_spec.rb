require File.dirname(__FILE__) + '/spec_helper'
require 'tempfile'

include Humperdink

describe BaseTracker do
  class TempfileEventConfig < BaseTrackerConfig
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
      BaseTracker.new(config)
    end
    Process.wait
    config.tempfile.tap { |f| f.close; f.open; f.read.should == "exit\n"; f.close! }
  end

  it 'should not notify at_exit if configuration says no-no' do
    config = TempfileEventConfig.new
    config.trigger_at_exit = false
    fork do
      BaseTracker.new(config)
    end
    Process.wait
    config.tempfile.tap { |f| f.close; f.open; f.read.should == ''; f.close! }
  end
end