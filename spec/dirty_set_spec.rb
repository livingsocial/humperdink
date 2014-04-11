require File.dirname(__FILE__) + '/spec_helper'

describe Humperdink::DirtySet do
  let(:set) { Humperdink::DirtySet.new }

  it 'should initialize empty by default' do
    set.clean.should == [].to_set
    set.dirty.should == [].to_set
  end

  it 'should initialize clean with initialize' do
    set = Humperdink::DirtySet.new(['a', 'b'])
    set.clean.should == ['a', 'b'].to_set
    set.dirty.should == [].to_set
  end

  it 'should only append to dirty' do
    set << 'foo'
    set.clean.should == [].to_set
    set.dirty.should == ['foo'].to_set
  end

  it 'should only append to dirty if not in clean' do
    set = Humperdink::DirtySet.new(['foo'])
    set << 'foo'
    set.clean.should == ['foo'].to_set
    set.dirty.should == [].to_set
  end

  it 'should clean! dirty things to clean' do
    set << 'foo'
    wuz_dirty = set.clean!
    wuz_dirty.should == ['foo']
    set.clean.should == ['foo'].to_set
    set.dirty.should == [].to_set
  end

  it 'should support max_clean_items option' do
    set = Humperdink::DirtySet.new(:max_clean_items => 3)
    set << 'foo'
    set << 'bar'
    set << 'baz'
    set << 'quux'
    set.clean!
    set.clean.length.should == 3
    set.dirty.length.should == 0
  end

  it 'should support max_dirty_items option' do
    set = Humperdink::DirtySet.new(:max_dirty_items => 3)
    set << 'foo'
    set << 'bar'
    set << 'baz'
    set << 'quux'
    set.clean.length.should == 4
    set.dirty.length.should == 0
  end

  it 'should return length of clean keys' do
    set << 'foo'
    set.length.should == 0
    set.clean!
    set.length.should == 1
  end

  it 'should support exclude regex list option' do
    set = Humperdink::DirtySet.new(:exclude_from_clean => [/foo/])
    set << 'foo'
    set << 'bar'
    set.dirty.should == ['foo', 'bar'].to_set
    set.clean!
    set.dirty.should == [].to_set
    set.clean.should == ['bar'].to_set
  end

  it 'should support clean_timeout option' do
    set = Humperdink::DirtySet.new(:clean_timeout => 10)
    set << 'foo'
    Timecop.travel(Time.now + 20) do
      set << 'bar' # dirty addition must occur after timeout to trigger the automatic clean!
      set.dirty.should == [].to_set
      set.clean.should == ['foo', 'bar'].to_set

      set << 'baz'
      set.dirty.should == ['baz'].to_set
      set.clean.should == ['foo', 'bar'].to_set

      Timecop.travel(Time.now + 20) do
        set << 'quux'
        set.dirty.should == [].to_set
        set.clean.should == ['foo', 'bar', 'baz', 'quux'].to_set
      end
    end
  end

  it 'will not trigger on clean_timeout all by itself' do
    set = Humperdink::DirtySet.new(:clean_timeout => 10)
    set << 'foo'
    set << 'bar'
    Timecop.travel(Time.now + 20) do
      set.dirty.should == ['foo', 'bar'].to_set
      set.clean.should == [].to_set
    end
  end

  it 'should clear itself' do
    set = Humperdink::DirtySet.new(:max_dirty_items => 1)
    set << 'foo'
    set << 'bar'
    set << 'quux'
    set.dirty.length.should == 1
    set.clean.length.should == 2
    set.clear
    set.dirty.length.should == 0
    set.clean.length.should == 0
  end

  it 'should support clean! event notification' do
    listener = TestListener.new
    set = Humperdink::DirtySet.new(:event_listener => listener)

    count = rand(7) + 3
    count.times do |i|
      set << "foo-#{i}"
    end

    set.clean!
    listener.event.should == :clean!
    listener.data[:count].should == count
  end
end