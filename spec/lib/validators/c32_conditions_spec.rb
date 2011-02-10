require File.dirname(__FILE__) + '/../../spec_helper'

describe "C32 Conditions Validation" do
  fixtures :conditions, :problem_types, :snowmed_problems
  
  before(:each) do
    @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/conditions/joes_condition.xml'))
    @condition = conditions(:joes_condition)
    @scope = Validators::C32Validation::ComponentScope.new(
      :validation_type => Validation::C32_V2_5_C83_V2_0_TYPE,
      :logger => TestLoggerDevNull.new,
      :validator => "ComponentScopeTest",
      :inspection_type => "Testing",
      :component_module => :conditions,
      :reference_model => [@condition],
      :document => @document
    )
  end

  it "should verify an insurance provider matches in a C32 doc" do
    errors = @scope.validate
    errors.should be_empty
  end
end
