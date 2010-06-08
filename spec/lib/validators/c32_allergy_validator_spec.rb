require File.dirname(__FILE__) + '/../../spec_helper'

describe "C32 Allergy Validation" do
  fixtures :allergies, :severity_terms, :adverse_event_types

  before(:each) do
    @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/allergies/joe_allergy.xml'))
    @allergy = allergies(:joes_allergy)
    @scope = Validators::C32Validation::ComponentScope.new(
      :validation_type => Validation::C32_V2_5_TYPE,
      :logger => TestLogger.new,
      :validator => "ComponentScopeTest",
      :inspection_type => "Testing",
      :component_module => :allergies,
      :section => :allergies,
      :gold_model_array => [@allergy],
      :xml_component => @document
    )
  end

  it "should verify an allergy matches in a C32 doc" do
    errors = @scope.validate
    errors.should be_empty
  end

  it "should fail if we cannot match an allergy section" do
    @allergy.stub!(:free_text_product).and_return('foo')
    errors = @scope.validate
    errors.size.should == 1
    errors.first.should be_kind_of(Laika::NoMatchingSection)
    errors.first.location.should == '/ClinicalDocument/component/structuredBody/component/section/entry/act/entryRelationship/observation'
    errors.first.expected_section.should == {
      :free_text_product => "foo",
      :start_event => "February 21, 2006",
      :end_event => nil,
      :product_code => "70618",
    }
    errors.first.provided_sections.should == [
      {
        :free_text_product => "Penicillin",
        :start_event => "20060221",
        :end_event => nil,
        :product_code => "70618",
      },
    ]
  end

  it "should verify when there are no known allergies" do
    pending "validate for no known allergies" do
      document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/allergies/no_known_allergies.xml'))
      allergy = Allergy.new
      @scope.update_attributes(
        :gold_model_array => [allergy],
        :xml_component => document
      )
      errors = @scope.validate
      errors.should be_empty
    end
  end
end
