require File.dirname(__FILE__) + '/../spec_helper'

describe ContentErrorsController do

  describe "while logged in" do
    before do
      @user = User.factory.create
      @error = ContentError.factory.create
      @controller.stub(:current_user).and_return(@user)
    end

    it "should pass manually" do
      xhr :put, :mark, :id => @error.id, :content_error => { :state => "passed" }
      @error.reload
      @error.state.should == 'passed'
    end

    it "should fail manually" do
      xhr :put, :mark, :id => @error.id, :content_error => { :state => "failed" }
      @error.reload
      @error.state.should == 'failed'
    end

    it "should set to review manually" do
      xhr :put, :mark, :id => @error.id, :content_error => { :state => "review" }
      @error.reload
      @error.state.should == 'review'
    end

    it "should not set an arbitrary state" do
      xhr :put, :mark, :id => @error.id, :content_error => { :state => "foo" }
      @error.reload
      @error.state.should == 'failed'
    end

  end
end
