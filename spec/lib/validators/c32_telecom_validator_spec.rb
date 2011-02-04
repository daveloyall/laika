require File.dirname(__FILE__) + '/../../spec_helper'

describe "C32 Telecom Validation" do
  fixtures :registration_information, :telecoms
 
  C32_PERSONAL_INFORMATION_TELECOM_XML = <<EOS
<?xml version="1.0" encoding="UTF-8"?>
<ClinicalDocument
   xmlns="urn:hl7-org:v3" xmlns:sdct="urn:hl7-org:sdct">
   <recordTarget>
      <patientRole>
         <id extension="24602" root="SomeClinicalOrganizationOID"
            assigningAuthorityName="Some Clinical Organization Name" />
         <telecom use="HP" value="tel:+1-312-555-1234" />
         <addr>
            <streetAddressLine>1600 Rockville Pike</streetAddressLine>
            <city>Rockville</city>
            <state>MD</state>
            <postalCode>20847</postalCode>
            <country>US</country>
         </addr>
         <patient>
            <name>
               <prefix>Mr.</prefix>
               <given>Joe</given>
               <given>William</given>
               <family>Smith</family>
            </name>
            <administrativeGenderCode code="M" displayName="Male"
               codeSystemName="HL7 AdministrativeGenderCodes"
               codeSystem="2.16.840.1.113883.5.1">
               <originalText>
                  AdministrativeGender codes are: M (Male), F (Female)
                  or UN (Undifferentiated).
               </originalText>
            </administrativeGenderCode>
            <birthTime value="19670323" />
            <maritalStatusCode code="S" displayName="Never Married" codeSystemName="MaritalStatusCode" codeSystem="2.16.840.1.113883.5.2"/>
            <religiousAffiliationCode code="1013" displayName="Christian" codeSystemName="Religious Affiliation" codeSystem="2.16.840.1.113883.5.1076"/>
            <raceCode code="2108-9" displayName="European" codeSystemName="CDC Race and Ethnicity" codeSystem="2.16.840.1.113883.6.238"/>
            <ethnicGroupCode code="2137-8" displayName="Spaniard" codeSystemName="CDC Race and Ethnicity" codeSystem="2.16.840.1.113883.6.238"/>
            <languageCommunication>
               <templateId root='2.16.840.1.113883.3.88.11.32.2' />
               <languageCode code="en-US" />
               <modeCode code='RWR' displayName='Recieve Written'
                  codeSystem='2.16.840.1.113883.5.60'
                  codeSystemName='LanguageAbilityMode' />
               <preferenceInd value='true' />
            </languageCommunication>
         </patient>
      </patientRole>
   </recordTarget>
</ClinicalDocument>
EOS

  before(:each) do
    @document = REXML::Document.new(C32_PERSONAL_INFORMATION_TELECOM_XML)
    @registration = registration_information(:joe_smith)
    @scope = Validators::C32Validation::ComponentScope.new(
      :validation_type => Validation::C32_V2_5_TYPE,
      :logger => TestLoggerDevNull.new,
      :validator => "ComponentScopeTest",
      :inspection_type => "Testing",
      :component_module => :personal_information,
      :reference_model => @registration,
      :document => @document
    )
  end
  
  it "should properly verify telecoms with a use attribute" do
    errors = @scope.validate
    errors.should be_empty
  end
  
  it "should properly verify telecoms with out a use attribute" do
    @document.elements.delete_all('//telecom')
    @document.root.insert_after('recordTarget/patientRole/id', telecom = REXML::Element.new('telecom'))
    telecom.attributes['value'] = "tel:+1-312-555-1234"
    errors = @scope.validate
    errors.should have(1).errors
    errors[0].message.should match(/Unable to find any Use/)
  end
  
  it "should find errors when the use attribute is wrong" do
    @document.elements.each('//telecom') { |e| e.attributes['use'] = 'foo' }
    errors = @scope.validate
    errors.should have(1).errors
    errors[0].message.should == 'Expected HP got foo'
  end
  
  it "should find errors when the use attribute there is no matching value" do
    @document.elements.each('//telecom') { |e| e.attributes['value'] = 'foo' }
    errors = @scope.validate
    errors.should have(1).errors
    errors[0].message.should match(/No matching Telecom Values/)
  end

  it "should find errors when a telecom is missing" do
    @document.elements.delete_all('//telecom')
    errors = @scope.validate
    errors.should_not be_empty
    errors.should have(1).error
    errors[0].message.should match(/Unable to find any Telecom Values/)
  end

end

