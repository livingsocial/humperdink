Bundler.require

require 'rspec'
require 'i18n'
require 'timecop'

class TestListener
  attr_accessor :event, :message

  def on_event(event, message)
    @event = event
    @message = message
  end
end
