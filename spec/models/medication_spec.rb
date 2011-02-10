require File.dirname(__FILE__) + '/../spec_helper'

describe Medication, 'it can validate medication elements in a C32' do
  fixtures :medications, :code_systems, :medication_types

  it "should verify a medication in a C32 doc version 2.3" do
    document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/medications/jenny_medication.xml'))
    med = medications(:jennifer_thompson_medication)
    errors = med.validate_c32(document, :validation_type => Validation::C32_V2_1_2_3_TYPE)
    errors.should be_empty
  end

  it "should verify a medication in a C32 doc version 2.5" do
    document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/medications/jenny_medication_2.5.xml'))
    med = medications(:jennifer_thompson_medication)
    med.quantity_ordered_value = 15.0
    errors = med.validate_c32(document, :validation_type => Validation::C32_V2_5_C83_V2_0_TYPE)
    errors.size.should == 1
    errors.first.message.should == "Expected 15.0 got 30.0"
    med.quantity_ordered_value = 30.0
    errors = med.validate_c32(document, :validation_type => Validation::C32_V2_5_C83_V2_0_TYPE)
    errors.should be_empty
  end
end

describe Medication, "can create a C32 representation of itself" do
  fixtures :medications, :code_systems, :medication_types

  it "should create valid C32 content" do
    med = medications(:jennifer_thompson_medication)
    
    document = LaikaSpecHelper.build_c32 do |xml|
      xml.component do
        xml.structuredBody do
           xml.component {
             xml.section {
               xml.templateId("root" => "2.16.840.1.113883.10.20.1.8", 
                              "assigningAuthorityName" => "CCD")
               xml.code("code" => "10160-0", 
                        "displayName" => "History of medication use", 
                        "codeSystem" => "2.16.840.1.113883.6.1", 
                        "codeSystemName" => "LOINC")
               xml.title "Medications"
               xml.text {
                   xml.content(med.product_coded_display_name, "ID" => "medication-"+med.id.to_s)
               }

               # Start structured XML
               med.to_c32(xml)
               # End structured XML
             }
           }
        end
      end
    end
    errors = med.validate_c32(document.root)
    puts errors.inspect if !errors.empty?
    errors.should be_empty
  end
end
