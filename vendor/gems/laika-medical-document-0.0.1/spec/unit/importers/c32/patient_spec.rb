require 'spec_helper'
require 'laika_medical_document/importers/c32/patient'

module LaikaMedicalDocument
  module Importers
    module C32

      describe Patient do
        before do
          @document = get_test_file_as_nokogiri_document('c32/joe_c32.xml')
          @patient = Patient.new(@document.root)
        end
        
        it "should extract the correct name" do 
          @patient.name.should == "Joe Smith"
        end
  
        it "should extract registration information" do
          @patient.registration_information.should_not be_nil
        end
        
        it "should import non-empty C32 modules" do
          @patient.conditions.should_not be_empty
          @patient.medications.should_not be_empty
        end
        
        it "should not fail on missing modules" do
          @patient.results.should be_empty
        end
        
      end

    end
  end
end
