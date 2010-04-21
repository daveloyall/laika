require 'spec_helper'
require 'laika_medical_document/document/node_hash'

module LaikaMedicalDocument
  module Document
    describe NodeHash do
    
      it "should instantiate" do
        node = NodeHash.new
        node.should_not be_nil
      end
    
    end
  end
end
