require 'spec_helper'
require 'method_cache'

class MethodCacheTester
  include MethodCache
  
  attr_accessor :counter

  def initialize
    @counter = 0
  end

  def foo
    _method_cache(:foo) do
      puts 'hi!'
      @counter += 1
    end    
  end
end

describe MethodCache do
  
  before do
    @tester = MethodCacheTester.new
  end

  it "should cache the method call in the given attribute" do
    @tester.foo.should == 1
    @tester.foo.should == 1
    @tester.foo.should == 1
  end
end
