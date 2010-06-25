require 'laika_medical_document/section'
require 'LaikaMedicalDocument/importers/c32/section_definitions'

module LaikaMedicalDocument
  module Importers
    module C32

      # Base class for all C32 section objects.
      class Section < LaikaMedicalDocument::Section
        include SectionDefinitions

        def namespaces
          {'cda' => 'urn:hl7-org:v3'}
        end
      end
  
    end
  end
end
