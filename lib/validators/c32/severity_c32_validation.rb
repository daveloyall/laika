module SeverityTermC32Validation

   include MatchHelper

   def validate_c32(severity_element)
     errors = []
     severity_text = REXML::XPath.first(severity_element,"cda:text",MatchHelper::DEFAULT_NAMESPACES)
     if severity_text
       derefed_text = deref(severity_text)
       if derefed_text != self.name
         errors << Laika::ComparisonError.new(
           :section => "Allergies", :subsection => "SeverityTerm",
           :message => "Severity term #{self.name} does not match #{derefed_text}",
           :expected => self.name,
           :provided => derefed_text,
           :location => severity_text.xpath
         )
       end
     else
       errors << Laika::ValidationError.new(
         :section => "Allergies", :subsection => "SeverityTerm",
         :message => "Unable to find severity term text",
         :location => severity_element.xpath
       )
     end
     errors << match_value(severity_element, 'cda:value/@code', 'code', self.code)
     errors.compact
   end

   def section_name
     'allergies'
   end

   def subsection_name
     'severity'
   end

end
