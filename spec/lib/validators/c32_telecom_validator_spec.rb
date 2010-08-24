require File.dirname(__FILE__) + '/../../spec_helper'

describe "C32 Telecom Validation" do
  fixtures :registration_information, :telecoms
 
  before(:each) do
    @registration = registration_information(:jennifer_thompson)
    @scope = Validators::C32Validation::ComponentScope.new(
      :validation_type => Validation::C32_V2_5_TYPE,
      :logger => TestLoggerDevNull.new,
      :validator => "ComponentScopeTest",
      :inspection_type => "Testing",
      :component_module => :healthcare_provider,
      :section => :telecom,
      :gold_model => @registration
    )
  end
  
  it "should properly verify telecoms with a use attribute" do
    pending do
      document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/telecom/jenny_telecom_with_uses.xml'))
      @scope.update_attributes(:xml_component => document)
      errors = @scope.validate
      errors.should be_empty
    end
  end
  
  it "should properly verify telecoms with out a use attribute" do
    pending do
      document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/telecom/jenny_telecom_no_uses.xml'))
      @scope.update_attributes(:xml_component => document)
      errors = @scope.validate
      errors.should be_empty
    end
  end
  
  it "should find errors when the use attribute is wrong" do
    pending do
      document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/telecom/jenny_telecom_wrong_uses.xml'))
      @scope.update_attributes(:xml_component => document)
      errors = @scope.validate
      errors.should_not be_empty
      errors.should have(2).errors
      errors[0].message.should == "Expected HP got HV"
    end
  end
  
  it "should find errors when a telecom is missing" do
    pending do
      document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/telecom/jenny_telecom_missing_mobile.xml'))
      @scope.update_attributes(:xml_component => document)
      errors = @scope.validate
      errors.should_not be_empty
      errors.should have(1).error
      errors[0].message.should == "Couldn't find the telecom for MC"
    end
  end

end

