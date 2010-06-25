require 'spec_helper'
require 'laika_medical_document/importation'

module LaikaMedicalDocument
  describe Importation do
    
    it "should respond to from_xml" do
      LaikaMedicalDocument::Importation.should respond_to :from_xml 
    end

  end
end
