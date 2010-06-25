require 'method_cache'
require 'laika_medical_document/node_methods'

module LaikaMedicalDocument
  module Importers
    module C32

      # Base class for all C32 section objects.
      class Base
        include MethodCache
        include LaikaMedicalDocument::NodeMethods

        def initialize(node)
          @node = node
        end

        def namespaces
          {'cda' => 'urn:hl7-org:v3'}
        end
      end
  
    end
  end
end
