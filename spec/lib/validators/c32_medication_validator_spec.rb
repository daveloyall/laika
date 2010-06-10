require File.dirname(__FILE__) + '/../../spec_helper'

describe "C32 Medication Validation" do
  fixtures :medications, :code_systems, :medication_types

  before(:each) do
    @medication = medications(:jennifer_thompson_medication)
    @scope = Validators::C32Validation::ComponentScope.new(
      :validation_type => Validation::C32_V2_5_TYPE,
      :logger => TestLoggerDevNull.new,
      :validator => "ComponentScopeTest",
      :inspection_type => "Testing",
      :component_module => :medications,
      :section => :medications,
      :gold_model_array => [@medication]
    )
  end

  describe "with a v2.3" do

    before do
      @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/medications/jenny_medication.xml'))
      @scope.update_attributes(
        :xml_component => @document,
        :validation_type => Validation::C32_V2_1_2_3_TYPE
      )
    end

    it "should verify a medication in a C32 doc version 2.3" do
      errors = @scope.validate
      errors.should be_empty
    end

  end

  describe "with a v2.5" do

    before do
      @medication.quantity_ordered_value = 30.0
      @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/medications/jenny_medication_2.5.xml'))
      @scope.update_attributes( :xml_component => @document )
    end

    it "should verify a medication in a C32 doc version 2.5" do
      errors = @scope.validate
      errors.should be_empty
    end
  
    it "should fail if there are no substanceAdministration sections" do
      @document.elements.delete_all('//substanceAdministration')
      errors = @scope.validate
      errors.size.should == 1
      errors.first.should be_kind_of(Laika::SectionNotFound)
      errors.first.location.should == '/ClinicalDocument/component/structuredBody/component/section/entry'
    end

    it "should fail if we cannot mach a substanceAdministration section" do
      @medication.stub!(:product_coded_display_name).and_return('foo')
      errors = @scope.validate
      errors.size.should == 1
      errors.first.should be_kind_of(Laika::NoMatchingSection)
      errors.first.location.should == '/ClinicalDocument/component/structuredBody/component/section/entry/substanceAdministration'
      errors.first.expected_section.should == {
        :product_coded_display_name => "foo", 
        :free_text_brand_name => nil, 
        :medication_type => "Over the counter product", 
        :status => nil, 
        :quantity_ordered_value => "30.0", 
        :expiration_time => "October 02, 2015",
      }
      errors.first.provided_sections.should == [
        {
          :product_coded_display_name => "Prednisone", 
          :free_text_brand_name => nil, 
          :medication_type => "Over the counter product", 
          :status => nil, 
          :quantity_ordered_value => "30.0", 
          :expiration_time => "20151002",
        },
      ]
    end

    it "should return multiple provider sections when no matching section found" do
      @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/c32v2.5.xml'))
      @scope.update_attributes( :xml_component => @document )
      @medication.stub!(:product_coded_display_name).and_return('foo')
      errors = @scope.validate
      errors.size.should == 1
      errors.first.should be_kind_of(Laika::NoMatchingSection)
      errors.first.location.should == "/ClinicalDocument/component/structuredBody/component[2]/section/entry/substanceAdministration[1]"
      errors.first.expected_section.should == {
        :product_coded_display_name => "foo", 
        :free_text_brand_name => nil, 
        :medication_type => "Over the counter product", 
        :status => nil, 
        :quantity_ordered_value => "30.0", 
        :expiration_time => "October 02, 2015",
      }
      errors.first.provided_sections.should == [
        {:product_coded_display_name => "Augmentin",
         :free_text_brand_name => "Augmentin",
         :medication_type => nil,
         :status => nil,
         :quantity_ordered_value => nil,
         :expiration_time => "20151002",
        },
        {:product_coded_display_name => "Aspirin",
         :free_text_brand_name => "Aspirin",
         :medication_type => nil,
         :status => nil}
      ]
    end

    it "should fail if a field does not match"
    it "should fail if we cannot find a consumable"
      
  end
end
