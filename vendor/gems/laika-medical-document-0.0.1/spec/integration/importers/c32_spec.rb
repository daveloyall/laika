require 'spec_helper'
require 'laika_medical_document/importers/c32'

module LaikaMedicalDocument
  module Importers

    describe C32 do

      it "should import via from_xml class method" do
        document = get_test_file_as_nokogiri_document('c32/joe_c32.xml')
        imported = LaikaMedicalDocument::Importers::C32.from_xml(document)
      end

    end

  end
end
