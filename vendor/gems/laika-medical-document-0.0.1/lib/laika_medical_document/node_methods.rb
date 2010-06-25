module LaikaMedicalDocument

  # Helper methods for objects which need to manipulate a Nokogiri node.
  #
  # Inclusion creates a reader for the attribute @node and extends
  # ClassMethods.
  module NodeMethods

    def self.included(base)
      base.send(:attr, :node)
    end
   
    # Returns the set of Nokogiri nodes found by applying the passed 
    # xpath expressions to @node, using self.namespaces().
    def xpath(*paths)
      node.xpath(*(paths << namespaces))
    end

    # Returns the text of the first element to match the given xpaths or
    # nil if nothing matches.
    def first_text(*paths)
      (first_node = xpath(*paths).first).nil? ? nil : first_node.text
    end

    # Returns an empty hash by default.
    # Overwrite namespaces() in your including class if you intend to
    # use namespaces in your xpath expressions.
    #
    # Example:
    #
    # { :foo => 'urn:foo.org/schema' }
    def namespaces
      {}
    end

end 
