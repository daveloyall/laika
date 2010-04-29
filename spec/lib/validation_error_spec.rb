require File.dirname(__FILE__) + '/../spec_helper'
require 'validation_error'

module Laika
  describe ValidationError do
  
    it "should initialize its suberrors array" do
      ValidationError.new.suberrors.should == []    
    end

    context "with an initialized ValidationError" do
  
      before do
        @error = ValidationError.new(:section => 'foo', :field_name => 'bar')
      end

      it "should assign attributes from an initializer hash" do
        @error.section.should == 'foo'
        @error.field_name.should == 'bar'
      end
  
      it "to_hash should produce a hash of attributes" do
        @error.to_hash.should == { :section => 'foo', :field_name => 'bar' } 
      end
    end

    context "with a new ValidationError" do
      
      before do
        @error = ValidationError.new
      end

      it "should assign attributes from_hash" do
        @error.from_hash(:section => 'foo', :field_name => 'bar')
        @error.section.should == 'foo'
        @error.field_name.should == 'bar'
      end
  
      it "should ignore unknown attributes when responding to from_hash" do
        lambda { @error.from_hash(:dingo => 'foo') }.should_not raise_exception
      end

      it "from_hash should return self" do
        @error.from_hash(:section => 'bar').should == @error 
      end
    end
  end
end
