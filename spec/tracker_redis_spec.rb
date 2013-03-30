require File.dirname(__FILE__) + '/spec_helper'

include Humperdink

describe 'Tracker with RedisDirtySet' do
  it 'should initialize' do
    TrackerRedisConfig.new
  end
end
