module Humperdink
  module HasEventListener
    def notify_event(event, message=nil)
      event_listener.on_event(event, state_hash, message) if event_listener
    end

    def event_listener
      config[:event_listener]
    end

    def state_hash
      {}
    end
  end
end