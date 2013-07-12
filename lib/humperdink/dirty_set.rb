module Humperdink
  # as a stand-alone class, this is a bit wonky in ways that are specific to its context here,
  # so ... if you think you want to extract this out for re-use, consider said wonkiness.
  class DirtySet
    attr_reader :dirty, :clean, :config

    def initialize(initial_contents=[], config={})
      if initial_contents.is_a? Hash
        config = initial_contents
        initial_contents = []
      end

      @clean = Set.new(initial_contents)
      @dirty = Set.new
      @config = config
      set_time_to_clean
    end

    def set_time_to_clean
      @time_to_clean = @config[:clean_timeout] ? Time.now + @config[:clean_timeout] : nil
    end

    def <<(value)
      @dirty << value if !@clean.include?(value)
      clean! if getting_messy?
    end

    def getting_messy?
      return true if @config[:max_dirty_items] && @dirty.length > @config[:max_dirty_items]
      return true if @config[:clean_timeout] && Time.now > @time_to_clean
    end

    def clean!
      set_time_to_clean
      if exclusions = @config[:exclude_from_clean]
        @dirty.delete_if { |item| exclusions.detect { |regex| item =~ regex } }
      end
      @clean.merge(@dirty)
      if max = @config[:max_clean_items]
        @clean.subtract(@clean.to_a[max..-1]) if @clean.length > max
      end
      cleaned = @dirty.to_a.dup # to_a just a pointer to the Set's internal Hash's keys
      @dirty.clear
      cleaned
    end

    def length
      @clean.length # wonky -> doesn't include @dirty
    end

    def clear
      @clean.clear
      @dirty.clear
    end
  end
end