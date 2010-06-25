require 'method_cache'
require 'laika_medical_document/node_methods'

# A Section is an abstract class representing a section of a medical document
# such as 'Registration Information' or a 'Medication' section.  It is tied
# to a physical node of the document from which it searches out whatever
# content is going to be used.
class Section
  include MethodCache
  include NodeMethods

  attr :node

  def initialize(node)
    @node = node
  end
end
