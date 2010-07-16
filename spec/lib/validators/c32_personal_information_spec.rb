require File.dirname(__FILE__) + '/../../spec_helper'

describe "C32 Registration Information" do
  fixtures :patients, :registration_information, :person_names, :addresses,
           :telecoms, :genders, :marital_statuses, :ethnicities, :races, :religions,
           :patient_identifiers

  before(:each) do
    @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/joe_c32.xml'))
    @joe = registration_information(:joe_smith)
    @scope = Validators::C32Validation::ComponentScope.new(
      :validation_type => Validation::C32_V2_5_TYPE,
      :logger => TestLoggerDevNull.new,
      :validator => "ComponentScopeTest",
      :inspection_type => "Testing",
      :component_module => :personal_information,
      :reference_model => @joe,
      :document => @document
    )
  end

  it "should verify an insurance provider matches in a C32 doc" do
    errors = @scope.validate
    errors.should be_empty
  end
end
