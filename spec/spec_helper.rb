Bundler.require

require 'rspec'
require 'timecop'

class TestListener
  attr_accessor :event, :data

  def on_event(event, data)
    @event = event
    @data = data
  end
end
