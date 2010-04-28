require File.dirname(__FILE__) + '/../spec_helper'

describe ContentError do

  before do
    @error = ContentError.factory.create
  end

  it "should have no children when initialized" do
    @error.children.should be_empty
  end

  it "should be possible to add children" do
    error = @error
    error.children << ContentError.factory.create
    error.children << ContentError.factory.create
    error.children.count.should == 2
  end

  it "should have a parent" do
    parent = @error
    parent.children << (child = ContentError.factory.create)
    child.parent.should == parent
  end

  it "should initialize in the failed state" do
    @error.state.should == 'failed'
  end

  it "should shift to passed if pass is called" do
    @error.tap(&:pass).state.should == 'passed'
  end

  it "should shift to review if review is called" do
    @error.tap(&:review).state.should == 'review'
  end

  it "should shift to failed if fail is called" do
    @error.tap(&:fail).state.should == 'failed'
  end

end
