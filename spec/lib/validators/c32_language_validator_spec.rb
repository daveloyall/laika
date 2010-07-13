require File.dirname(__FILE__) + '/../../spec_helper'

describe "C32 Language Validation" do
  fixtures :languages

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

  before(:each) do
    @document = REXML::Document.new(C32_LANGUAGES_XML)
    @language = languages(:joe_smith_english_language)
    @scope = Validators::C32Validation::ComponentScope.new(
      :validation_type => Validation::C32_V2_5_TYPE,
      :logger => TestLoggerDevNull.new,
      :validator => "ComponentScopeTest",
      :inspection_type => "Testing",
      :component_module => :languages,
      :reference_model => [@language],
      :document => @document
    )
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
      :preference => true,
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
    #pp errors
    errors.size.should == 1
    e = errors.first
    e.should be_kind_of(Laika::ComparisonError)
    e.expected.should == 'false'
    e.provided.should == 'true'
    REXML::XPath.first(@document.root, e.location).should == REXML::XPath.first(@document.root, "//languageCommunication[1]/preferenceInd")
  end

  it "should not fail if language_ability_mode is absent" do
    @language.language_ability_mode = nil
    errors = @scope.validate
    #pp errors
    errors.size.should == 0
  end

  it "should not fail if preference is absent" do
    @language.preference = nil
    errors = @scope.validate
    #pp errors
    errors.size.should == 0
  end

  describe "with multiple languages" do
    
    before do
      @german = languages(:emily_jones_german_language)
      @scope.update_attributes(:reference_model  => [@language, @german])
    end

    it "should handle multiple languages" do
      @scope.validate.size.should == 0
    end
  
    it "should provide matching errors if unable to match amid multiple languages" do
      @german.preference = true
      @language.stub!(:language_code).and_return('foo')
      errors = @scope.validate
      errors.size.should == 2
      match_error = errors.first
    #  puts match_error.inspect
      match_error.should be_kind_of(Laika::NoMatchingSection)
      match_error.expected_section.should_not be_empty
      match_error.provided_sections.should_not be_empty
      comparison_error = errors.last
    #  puts comparison_error.inspect
      comparison_error.should be_kind_of(Laika::ComparisonError)
      comparison_error.expected.should == 'true'
      comparison_error.provided.should == 'false'
    end
  end

end
