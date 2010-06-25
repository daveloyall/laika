require 'spec_helper'
require 'ruby_ext'

describe Object do

  it 'should tap to yield self and return self' do
    foo = "foo"
    foo.tap { |s| s.should be foo }.reverse.should == 'oof'
  end

  it 'should try a method and send one that exists' do
    "foo".try('reverse').should == 'oof'
  end

  it 'should try a method with parameters' do
    "foo".try(:replace, 'bar').should == 'bar'
  end

  it 'should try a method with a block' do
    [1, 2, 3].try(:select) { |i| i == 2 }.should == [2]
  end

  it 'should try a method that does not exist and return nil' do
    [].try(:foo).should be_nil
  end

  it 'should return nil if try is used on Nil' do
    nil.try(:replace).should be_nil
  end

end
