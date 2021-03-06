require File.dirname(__FILE__) + '/../spec_helper'

# Test plan type used for testing.
class MyTestPlan < TestPlan
  test_name 'My Test Plan'
end

describe TestPlan do
  before { Laika::TEST_PLAN_TYPES['My Test Plan'] = MyTestPlan }
  after { Laika::TEST_PLAN_TYPES.delete 'My Test Plan' }

  it "should list all test plans" do
    TestPlan.test_types.values.should include(MyTestPlan)
  end

  it "should start in pending state" do
    MyTestPlan.factory.create.state.should == 'pending'
  end

  it "should transition from pending to passed" do
    MyTestPlan.factory.create.tap(&:pass).state.should == 'passed'
  end

  it "should transition from pending to failed" do
    MyTestPlan.factory.create.tap(&:fail).state.should == 'failed'
  end

  it "should be possible to force transition from pending to pass" do
    MyTestPlan.factory.create.tap(&:force_pass).state.should == 'passed'
  end

  it "should be possible to force transition from fail to pass" do
    plan = MyTestPlan.factory.create.tap(&:fail)
    plan.tap(&:force_pass).state.should == 'passed'
  end

  it "should be possible to force transition from fail to pass" do
    plan = MyTestPlan.factory.create.tap(&:fail)
    plan.tap(&:force_pass).state.should == 'passed'
  end

  it "should remain passed if passed and force_pass" do
    plan = MyTestPlan.factory.create.tap(&:pass)
    plan.tap(&:force_pass!).state.should == 'passed'
  end

  it "should be possible to force transition from pending to fail" do
    MyTestPlan.factory.create.tap(&:force_fail).state.should == 'failed'
  end

  it "should be possible to force transition from pass to fail" do
    plan = MyTestPlan.factory.create.tap(&:pass)
    plan.tap(&:force_fail).state.should == 'failed'
  end

  it "should remain failed if failed and force_fail" do
    plan = MyTestPlan.factory.create.tap(&:fail)
    plan.tap(&:force_fail!).state.should == 'failed'
  end

  describe "override_state" do
    before do
      @plan = MyTestPlan.factory.create
      @plan.status_override_reason.should be_nil
    end

    it "should override pending to passed" do
      @plan.override_state!( 'state' => 'passed', 'status_override_reason' => 'foo')
      @plan.state.should == 'passed'
      @plan.status_override_reason.should == 'foo'
    end

    it "should override pending to failed" do
      @plan.override_state!( 'state' => 'failed', 'status_override_reason' => 'foo')
      @plan.state.should == 'failed'
      @plan.status_override_reason.should == 'foo'
    end

    it "should override passed to passed" do
      @plan.pass!
      @plan.override_state!( 'state' => 'passed', 'status_override_reason' => 'foo')
      @plan.state.should == 'passed'
      @plan.status_override_reason.should == 'foo'
    end

    it "should override passed to failed" do
      @plan.pass!
      @plan.override_state!( 'state' => 'failed', 'status_override_reason' => 'foo')
      @plan.state.should == 'failed'
      @plan.status_override_reason.should == 'foo'
    end

    it "should override failed to passed" do
      @plan.fail!
      @plan.override_state!( 'state' => 'passed', 'status_override_reason' => 'foo')
      @plan.state.should == 'passed'
      @plan.status_override_reason.should == 'foo'
    end

    it "should override failed to failed" do
      @plan.fail!
      @plan.override_state!( 'state' => 'failed', 'status_override_reason' => 'foo')
      @plan.state.should == 'failed'
      @plan.status_override_reason.should == 'foo'
    end

  end
end

