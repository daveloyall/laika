require File.dirname(__FILE__) + '/../../spec_helper'

describe "C32 Allergy Validation" do
  fixtures :allergies, :severity_terms, :adverse_event_types, :code_systems

  before(:each) do
    @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/allergies/joe_allergy.xml'))
    @allergy = allergies(:joes_allergy)
    @scope = Validators::C32Validation::ComponentScope.new(
      :validation_type => Validation::C32_V2_5_C83_V2_0_TYPE,
      :logger => TestLoggerDevNull.new,
      :validator => "ComponentScopeTest",
      :inspection_type => "Testing",
      :component_module => :allergies,
      :reference_model => [@allergy],
      :document => @document
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
      :start_event => Date.new(2006,2,21),
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
    document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/allergies/no_known_allergies.xml'))
    allergy = Allergy.new
    @scope.update_attributes(
      :reference_model => [allergy],
      :document => document
    )
    errors = @scope.validate
    errors.should be_empty
  end

  # The point of this test is to verify that we can locate and make content comparisons for
  # an allergy product code regardless of which codeSystem is set.  It is not attempting to verify
  # that the cda:code/@code is correct for the cda:code/@codeSystem.  That is not something the
  # content validator is checking.
  it "should match for product code regardless of codeSystem (170)" do
    fda_uniii = code_systems(:fda_uniii)
    product_code = REXML::XPath.first(@document.root, %q{//cda:participant[@typeCode='CSM']/cda:participantRole[@classCode='MANU']/cda:playingEntity[@classCode='MMAT']/cda:code}, {'cda' => 'urn:hl7-org:v3'})
    assert_not_nil product_code
    product_code.attributes['codeSystem'] = fda_uniii.code
    product_code.attributes['codeSystemName'] = fda_uniii.name
    original_code = @allergy.product_code
    @allergy.update_attributes(:product_code => 'foo')

    errors = @scope.validate
    errors.size.should == 1
    errors.first.should be_kind_of(Laika::ComparisonError)
    errors.first.field_name.should == :product_code

    product_code.attributes['code'] = 'foo'
    @allergy.code_system = code_systems(:fda_uniii)
    @scope.clear
    errors = @scope.validate
    errors.should be_empty
  end

end
