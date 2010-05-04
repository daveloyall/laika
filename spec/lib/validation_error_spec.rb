require File.dirname(__FILE__) + '/../spec_helper'

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

      it "should assign attributes attributes" do
        @error.attributes(:section => 'foo', :field_name => 'bar')
        @error.section.should == 'foo'
        @error.field_name.should == 'bar'
      end
  
      it "should ignore unknown attributes when responding to attributes" do
        lambda { @error.attributes(:dingo => 'foo') }.should_not raise_exception
      end

      it "attributes should return self" do
        @error.attributes(:section => 'bar').should == @error 
      end
    end
  end
end
