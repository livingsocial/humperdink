require 'i18n'

class I18nFaker
  def initialize
    I18n.load_path.clear
  end

  def load_em_up(opts={})
    full_hash = make_full_hash(opts)
    I18n.backend.store_translations(:en, full_hash)
  end

  def make_full_hash(opts)
    full_hash = {}
    count = 0
    while count < opts[:total] do
      sub_hash = make_sub_hash([opts[:total] - count, (rand(20) + 1)].min)
      count += sub_hash.keys.length

      leaf_hash = nest_hashes(full_hash, opts[:max_depth] - 1)
      leaf_hash[random_string.to_sym] = sub_hash
    end
    full_hash
  end

  # dumb recursion ...
  def nest_hashes(hash, level)
    new_hash = {}
    hash[random_string.to_sym] = new_hash
    new_level = level - 1
    if level > 0
      nest_hashes(new_hash, new_level)
    else
      new_hash
    end
  end

  def make_sub_hash(key_count)
    result = {}
    key_count.times do
      result[random_string.to_sym] = random_translation
    end
    result
  end

  def random_string
    letters = ('a'..'z').to_a
    result = ''
    length = (((rand**5)*50) + (rand(3) + 3)).to_i # skews towards shorter 'words'
    length.times do
      result << (letters.respond_to?(:choice) ? letters.choice : letters.sample)
    end
    result
  end

  def random_translation
    result = []
    (rand(12) + 5).times do
      result << random_string
    end
    result.join(' ')
  end

  def random_deep_key(max_depth)
    result = []

    result << random_string
  end
end

class KeyDumper
  def initialize(hash=nil)
    @hash = hash
    if @hash.nil?
      I18n.backend.load_translations
      @hash = I18n.backend.send(:translations)
    end
  end

  def dump_all_fully_qualified_key_names
    localeless_keys = Set.new
    @hash.keys.each do |locale|
      squash_hash(@hash[locale], [], localeless_keys)
    end
    localeless_keys
  end

  def squash_hash(h, path_array=[], result=[])
    h.each do |key, value|
      if value.is_a? Hash
        squash_hash(value, path_array + [key], result)
      else
        result << (path_array + [key]).join('.')
      end
    end
  end
end