Bundler.require

require 'rspec'
require 'timecop'

class TestListener
  attr_accessor :event, :state_hash, :message

  def on_event(event, state_hash, message)
    @event = event
    @state_hash = state_hash
    @message = message
  end
end
