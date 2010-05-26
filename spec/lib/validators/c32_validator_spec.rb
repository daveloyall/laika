require File.dirname(__FILE__) + '/../../spec_helper'

class TestLogger
  [:debug, :info, :warn, :error].each do |m|
    define_method(m) { |message| puts "#{m.to_s.upcase}: #{message}" }
  end
end

describe Validators::C32Validation do
  patient_fixtures

  describe "ComponentScope" do

    before do
      @scope = Validators::C32Validation::ComponentScope.new(
        :validation_type => Validation::C32_V2_5_TYPE,
        :logger => TestLogger.new,
        :validator => "ComponentScopeTest",
        :inspection_type => "Testing"
      )
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

      it "should build an expected section hash from the gold model" do
        @scope.update_attributes(:gold_model => languages(:joe_smith_english_language))
        @scope.gold_expected_section_hash(:language_communication).should == {
          :language_code => "en-US",
          :language_ability_mode => 'RWR',
          :preference => 'true',
        }
      end
  
      it "should build a provided sections array from the section nodes" do
        @scope.update_attributes(:xml_section_nodes => REXML::XPath.match(@document.root, '//languageCommunication'))
        @scope.xml_provided_sections_array(:language_communication).should == [
          {
            :language_code => "en-US",
            :language_ability_mode => 'RWR',
            :preference => 'true',
          },
          {
            :language_code => "de-DE",
            :language_ability_mode => 'RSP',
            :preference => 'false',
          },
        ]
      end

    end

    describe "Languages" do

      C32_LANGUAGES_XML = <<-EOS
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
        @document = REXML::Document.new(C32_LANGUAGES_XML)
        @language = languages(:joe_smith_english_language)
        @scope.update_attributes(
          :component_module => :languages,
          :section => :languages,
          :gold_model_array => [@language],
          :xml_component => @document
        )
        @german = languages(:emily_jones_german_language)
      end

      it "should validate the Languages component" do
        @scope.validate.should == []
      end

      it "should fail if there are no languageCommunication sections" do
        @document.elements.delete_all('//languageCommunication')
        errors = @scope.validate
        errors.size.should == 1
        errors.first.should be_kind_of(Laika::SectionNotFound)
        errors.first.location.should == '/ClinicalDocument/recordTarget/patientRole/patient'
      end

      it "should fail if we cannot match a languageCommunication section" do
        @language.stub!(:language_code).and_return('foo')
        errors = @scope.validate
        errors.size.should == 1
        errors.first.should be_kind_of(Laika::NoMatchingSection)
        errors.first.location.should == '/ClinicalDocument/recordTarget/patientRole/patient/languageCommunication[1]'
        errors.first.expected_section.should == {
          :language_code => "foo",
          :language_ability_mode => 'RWR',
          :preference => 'true',
        }
        errors.first.provided_sections.should == [
          {
            :language_code => "en-US",
            :language_ability_mode => 'RWR',
            :preference => 'true',
          },
          {
            :language_code => "de-DE",
            :language_ability_mode => 'RSP',
            :preference => 'false',
          },
        ]
      end

      it "should fail if language_ability_mode does not match" do
        mode_stub = stub.as_null_object
        mode_stub.stub!(:code).and_return('foo')
        @language.stub!(:language_ability_mode).and_return(mode_stub)
        errors = @scope.validate
        errors.size.should == 1
        e = errors.first
        e.should be_kind_of(Laika::ComparisonError)
        e.expected.should == 'foo'
        e.provided.should == 'RWR'
        errors.first.location.should == '/ClinicalDocument/recordTarget/patientRole/patient/languageCommunication[1]/modeCode'
        REXML::XPath.first(@document.root, e.location).should == REXML::XPath.first(@document.root, "//languageCommunication[1]/modeCode")
      end

      it "should fail if preference does not match" do
        @language.preference = false
        errors = @scope.validate
        errors.size.should == 1
        e = errors.first
        e.should be_kind_of(Laika::ComparisonError)
        e.expected.should == 'false'
        e.provided.should == 'true'
        REXML::XPath.first(@document.root, e.location).should == REXML::XPath.first(@document.root, "//languageCommunication[1]/preferenceInd")
      end

      it "should not fail if language_ability_mode is absent" do
        @language.language_ability_mode = nil
        @scope.validate.size.should == 0
      end

      it "should not fail if preference is absent" do
        @language.preference = nil
        errors = @scope.validate
        puts errors.inspect
        errors.size.should == 0
      end

      it "should handle multiple languages" do
        @scope.update_attributes(:gold_model_array => [@language, @german])
        @scope.validate.size.should == 0
      end

      it "should provide matching errors if unable to match amid multiple languages" do
        @german.preference = true
        @language.stub!(:language_code).and_return('foo')
        @scope.update_attributes(:gold_model_array => [@language, @german])
        errors = @scope.validate
        errors.size.should == 2
        match_error = errors.first
#        puts match_error.inspect
        match_error.should be_kind_of(Laika::NoMatchingSection)
        match_error.expected_section.should_not be_empty
        match_error.provided_sections.should_not be_empty
        comparison_error = errors.last
#        puts comparison_error.inspect
        comparison_error.should be_kind_of(Laika::ComparisonError)
        comparison_error.expected.should == 'true'
        comparison_error.provided.should == 'false'
      end

    end

  end

  before do
    @validator = Validators::C32Validation::Validator.new
    @validator.validation_type = Validation::C32_V2_5_TYPE 
    @validator.logger = TestLogger.new
    @patient = patients(:david_carter)
    @document = REXML::Document.new(@patient.to_c32)
  end

  it "should validate a v2.5 C32 document" do
    puts @validator.validate(@patient, @document).inspect
  end

end
