require 'spec_helper'
require 'laika_medical_document/document/node_hash'

module LaikaMedicalDocument
  module Document
    describe NodeHash do
    
      it "should instantiate" do
        node = NodeHash.new
        node.should be_kind_of(Hash)
      end
    
    end
  end
end
