module Humperdink
  module HasEventListener
    def notify_event(event, data = {})
      data[:state] ||= state_hash
      event_listener.on_event(event, data) if event_listener
    end

    def event_listener
      config[:event_listener]
    end

    def state_hash
      {}
    end
  end
end