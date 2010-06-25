module MethodCache

  # Ensures that code is executed once and cached in the given attribute:
  #
  # _method_cache(:foo) do
  #   something_expensive()
  # end
  #  => @foo
  def _method_cache(attribute_name)
    attribute_name = "@#{attribute_name}"
    unless attribute = send(:instance_variable_get, attribute_name)
      attribute = send(:instance_variable_set, attribute_name, yield)
    end 
    return attribute
  end

end
