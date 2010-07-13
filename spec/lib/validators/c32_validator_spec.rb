require File.dirname(__FILE__) + '/../../spec_helper'

describe Validators::C32Validation do
  patient_fixtures

  describe "ComponentScope" do

    before do
      @scope = Validators::C32Validation::ComponentScope.new(
        :validation_type => Validation::C32_V2_5_TYPE,
        :logger => TestLoggerDevNull.new,
        :validator => "ComponentScopeTest",
        :inspection_type => "Testing"
      )
    end

    describe "expected and provided values" do

      before do
        @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/c32v2.5.xml'))
        @scope.update_attributes(:document => @document)
      end

      describe "for a flat component" do

        before do
          @language = languages(:joe_smith_english_language)
          @scope.update_attributes(
            :component_module => :languages,
            :reference_model  => [@language]
          )
        end

        it "should collect expected hash for language" do
          @scope.collect_expected_values.should == {
            :language_code => 'en-US',
            :language_ability_mode => 'RWR',
            :preference => true,
          } 
        end
      
        it "should collect provided hash for language" do
          @scope.collect_provided_values.should == [{
            :language_code => "en",
            :language_ability_mode => nil,
            :preference => nil,
          }]
        end
      end

      describe "for a component with nested subsections" do

        before do
          @medication = medications(:jennifer_thompson_medication)
          @scope.update_attributes(
            :component_module => :medications,
            :key => :medications_medication,
            :reference_model => [@medication]
          )
        end

        it "should collect expected hash for medication" do
          expected = @scope.collect_expected_values
          expected.should == {
            :product_coded_display_name => "Prednisone", 
            :free_text_brand_name => nil, 
            :medication_type => "Over the counter product", 
            :status => nil, 
            :quantity_ordered_value => nil, 
            :expiration_time => Date.new(2015,10,2),
          } 
        end

        it "should collect provided hashes for medication" do
          @scope.collect_provided_values.should == [{
            :product_coded_display_name => 'Augmentin', 
            :free_text_brand_name => 'Augmentin', 
            :medication_type => nil,
            :status => nil, 
            :quantity_ordered_value => nil, 
            :expiration_time => '20151002',
          },
          {
            :product_coded_display_name => 'Aspirin', 
            :free_text_brand_name => 'Aspirin', 
            :medication_type => nil,
            :status => nil, 
            :quantity_ordered_value => nil, 
            :expiration_time => nil,
          }]
        end

      end
    end

    describe "generically" do

      TEST_XML = <<-EOS
<?xml version="1.0" encoding="UTF-8"?>
<ClinicalDocument
   xmlns="urn:hl7-org:v3" xmlns:sdct="urn:hl7-org:sdct">
   <recordTarget>
      <patientRole>
         <patient>
            <languageCommunication>
               <templateId root='2.16.840.1.113883.3.88.11.32.2' />
               <languageCode code="en-US" />
               <modeCode code='RWR' displayName='Recieve Written'
                  codeSystem='2.16.840.1.113883.5.60'
                  codeSystemName='LanguageAbilityMode' />
               <preferenceInd value='true' />
            </languageCommunication>
            <languageCommunication>
               <templateId root='2.16.840.1.113883.3.88.11.32.2' />
               <languageCode code="de-DE" />
               <modeCode code='RSP' displayName='Recieve Spoken'
                  codeSystem='2.16.840.1.113883.5.60'
                  codeSystemName='LanguageAbilityMode' />
               <preferenceInd value='false' />
            </languageCommunication>
         </patient>
      </patientRole>
   </recordTarget>
</ClinicalDocument>
EOS

      before do
        @module = :languages
        @document = REXML::Document.new(TEST_XML)
        @scope.update_attributes(
          :component_module => @module,
          :document => @document
        )
      end

      it "should lazily initialize simple attributes" do
        @scope.unguarded_key.should be_nil
        @scope.key.should == @scope.component_module
      end

      it "should lazily initialize complex attributes" do
        @scope.unguarded_component_descriptors.should be_nil
        @scope.component_descriptors == Validators::C32Descriptors.get_component(@module) 
      end

      it "should raise an error if unable to find descriptor" do
        @scope.component_module = :foo
        lambda { @scope.component_descriptors }.should raise_error(Validators::ValidatorException)
      end

      it "should determine equality between expected and provided" do
        @scope.send(:_equal_values?, "foo", "foo").should be_true
        @scope.send(:_equal_values?, :foo, "foo").should be_true
        @scope.send(:_equal_values?, 1, "1").should be_true
      end
  
      it "should handle time conversion when determining equality" do
        @scope.send(:_equal_values?, Date.new(2010,5,27), "20100527").should be_true
      end

      it "should provide the xpath location of the current xml in scope" do
        @scope.location.should == '/ClinicalDocument' 
      end

      it "should determine if xml was located for a non-array" do
        @scope.stub!(:xml_value).and_return(true)
        @scope.xml_located?.should be_true
      end

      it "should determine if xml was not located for a non-array" do
        @scope.stub!(:xml_value).and_return(nil)
        @scope.xml_located?.should be_false
      end

      it "should determine if xml was located for an array" do
        @scope.stub!(:xml_value).and_return([true])
        @scope.xml_located?.should be_true
      end

      it "should determine if xml was not located for an array" do
        @scope.stub!(:xml_value).and_return([])
        @scope.xml_located?.should be_false
      end
 
    end

  end

  before do
    @validator = Validators::C32Validation::Validator.new
    @validator.validation_type = Validation::C32_V2_5_TYPE 
    @validator.logger = TestLoggerDevNull.new
    @patient = patients(:david_carter)
    @document = REXML::Document.new(@patient.to_c32)
  end

  it "should validate a v2.5 C32 document" do
    @validator.validate(@patient, @document).should == []
    flunk "haven't finished directives for all component modules yet"
  end

end
