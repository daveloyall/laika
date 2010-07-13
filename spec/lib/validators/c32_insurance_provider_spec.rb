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
      :reference_model => [@insurance_provider],
      :document => @document
    )
  end

  it "should verify an insurance provider matches in a C32 doc" do
    errors = @scope.validate
    pp errors
    errors.should be_empty
    flunk "finish insurance provider directives"
  end

  it "should match group number if exists" do
    original_group_number = @insurance_provider.group_number
    @insurance_provider.group_number = 12345
    errors = @scope.validate
    errors.size.should == 1
    errors.first.should be_kind_of(Laika::ComparisonError)
    @insurance_provider.group_number = original_group_number
    @scope.clear
    @scope.validate.should == []
  end

  it "should match represented_organization if exists" do
    @insurance_provider.represented_organization.should_not be_nil
    @scope.validate.should == []
  end

  it "should match insurance_provider_guarantor" do
    pp @insurance_provider.insurance_provider_guarantor
    pp @insurance_provider.insurance_provider_guarantor.person_name
  end
end
