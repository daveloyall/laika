require 'spec_helper'
require 'laika_medical_document/document/patient_node'

module LaikaMedicalDocument
  module Document
    describe PatientNode do

      it "should instantiate" do
        node = PatientNode.new
        node.should be_kind_of(NodeHash)
      end

    end
  end
end    
