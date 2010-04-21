# A format neutral in memory representation of a section of a laika medical
# document such as a Patient or Medication.  A NodeHash's attributes
# represent section data, and may include NodeArrays of other NodeHashes.
module LaikaMedicalDocument
  module Document
    class NodeHash < Hash
    
    end
  end
end
