require 'laika_medical_document/document/node_hash'

module LaikaMedicalDocument
  module Document
    class PatientNode < NodeHash

      node_accessor  :name
      node_accessor  :pregnant
      node_accessor  :no_known_allergies

    end
  end
end
