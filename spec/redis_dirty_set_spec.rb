require File.dirname(__FILE__) + '/spec_helper'

include Humperdink

describe RedisDirtySet do
  let(:key) { 'dirty_set_test' }
  let(:redis) { Redis.connect(:url => 'redis://127.0.0.1/8') }

  before do
    redis.del(key)
  end

  def new_set(options={})
    set = RedisDirtySet.new({:redis => redis, :key => key}.merge(options))
  end

  it 'should DirtySet to provide persistence for basic functions' do
    set = new_set
    set.redis.should_not be_nil
    set << 'foo'
    set.clean!
    set << 'bar'
    set.save

    set_too = new_set
    set_too.load
    set_too.clean.should == ['foo'].to_set

    set.clean!
    set.save

    set_too.load
    set_too.clean.should == ['foo', 'bar'].to_set

    set_tri = new_set
    set_tri << 'quux'
    set_tri.clean!
    set_tri.load
    set_tri.clean.should == ['foo', 'bar', 'quux'].to_set
  end

  it 'should support save_on_clean option' do
    set = new_set(:save_on_clean => true)
    set << 'foo'
    set.clean!

    set_too = new_set
    set_too.load
    set_too.clean.should == ['foo'].to_set
  end

  it 'should only save cleaned items with save_on_clean option' do
    set = new_set(:save_on_clean => true)
    set << 'foo'
    set.clean!

    set << 'bar'
    set.should_receive(:save).with(['bar'])
    set.clean!
  end

  it 'should not autosave without save_on_clean option' do
    set = new_set(:save_on_clean => false)
    set << 'foo'
    set.clean!

    set_too = new_set
    set_too.load
    set_too.clean.should == [].to_set
  end

  it 'should automagically work with max_dirty_items' do
    set = new_set(:max_dirty_items => 1, :save_on_clean => true)
    set << 'fuh'
    set << 'buh'

    set_too = new_set
    set_too.load
    set_too.clean.should == ['fuh', 'buh'].to_set
  end

  it 'should automagically work with clean_timeout option' do
    set = new_set(:clean_timeout => 10, :save_on_clean => true)
    set << 'fuh'

    Timecop.travel(Time.now + 20) do
      set << 'buh'

      set_too = new_set
      set_too.load
      set_too.clean.should == ['fuh', 'buh'].to_set
    end

  end

  it 'should not blow chunks when nothing to save' do
    set = new_set
    set.save([])
  end

  it 'should support clean_at_exit option' do
    set = new_set(:save_on_clean => true, :clean_at_exit => true)
    fork do
      set << 'exit'
    end
    Process.wait

    set_too = new_set
    set_too.load
    set_too.clean.should == ['exit'].to_set
  end

  it 'should support save event notification' do
    set = new_set
    listener = TestListener.new
    set.event_listener = listener
    set << 'foo'
    set.save

    listener.event.should == :save
    listener.message[0..4].should == 'Saved'
  end
end