require 'forwardable'

# A separate validation library for validating Patient data in a hash-like
# structure with an xml document.  The XML format to Hash key/value 
# relationship must be specified in a set of Descriptors (see ComponentDescriptors)
module Validators

  # Raised if the Validator itself encounters a problem in execution. 
  class ValidatorException < RuntimeError; end

  module C32Validation
    C32VALIDATOR = "C32Validator"
  
    module Actions

      def self.included(base)
        base.send(:include, InstanceMethods)
      end

      module InstanceMethods
 
        def validate_repeating_section
          raise(ValidatorException, "Cannot validate repeating section #{descriptor}.  Gold model does not appear to be an array: #{gold_model}") unless gold_model.respond_to?(:each)
          gold_model.each do |g|
            if section = descriptor.find_matching_section_for(g)
              options = {
                :section => section.key,
                :descriptor => section,
                :gold_model => g 
              }
              errors << descend(options).validate
            else
              add_no_matching_section_error(descriptor.get_section_key_hash_from(g))
            end
          end
        end

        def validate_section
          # we have a section
          descriptor.subdescriptors.each do |d|
            options = {
              :section => d.key,
              :descriptor => d,
            }
            if gm = _gold_model_matching(d)
              options.merge!(:gold_model => gm)
            end
            errors << descend(options).validate
          end
        end

        def validate_component
          validate_section
        end

        # See if the current gold_model matches the descriptor's extracted_value. 
        def match_value
          debug("match_value")
          expected_value = gold_model
          actual_value = descriptor.extracted_value
          add_comparison_error(field_name, expected_value.to_s, actual_value) unless _equal_values?(expected_value, actual_value)
        end

        private

        def _equal_values?(expected, provided)
          case expected
            when Date
              expected.to_formatted_s(:brief).eql?(provided)
            else
              expected.to_s.eql?(provided)
          end 
        end

        def _gold_model_matching(descriptor)
          gold_model.send(descriptor.key) if gold_model.respond_to?(descriptor.key)
        end

      end # module InstanceMethods
    end # module Actions

    module Routines

      private

    end

    # Holds the scope and general helper routines needed to validate a
    # C83 xml component against the values in a gold model object.
    class ComponentScope
      include Laika::AttributesHashAccessor
      include Routines
      include Actions
      include Logging

      # Symbol identifying the overarching C83 content model section
      # we are currently evaluating, such as Allergies or Medications
      attr_hash_accessor :component_module

      # Symbol used to identify the C83 section element being validated
      # in the current scope.
      attr_hash_accessor :section

      # The model of section values that we are validating the xml against.
      attr_hash_accessor :gold_model

      # A ComponentDescriptors::SectionDescriptor instance detailing the model
      # key, xpath locator and exact node or text value for the the current
      # document element in scope.
      attr_hash_accessor :descriptor

      # The root xml document object.
      attr_hash_accessor :document

      # The parent section scope, if any.
      attr_hash_accessor :enclosing_scope

      # C32 version type.
      attr_hash_accessor :validation_type

      # The Validator being used in the current validation.
      attr_hash_accessor :validator

      # The overall inspection type (content, xml, etc.)
      attr_hash_accessor :inspection_type

      # Current logger. 
      attr_hash_accessor :logger

      # Current logger color.
      attr_hash_accessor :logger_color

      extend Forwardable

      def_delegators :descriptor, :key, :locator, :field_name, :find_innermost_element, :xml 

      def initialize(options)
        self.attributes=(options)
        self.logger_color = 33 unless self.logger_color
      end

      alias :unguarded_descriptor :descriptor
      def descriptor
        return unguarded_descriptor if unguarded_descriptor
        if document
          new_descriptor = Validators::C32Descriptors.get_component(component_module)
          raise(ValidatorException, "Unable to find descriptors for component: '#{component_module}'") unless new_descriptor
          self.descriptor = new_descriptor.attach_xml(document.root) if new_descriptor
        end
      end

      # Descend into a new component scope enclosed by the current scope,
      # with scope attributes overridden as specified in the passed options.
      #
      # If a block is also given, it is executed within this newly 
      # created ComponentScope.  This is used to drill down into subsections
      # of the document.
      #
      # Returns the new scope.
      def descend(options, &block)
        debug("descending in scope from: #{self.to_s}")
        scope = ComponentScope.new(self.attributes.merge(options))
        scope.enclosing_scope = self
        debug("descended into scope : #{scope.inspect}")
        scope.instance_eval &block if block_given?
        return scope
      end

      # Accessor for the current scopes array of ValidationErrors.
      def errors
        @errors ||= []
      end

      # Add a ValidationError with the given message to the current
      # scope's errors list.  Default ValidationError arguments may be
      # overridden by passing in options in the args parameter.
      def add_validation_error(message, args = {})
        _add_error(Laika::ValidationError, {
            :message => message,
          },
          args
        )
      end

      # Add a SectionNotFound error with the given locator to the current
      # scope's error list.  Default error arguments may be overridden by
      # passing in options in the args parameter.
      def add_section_not_found_error(locator, args = {})
        _add_error(Laika::SectionNotFound, {
            :message => "Unable to find any #{section_name}.  Tried following #{locator} in the current element.",
            :locator => locator,
          },
          args
        )
      end

      # Add a NoMatchingSection error with provided and expected sections 
      # to the current scope's error list.  Default error arguments may
      # be overridden by passing in options in the args parameter.
      def add_no_matching_section_error(xpath, args = {})
        _add_error(Laika::NoMatchingSection, {
            :message => "No matching #{section_name} was found. Searched for: #{xpath}",
            :expected_section => collect_expected_values, 
            :provided_sections => collect_provided_values,
          },
          args
        )
      end

      # Add a ComparisonError with expected and provided values
      # to the current scope's error list.  Default error arguments
      # may be overridden by passing in options in the args parameter.
      def add_comparison_error(field_name, expected_value, actual_value, args = {})
        _add_error(Laika::ComparisonError, {
            :field_name => field_name,
            :subsection => section == field_name ? nil : section,
            :message    => "Expected #{ !expected_value.blank? ? expected_value.to_s : 'nil' } got #{ !actual_value.blank? ? actual_value : 'nil' }",
            :expected   => expected_value,
            :provided   => actual_value,
          },
          args
        )
      end

      # XPath pointer to find the current xml within it's parent
      # document.
      def location
        xml.xpath
      end

      # Human readable section name.
      def section_name
        section.to_s.humanize.titleize
      end

      def validate
        debug("validating: #{section}(#{xml.inspect}, #{descriptor})")
        begin

          if descriptor.kind_of?(ComponentDescriptors::Component)
            validate_component
          elsif descriptor.error?
            add_validation_error((e = descriptor.error.dup).delete(:message), e)
          elsif descriptor.required? && descriptor.extracted_value.nil?
            add_section_not_found_error(locator, (descriptor.field? ? { :field_name => field_name } : {})) if gold_model
          elsif descriptor.repeats?
            validate_repeating_section
          elsif descriptor.field?
            match_value            
          else 
            validate_section
          end
  
        rescue ValidatorException => e
          raise e # just repropagate
        rescue RuntimeError => e
          error("C32Validator failure: #{e.inspect}\n#{e.backtrace}")
          raise(ValidatorException, "C32Validator failure: #{e.inspect}", e.backtrace)

          # evil? Basically just looking to get the original trace in a more
          # specific exception type
        end
        debug("done validating: #{section}(#{xml.inspect}, #{descriptor})")
        return errors.flatten.compact
      end

      # Collect a hash of all the expected values from the current gold_model().
      def collect_expected_values
        debug("collect_expected_values: #{section}, #{gold_model.inspect}")
        descriptor.copy.attach_model(gold_model).to_field_hash
      end

      # Collect a hash of all the values in the current xml
      def collect_provided_values
        debug("collect_provided_values: #{section}, #{xml.inspect}")
        descriptor.values.map { |v| v.to_field_hash }
      end

      def inspect
        str = "<#{self.class}:#{self.object_id}\n"
        attributes.each do |k,v|
          if [:enclosing_scope].include?(k)
            str << "  #{k} => #{v}\n"
          else
            str << "  #{k} => #{v.inspect}\n"
          end
        end
        str << ">"
        return str
      end

      private

      def _location_by_error_type(klass)
        debug("_location_by_error_type for #{klass}")
        case 
          when klass == Laika::SectionNotFound
            find_innermost_element.try(:xpath)
          when klass == Laika::NoMatchingSection
            xml.first.try(:xpath)
          when klass == Laika::ComparisonError
            find_innermost_element.try(:xpath)
          else
            location
        end
      end

      def _error_defaults(klass)
        {
          :section => component_module,
          :subsection => section == component_module ? nil : section,
          :severity => :error,
          :location => _location_by_error_type(klass),
          :validator => validator,
          :inspection_type => inspection_type,
        }
      end

      def _add_error(klass, args, overrides)
        final_args = _error_defaults(klass).merge(args).merge(overrides)
        debug("_add_error: #{klass}, #{final_args.inspect}")
        errors << klass.new(final_args)
      end

    end

    # This is the validation engine for content inspection.
    #
    # Validators::C32Validation::Validator.new.validate(patient, document)
    #
    class Validator < Validation::BaseValidator
  
      include Logging

      def validate(patient, document)
        self.logger = patient.logger if logger.nil?
        self.logger_color = 33
        debug("#{self.class}.validate()\n  -> patient: #{patient}\n  -> document: #{document.inspect}")
        errors = Patient.c32_modules.each.map do |component_module, association_key|
          gold_model = patient.send(association_key)

          # temporary test for whether we have any directives set up for this component module
          next unless descriptor = Validators::C32Descriptors.get_component(component_module)

          debug("Validating component: #{component_module}, association_key: #{association_key}")
          descriptor.attach_xml(document.root)
          debug("descriptor: #{descriptor.inspect}")
          debug("gold_model: #{gold_model}")

          unless gold_model.nil? || gold_model.empty?
            ComponentScope.new(
              :component_module => component_module,
              :section          => component_module,
              :gold_model       => gold_model,
              :document         => document,
              :descriptor       => descriptor,
              :validation_type  => validation_type,
              :logger           => logger,
              :logger_color     => 33,
              :validator        => C32VALIDATOR,
              :inspection_type  => ::CONTENT_INSPECTION
            ).validate
          end

        end.flatten!.compact!
      end

    end

  end

end
