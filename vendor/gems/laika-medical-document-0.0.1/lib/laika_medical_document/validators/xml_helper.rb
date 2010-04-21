module XmlHelper
  # This method first checks expected_value. If it is nil, it does nothing
  # and returns nil.
  #
  # Otherwise, it will use the expression to a node to evaluate. It will use the
  # first node it finds. It will then try to match the expected_value to the returned
  # node. If the node is an Element, it will call text. If it is an attribute
  # it will call value.
  # Nil will be returned if the values match.
  # If the values do not match, or if the node cannot be found, and error
  # string will be returned.
  def self.match_value(element, expression, expected, namespaces={'cda' => 'urn:hl7-org:v3'},bind_variables = {}, format=:small)
    error = nil
     expected_value = (expected.kind_of?(Numeric)) ? expected.to_s : expected
      desired_node = REXML::XPath.first(element, expression, namespaces,bind_variables)
     
        actual_value = nil
        
        if desired_node.kind_of?(String) ||
           desired_node.kind_of?(TrueClass)||
           desired_node.kind_of?(FalseClass) ||
           desired_node.kind_of?(NilClass)
           actual_value = desired_node           
        elsif desired_node.respond_to?(:text)
          actual_value = desired_node.text
        else
          actual_value = desired_node.value
        end
        
        unless expected_value.eql?(actual_value)
       
          error = "Expected #{(expected_value)? expected_value.to_s : 'nil'} got #{(actual_value) ? actual_value : 'nil'}"
          if format == :long
	          error += "\nElement: #{element.xpath}\n"
	          error += "XPath Expression: #{expression}\n"
	          error += "Bind Varibales: #{bind_variables.collect{|key,value| "#{key} = #{value}"}}"
	       end
        end    
    error
  end
 
  # Extracts all the given sections from a passed REXML doc and return them as a hash
  # keyed by an internal reference@value
  #
  # For example, if the section is substanceAdministration, this will produce a hash of
  # all the medication component's substanceAdministration element's keyed by their own
  # consumable/manufacturedProduct/manufacturedMaterial/code/reference@value's (which 
  # should key to the medication names in the free text table for a v2.5 C32 doc...
  def self.dereference(section_name, document)
    reference_hash = {}
    REXML::XPath.each(document,"//cda:#{section_name}", MatchHelper::DEFAULT_NAMESPACES) do |section|
      if (reference = REXML::XPath.first(section, './/cda:reference[@value]', MatchHelper::DEFAULT_NAMESPACES))
        if (name = REXML::XPath.first(document,"//[@ID=$id]/text()", MatchHelper::DEFAULT_NAMESPACES, {"id"=>reference.attributes['value'].gsub("#",'')}))
          reference_hash[name.value] = section
        end
      end
    end
    return reference_hash
  end
end
