require File.dirname(__FILE__) + '/../spec_helper'

describe XmlHelper, "can match values in XML" do
  it "should return nil when a value properly matches" do
    document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/joe_c32.xml'))
    patient_element = REXML::XPath.first(document, '/cda:ClinicalDocument/cda:recordTarget/cda:patientRole', {'cda' => 'urn:hl7-org:v3'})
    error = XmlHelper.match_value(patient_element, 'cda:patient/cda:name/cda:given', 'Joe')
    error.should be_nil
  end
  
  it "should return an error string when the values don't match" do
    document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/joe_c32.xml'))
    patient_element = REXML::XPath.first(document, '/cda:ClinicalDocument/cda:recordTarget/cda:patientRole', {'cda' => 'urn:hl7-org:v3'})
    error = XmlHelper.match_value(patient_element, 'cda:patient/cda:name/cda:given', 'Billy')
    error.should_not be_nil
    error.should == "Expected Billy got Joe"
  end
  
  it "should return an error string when it can't find the XML it is looking for and the expected value is not nil" do
    document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/joe_c32.xml'))
    patient_element = REXML::XPath.first(document, '/cda:ClinicalDocument/cda:recordTarget/cda:patientRole', {'cda' => 'urn:hl7-org:v3'})
    error = XmlHelper.match_value(patient_element, 'cda:patient/cda:foo', 'Billy')
    error.should_not be_nil
    error.should == "Expected Billy got nil"
  end
  
  it "should return nil when the expected value is nil and the expression does not match anything" do
    document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/joe_c32.xml'))
    patient_element = REXML::XPath.first(document, '/cda:ClinicalDocument/cda:recordTarget/cda:patientRole', {'cda' => 'urn:hl7-org:v3'})
    error = XmlHelper.match_value(patient_element, 'some_element_bound_not_to_be_there', nil)
    error.should be_nil
  end
  
  it "should return an error when the expected_value is nil and it matches something" do
    document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/joe_c32.xml'))
    patient_element = REXML::XPath.first(document, '/cda:ClinicalDocument/cda:recordTarget/cda:patientRole', {'cda' => 'urn:hl7-org:v3'})
    error = XmlHelper.match_value(patient_element, '/', nil)
    error.should_not be_nil
  end 
  
  it "should return be able to match boolean return values correctly" do
    document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/joe_c32.xml'))
    patient_element = REXML::XPath.first(document, '/cda:ClinicalDocument/cda:recordTarget/cda:patientRole', {'cda' => 'urn:hl7-org:v3'})
    error = XmlHelper.match_value(patient_element, 'cda:patient/cda:name/cda:given/text() = $name',true,{'cda' => 'urn:hl7-org:v3'},{ "name"=>'Joe'})
    error.should be_nil
    
    error = XmlHelper.match_value(patient_element, 'cda:patient/cda:name/cda:given/text() = $name',false,{'cda' => 'urn:hl7-org:v3'},{ "name"=>'Joe'})
    error.should_not be_nil      
  end   
  
  it "should return be able to match String return values correctly" do
    document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/joe_c32.xml'))
    patient_element = REXML::XPath.first(document, '/cda:ClinicalDocument/cda:recordTarget/cda:patientRole', {'cda' => 'urn:hl7-org:v3'})
    error = XmlHelper.match_value(patient_element, 'cda:patient/cda:name/cda:given/text() ','Joe')
    error.should be_nil
    
    error = XmlHelper.match_value(patient_element, 'cda:patient/cda:name/cda:given/text() ','Bilabo')
    error.should_not be_nil      
  end   
  
  it "should return be able to use passed in namespace info" do
    document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/joe_c32.xml'))
    patient_element = REXML::XPath.first(document, '/c32:ClinicalDocument/c32:recordTarget/c32:patientRole', {'c32' => 'urn:hl7-org:v3'})
    error = XmlHelper.match_value(patient_element, 'c32:patient/c32:name/c32:given/text() ','Joe',{'c32' => 'urn:hl7-org:v3'})
    error.should be_nil   
  end     

  describe "with dereference calls" do

    before do
      @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/c32v2.5.xml'))
    end

    it "should be able to produce a hash of dereferenced subsections" do
      references = XmlHelper.dereference('substanceAdministration', @document)
      references.keys.should == ['Augmentin', 'Aspirin']
      references.values.each { |v| 'substanceAdministration'.should == v.name }
    end

    it "should handle attempts to dereference a section without referenced content" do
      @document.elements.delete_all('//text')
      references = XmlHelper.dereference('substanceAdministration', @document)
      references.should == {}
    end

    it "should handle attempts to dereference a section without references" do
      @document.elements.delete_all('//reference')
      references = XmlHelper.dereference('substanceAdministration', @document)
      references.should == {}
    end
  end
end

# This is not supposed to be valid markup.  It provides markup
# with missing elements to test for failure points
C32_MEDICATION_WITHOUT_REFERENCES = <<-EOD
<?xml version="1.0" encoding="UTF-8"?>
<ClinicalDocument xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" moodCode="EVN" xmlns="urn:hl7-org:v3">
                        <substanceAdministration classCode="SBADM" moodCode="EVN">
                            <templateId root="2.16.840.1.113883.10.20.1.24"/>
                            <templateId root="1.3.6.1.4.1.19376.1.5.3.1.4.7"/>
                            <templateId root="1.3.6.1.4.1.19376.1.5.3.1.4.7.1"/>
                            <templateId root="2.16.840.1.113883.3.88.11.83.8"/>
                            <id root="001d6e65-e378-43c7-bda1-792e1f59302a"/>
                            <statusCode code="completed"/>
                            <effectiveTime xsi:type="IVL_TS">
                                <low value="20091207"/>
                                <high value="20091214"/>
                            </effectiveTime>
                            <doseQuantity value="1" unit="tablet"/>
                            <consumable typeCode="CSM">
                                <manufacturedProduct>
                                    <templateId root="1.3.6.1.4.1.19376.1.5.3.1.4.7.2"/>
                                    <templateId root="2.16.840.1.113883.10.20.1.53"/>
                                    <templateId root="2.16.840.1.113883.3.88.11.83.8.2"/>
                                    <manufacturedMaterial classCode="MMAT">
                                        <code code="562508" codeSystem="2.16.840.1.113883.6.88" codeSystemName="RxNorm" displayName="AMOX TR/POTASSIUM CLAVULANATE 875 mg-125 mg ORAL TABLET">
                                            <originalText>
                                                <reference value="#MedName-1"/>
                                            </originalText>
                                        </code>
                                        <name>Augmentin</name>
                                    </manufacturedMaterial>
                                </manufacturedProduct>
                            </consumable>
                            <entryRelationship typeCode="SUBJ" inversionInd="true">
                                <act classCode="ACT" moodCode="INT">
                                    <templateId root="2.16.840.1.113883.10.20.1.49"/>
                                    <templateId root="1.3.6.1.4.1.19376.1.5.3.1.4.3"/>
                                    <code code="PINSTRUCT" codeSystem="1.3.6.1.4.1.19376.1.5.3.2" codeSystemName="IHEActCode"/>
                                    <text>
                                        <reference value="#MedComment-1"/>
                                    </text>
                                    <statusCode code="completed"/>
                                </act>
                            </entryRelationship>
                        </substanceAdministration>
</ClinicalDocument>
EOD
