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
  
      it "attributes reader should produce a hash" do
        @error.attributes.should == { :section => 'foo', :field_name => 'bar' } 
      end
    end

    context "with a new ValidationError" do
      
      before do
        @error = ValidationError.new
      end

      it "should be able to assign attributes from a hash" do
        @error.attributes=({:section => 'foo', :field_name => 'bar'})
        @error.section.should == 'foo'
        @error.field_name.should == 'bar'
      end
  
      it "should ignore unknown attributes when mass assinging attributes attributes" do
        lambda { @error.attributes=({:dingo => 'foo'}) }.should_not raise_exception
      end

      it "should be able to update attributes and chain" do
        @error.update_attributes(:section => 'foo', :field_name => 'bar').should == @error
        @error.section.should == 'foo'
        @error.field_name.should == 'bar'
      end

    end
  end
end
