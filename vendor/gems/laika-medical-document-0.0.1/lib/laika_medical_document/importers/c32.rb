require 'laika_medical_document/importers/c32/patient'

module LaikaMedicalDocument
  module Importers

    # Handles import of C32 xml documents.
    #
    # LaikaMedicalDocument::Importers::C32.from_xml(nokogiri_document)
    #  => LaikaMedicalDocument::Importers::C32::Patient wrapped around the
    #     Document's root node.
    # 
    # See LaikaMedicalDocument::Importation.from_xml for a more general import
    # method that will handle Strings or Files.
    module C32

      def self.from_xml(document)
        LaikaMedicalDocument::Importers::C32::Patient.new(document.root)
      end

    end

change from c32 module to c32 class >>

    class C32
     
      attr :document, :root_section

      delegate :root_section 

      def initialize(document)
        @document = document
        @root_section = LaikaMedicalDocument::Importers::C32::Section.new(document.root) 
      end

    end
  end
end
