require 'nokogiri'
require 'laika_medical_document/importers/c32'

module LaikaMedicalDocument

  class ImportError < RuntimeError; end

  # Handles import of a medical document in a recognized xml format.
  #
  # Currently we only have an importer for C32 documents.
  #
  # The given xml is parsed and wrapped with a Patient object for conveninent
  # data access and translation into other formats (such as hashes) for import.
  class Importation

    # Import an xml document.
    #
    # * xml => may be either a String of XML data or a File or other IO
    # pointing to an XML file.
    def self.from_xml(xml)
      document = Nokogiri.parse(xml)
      case root_element_name = document.root.name
        when 'ClinicalDocument' # C32
          LaikaMedicalDocument::Importers::C32.from_xml(document)
        else
          raise(ImportError, "No importer available for an XML document with a root element: #{root_element_name}") 
      end
    end

  end

end
