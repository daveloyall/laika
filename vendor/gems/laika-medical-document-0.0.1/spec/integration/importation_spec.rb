require 'spec_helper'
require 'laika_medical_document/importation'

module LaikaMedicalDocument
  describe Importation do

    it "should import a C32 document from String" do
      c32_xml = get_test_file('c32/joe_c32.xml')
      imported = LaikaMedicalDocument::Importation.from_xml(c32_xml)
      puts imported.inspect
      imported.should be_kind_of(Hash) 
    end

    it "should import a C32 document from a File"

  end
end    
