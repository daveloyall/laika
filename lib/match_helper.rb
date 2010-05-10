# Module to be included into models who do matching against clinical documents
# The match value function will pull the section and subsection names from
# the methods section_name and subsection_name. By default, section_name
# will return the underscore name of the class. Subsection will return nil.
# To change this behavior, reimplement section_name or subsection_name in
# the model class.
module MatchHelper
  DEFAULT_NAMESPACES = {"cda"=>"urn:hl7-org:v3", "sdtc"=>"urn:hl7-org:sdtc"}

  def self.included(base)
    base.class_eval do
      def match_value(an_element, xpath, field, value)
        error = XmlHelper.match_value(an_element, xpath, value)
        error.update_attributes(
            :section => section_name,
            :subsection => subsection_name,
            :field_name => field
        ) if error
        return error
      end
  
      def safe_match(element,&block)
         if element
               yield(element) 
               return nil
         else
             return Laika::ValidationError.new(:section => section_name, 
                                     :message => 'Null value supplied for matching',
                                     :severity=>'error',
                                     :location =>nil)             
         end
      end    
  
      def match_required(element,xpath,namespaces,xpath_variables,subsection,error_message,error_location=nil,&block)
        content = REXML::XPath.first(element,xpath,namespaces,xpath_variables ) if element
        if content
          yield(content) if block_given?
          return nil
        else
            return Laika::ValidationError.new(:section => section_name, 
                                    :message => error_message,
                                    :severity => 'error',
                                    :location => error_location)
        end
      end

      def content_required(content,subsection,error_message,error_location=nil,&block)

        if content
          yield(content) if block_given?
          return nil
        else
          return Laika::ValidationError.new(:section =>section_name,
                                  :message => error_message,
                                  :severity=>'error',
                                  :location => error_location)
        end
      end


      def section_name
        self.class.name
      end

      def subsection_name
        nil
      end


      def deref(code)
        if code
          ref = REXML::XPath.first(code,"cda:reference",MatchHelper::DEFAULT_NAMESPACES)
          if ref
            REXML::XPath.first(code.document,"//cda:content[@ID=$id]/text()",MatchHelper::DEFAULT_NAMESPACES,{"id"=>ref.attributes['value'].gsub("#",'')})
          else
            nil
          end
        end
      end
    end
  end
end
