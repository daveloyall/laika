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

    describe "dereference" do
  
      before do
        @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/c32v2.5.xml'))
        @scope.update_attributes(:xml_component => @document)
        @nodes = REXML::XPath.match(@document.root, '//substanceAdministration')
        @nodes.should_not be_empty
      end
  
      it "should be able to produce a hash of dereferenced subsections" do
        references = @scope.dereference(nil, @nodes)
        references.keys.should == ['Augmentin', 'Aspirin']
        references.values.each { |v| 'substanceAdministration'.should == v.name }
      end
  
      it "should handle attempts to dereference a section without referenced content" do
        @document.elements.delete_all('//text')
        references = @scope.dereference(nil, @nodes)
        references.should == {}
      end
  
      it "should handle attempts to dereference a section without references" do
        @document.elements.delete_all('//reference')
        references = @scope.dereference(nil, @nodes)
        references.should == {}
      end
    end

    describe "expected and provided values" do

      before do
        @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/c32v2.5.xml'))
        @scope.update_attributes(:xml_component => @document)
      end

      describe "for a flat component" do

        before do
          @language = languages(:joe_smith_english_language)
          @scope.update_attributes(
            :component_module => :languages,
            :section          => :language_communication,
            :gold_model       => @language
          )
        end

        it "should collect expected hash for language" do
          @scope.collect_expected_values.should == {
            :language_code => "en-US",
            :language_ability_mode => 'RWR',
            :preference => 'true',
          } 
        end
      
        it "should collect provided hash for language" do
          @scope.update_attributes(:xml_component => REXML::XPath.first(@document.root, '//languageCommunication'))
          @scope.collect_provided_values.should == {
            :language_code => "en",
            :language_ability_mode => nil,
            :preference => nil,
          }
        end
      end

      describe "for a component with nested subsections" do

        before do
          @medication = medications(:jennifer_thompson_medication)
          @scope.update_attributes(
            :component_module => :medications,
            :section          => :medication,
            :gold_model       => @medication
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
            :expiration_time => "October 02, 2015",
          } 
        end

        it "should collect provided hashes for medication" do
          @scope.update_attributes(:xml_component => REXML::XPath.first(@document.root, '//substanceAdministration'))
          @scope.collect_provided_values(:medication, 'foo').should == {
            :product_coded_display_name => "foo", 
            :free_text_brand_name => 'Augmentin', 
            :medication_type => nil,
            :status => nil, 
          }
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
        @document = REXML::Document.new(TEST_XML)
        @scope.update_attributes(:xml_component => @document)
      end

      it "should provide access to the root element" do
        @scope.root_element.should == @document.root
        @scope.descend(:xml_component => nil, :xml_section_nodes => [@scope.xml_component]).root_element.should == @document.root
      end

      it "should pull directives by version" do
        Validators::C32Validation::DirectiveMap::SECTION_DIRECTIVES_MAP[:by_version_test] = {
          Validation::C32_V2_5_TYPE => {
            :action => :foo,
          },
          :action => :bar,
        }
        @scope.action(:by_version_test).should == :foo
        @scope.validation_type = Validation::C32_V2_1_2_3_TYPE
        @scope.action(:by_version_test).should == :bar
      end
      
      it "should raise a SectionDirectiveException when key is unknown" do
        lambda { @scope.section_directives_map_entry(:testing_no_key) }.should raise_error(Validators::SectionDirectiveException)
      end
 
      it "should determine equality between expected and provided" do
        @scope.send(:_equal_values?, "foo", "foo").should be_true
        @scope.send(:_equal_values?, :foo, "foo").should be_true
        @scope.send(:_equal_values?, 1, "1").should be_true
      end
  
      it "should handle time conversion when determining equality" do
        @scope.send(:_equal_values?, Date.new(2010,5,27), "20100527").should be_true
      end

      it "should catch requests to *_if_exists_in_model" do
        @scope.stub!(:gold_expected_value).and_return(true)
        @scope.should_receive(:foo)
        @scope.foo_if_exists_in_model
      end

      it "should set xml_component to Document.root if given a Document" do
        @scope.xml_component.should == @document.root
      end
  
      it "should provide the xpath location of the current xml in scope" do
        @scope.location.should == '/ClinicalDocument' 
      end
  
      it "should find the innermost element" do
        @scope.find_innermost_element('/foo/bar', @document.root).xpath.should == '/ClinicalDocument'
        @scope.find_innermost_element('//foo/bar', @document.root).xpath.should == '/ClinicalDocument'
        @scope.find_innermost_element('foo/bar', @document.root).xpath.should == '/ClinicalDocument'

        language = @scope.find_innermost_element('//cda:recordTarget/cda:patientRole/cda:patient/cda:languageCommunication/bar', @document.root)

        @scope.find_innermost_element("cda:languageCode[@code='en-US']", language).xpath.should == '/ClinicalDocument/recordTarget/patientRole/patient/languageCommunication[1]/languageCode'
        @scope.find_innermost_element("cda:languageCode[@code='foo']", language).xpath.should == '/ClinicalDocument/recordTarget/patientRole/patient/languageCommunication[1]/languageCode'
        @scope.find_innermost_element("cda:modeCode/@code]", language).xpath.should == '/ClinicalDocument/recordTarget/patientRole/patient/languageCommunication[1]/modeCode'
      end

      it "should return nil if extract_first_node is given a nil locator" do
        @scope.extract_first_node("", @document.root).should be_nil
        @scope.extract_first_node(nil, @document.root).should be_nil
      end

      it "should return empty array if extract_all_nodes is given a nil locator" do
        @scope.extract_all_nodes("", @document.root).should == []
        @scope.extract_all_nodes(nil, @document.root).should == []
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
    puts @validator.validate(@patient, @document).inspect
  end

end
