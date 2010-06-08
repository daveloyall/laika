require File.dirname(__FILE__) + '/../../spec_helper'

describe "C32 Isurance Provider Validation" do
  fixtures :insurance_providers, :insurance_types, :coverage_role_types, :role_class_relationship_formal_types, :insurance_provider_guarantors, :insurance_provider_patients, :insurance_provider_subscribers
  
  before(:each) do
    @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/insurance_provider/insurance_provider.xml'))
    @insurance_provider = insurance_providers(:joe_smiths_insurance_provider)
    @scope = Validators::C32Validation::ComponentScope.new(
      :validation_type => Validation::C32_V2_5_TYPE,
      :logger => TestLogger.new,
      :validator => "ComponentScopeTest",
      :inspection_type => "Testing",
      :component_module => :insurance_providers,
      :section => :insurance_providers,
      :gold_model_array => [@insurance_provider],
      :xml_component => @document
    )
  end

  it "should verify an insurance provider matches in a C32 doc" do
    errors = @scope.validate
    pp errors
    errors.should be_empty
    flunk "finish insurance provider directives"
  end

  it "should match group number if exists"
  it "should match insurance type code if exists"

end
