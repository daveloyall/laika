require 'forwardable'

# A separate validation library for validating Patient data in a
# model/attribute or hash-like structure with an xml document.  The XML format
# to model relationship must be specified in a set of Descriptors (see
# ComponentDescriptors)
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
          debug("validate_repeating_section: #{current_reference_descriptor}")
          current_reference_descriptor.each do |section_key,reference_descriptor|
            if document_descriptor = current_document_descriptor[section_key]
              options = {
                :key => document_descriptor.index_key,
                :current_reference_descriptor => reference_descriptor,
                :current_document_descriptor => document_descriptor,
              }
              errors << descend(options).validate
            else
              add_no_matching_section_error(reference_descriptor.section_key_hash)
            end
          end
        end

        def validate_section
          debug("validate_section: #{current_reference_descriptor}")
          # we have a section
          current_reference_descriptor.subdescriptors.each do |d|
            options = {
              :key => d.index_key,
              :current_reference_descriptor => d,
            }
#            if rm = _reference_model_matching(d)
#              options.merge!(:reference_model => rm)
#            end
            errors << descend(options).validate
          end
        end

        # See if the current_reference_descriptor and current_document_descriptor's
        # extracted_values match.
        def match_value
          debug("match_value for #{current_reference_descriptor}")
          expected_value = model_value 
          actual_value = xml_value
          add_comparison_error(field_name, expected_value.to_s, actual_value) unless expected_value == actual_value
        end

      end # module InstanceMethods
    end # module Actions

    # Holds the scope and general helper routines needed to validate a
    # C83 xml component against the values in a reference model object.
    class ComponentScope
      include Laika::AttributesHashAccessor
      include Actions
      include Logging

      # Symbol identifying the overarching C83 content model section
      # we are currently evaluating, such as Allergies or Medications.
      # This establishes the set of Descriptors we will be using for
      # validation.
      attr_hash_accessor :component_module

      # Symbol identifies the exact descriptor under evaluation in the
      # the current scope.  Defaults to component_module().
      attr_hash_accessor :key

      # The base model that we are validating the xml against.
      attr_hash_accessor :reference_model

      # The root xml document object.
      attr_hash_accessor :document

      # The tree of unattached ComponentDescriptors for component_module().
      # Used to seed reference and document_descriptors.
      attr_hash_accessor :component_descriptors

      # Copy of component_descriptors() with reference_model() attached.
      attr_hash_accessor :reference_descriptors

      # Copy of component_descriptors() with document() attached.
      attr_hash_accessor :document_descriptors

      # The current reference_descriptors element we are evaluating in this
      # scope.  This should be the key() descriptor from
      # reference_descriptors().
      attr_hash_accessor :current_reference_descriptor

      # The current document_descriptors element we are validating against
      # in this scope.  This should be the key() descriptor from
      # document_descriptors().  May be nil.
      attr_hash_accessor :current_document_descriptor

      # The parent ComponentScope, if any.
      # TODO - deprecate?  Only useful for tracing?
      attr_hash_accessor :enclosing_scope

      # C32 version type.
      attr_hash_accessor :validation_type

      # The Validator being used in the current validation.
      attr_hash_accessor :validator

      # The overall inspection type (content, xml, etc.).
      attr_hash_accessor :inspection_type

      # Current logger. 
      attr_hash_accessor :logger

      # Current logger color.
      attr_hash_accessor :logger_color

      # These attributes will not be included when descending into a lower scope.
      LOCAL_ATTRIBUTES = [:key, :current_document_descriptor, :current_reference_descriptor, :enclosing_scope]

      extend Forwardable

      def_delegators :current_reference_descriptor, :section_key, :field_name, :model_has_section?
      def_delegators :current_document_descriptor, :locator, :find_innermost_element, :xml 

      def initialize(options)
        self.attributes=(options)
        self.logger_color = 33 unless self.logger_color
      end

      # Class methods
      class << self

        # Ensures that the attribute will lazily initialize with &block if necessary.
        def default_to(attribute, &default_block)
          class_eval do
            alias_method "unguarded_#{attribute}", attribute
            define_method(attribute) do
              value = send("unguarded_#{attribute}")
              return value if value
              send("#{attribute}=", instance_eval(&default_block)) 
            end
          end
        end
    
        # Handles "default_<attribute>_to" {...} => default_to(attribute, &block) translation
        def method_missing(method, *args, &block)
          if method.to_s =~ /^default_(.+)_to$/
            return default_to($1, *args, &block)
          end
          super
        end
      end

      default_key_to { component_module }

      default_component_descriptors_to do
        new_descriptor = Validators::C32Descriptors.get_component(component_module, :validation_type => validation_type, :logger => logger)
        raise(ValidatorException, "Unable to find descriptors for component: '#{component_module}'") unless new_descriptor
        new_descriptor
      end

      default_reference_descriptors_to do
        raise(ValidatorException, "Unable to set reference descriptors -- no reference_model set.") unless reference_model
        attached = component_descriptors.copy
        attached.model = reference_model
        attached
      end

      default_document_descriptors_to do
        raise(ValidatorException, "Unable to set document descriptors -- no document set.") unless document 
        attached = component_descriptors.copy
        attached.xml = document
        attached
      end
 
      default_current_reference_descriptor_to do
        reference_descriptors.find(key)
      end

      default_current_document_descriptor_to do
        document_descriptors.find(key)
      end

      def clear
        errors.clear
        [:component_descriptors, :reference_descriptors, :document_descriptors, :current_reference_descriptor, :current_document_descriptor].each { |m| send("#{m}=", nil) }
      end

      # Descend into a new component scope enclosed by the current scope,
      # with scope attributes overridden as specified in the passed options.
      #
      # Must at least pass a new descriptor :key in the options hash.
      #
      # Returns the new scope.
      def descend(options)
        debug("descending in scope from: #{self.to_s}")
        raise(ValidatorException, "Must provide a key value for the new scope.") unless options.include?(:key)
        # we don't want to accidentally hand off the current scopes local attributes
        # like :key or :current_reference_descriptor
        global_attributes = self.attributes.dup
        LOCAL_ATTRIBUTES.each { |k| global_attributes.delete(k) }
        scope = ComponentScope.new(global_attributes.merge(options))
        scope.enclosing_scope = self
        debug("descended into scope : #{scope.inspect}")
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
            :message => "No matching #{section_name} was found. Searched for: #{xpath.inspect}",
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
            :subsection => section_key == field_name ? nil : section_key,
            :message    => "Expected #{ !expected_value.blank? ? expected_value.to_s : 'nil' } got #{ !actual_value.blank? ? actual_value : 'nil' }",
            :expected   => expected_value,
            :provided   => actual_value,
          },
          args
        )
      end

      # XPath pointer to find the current xml within its parent
      # document.
      def location
        xml.xpath
      end

      # Human readable section name.
      def section_name
        section_key.to_s.humanize.titleize
      end

      # Value extracted by the current Descriptor from the document.
      def xml_value
        current_document_descriptor.extracted_value
      end

      # Value extracted by the current Descriptor from the model.
      def model_value
        current_reference_descriptor.extracted_value
      end

      # True if xml was found using the locators in the current_document_descriptor.
      def xml_located?
        xml_located = !xml_value.nil?
        xml_located &&= !xml_value.empty? if xml_value.respond_to?(:empty?)
        xml_located
      end

      # True if reference_model has a separate section for the current
      # descriptor, and this section has been left nil.  A model does not have
      # to provide an accessor for every section, just for fields.  This
      # test may be used to decide whether or not we are validating the
      # current section.  The default is to skip validation if it has been
      # left blank in the reference model.
      def model_section_nil?
        model_has_section? && model_value.nil?
      end

      def validate
        debug("validating: #{key} -> #{current_reference_descriptor}")
        raise(ValidatorException, "Reference and document descriptors are out of sync.\ncurrent_reference_descriptor: #{current_reference_descriptor.pretty_inspect}\ncurrent_document_descriptor: #{current_document_descriptor}") if current_reference_descriptor.index_key != current_document_descriptor.index_key
        begin

          if current_document_descriptor.error?
            add_validation_error((e = current_document_descriptor.error.dup).delete(:message), e)
          elsif xml_located?
            if current_reference_descriptor.repeats?
              validate_repeating_section
            elsif current_reference_descriptor.field?
              match_value unless model_value.nil?
            else 
              validate_section
            end
          elsif current_reference_descriptor.required?
            add_section_not_found_error(locator, (current_reference_descriptor.field? ? { :field_name => field_name } : {})) unless model_section_nil? 
          end

        rescue ValidatorException => e
          raise e # just repropagate
        rescue RuntimeError => e
          error("C32Validator failure: #{e.inspect}\n#{e.backtrace}")
          raise(ValidatorException, "C32Validator failure: #{e.inspect}", e.backtrace)

          # evil? Basically just looking to get the original trace in a more
          # specific exception type
        end
        debug("done validating: #{key}")
        return errors.flatten.compact
      end

      # Collect a hash of all the expected values from the current reference_model().
      def collect_expected_values
        debug("collect_expected_values: #{key}, #{current_reference_descriptor}")
        current_reference_descriptor.to_field_hash
#        attached = descriptor.copy.model = reference_model
#        attached.to_field_hash
      end

      # Collect a hash of all the values in the current xml
      def collect_provided_values
        debug("collect_provided_values: #{key}, #{current_document_descriptor}")
        current_document_descriptor.values.map { |v| v.to_field_hash }
      end

      def inspect
        str = "<#{self.class}:#{self.object_id}\n"
        attributes.each do |k,v|
          if [:enclosing_scope,:component_descriptors,:document_descriptors,:reference_descriptors,:current_document_descriptor,:current_reference_descriptor].include?(k)
            str << "  #{k} => #{v}\n"
#          elsif v.respond_to?(:pretty_inspect)
#            str << "  #{k} => #{v.pretty_inspect}\n"
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
            # Location to the first of the available sections
            xml_value.first.try(:xpath) || location
          when klass == Laika::ComparisonError
            find_innermost_element.try(:xpath)
          else
            location
        end
      end

      def _error_defaults(klass)
        {
          :section => component_module,
          :subsection => section_key == component_module ? nil : section_key,
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
        debug("validate()\n  -> patient: #{patient}\n  -> document: #{document.inspect}")
        errors = Patient.c32_modules.each.map do |component_module, association_key|
          reference_model = patient.send(association_key)

          # temporary test for whether we have any descriptors set up for this component module
          next unless Validators::C32Descriptors.descriptors.key?(component_module)
          # remove or raise an exception perhaps once all components described

          debug("Validating component: #{component_module}, association_key: #{association_key}")
          debug("reference_model: #{reference_model}")

          unless reference_model.nil? || reference_model.respond_to?(:empty?) ? reference_model.empty? : false
            Validator.validate_component( 
              :component_module => component_module,
              :reference_model  => reference_model,
              :document         => document,
              :validation_type  => validation_type,
              :logger           => logger
            )
          end

        end.flatten!.compact!
      end

      # Utility method for validating a component module.
      # 
      # The options hash must include the following:
      # * :component_module
      # * :reference_model
      # * :document
      # * :validation_type
      def self.validate_component(options)
        local_options = options.dup
        unless local_options.key?(:logger)
          reference_model = local_options[:reference_model]
          local_options[:logger] = reference_model.try(:logger) if reference_model.respond_to?(:logger)
        end
        default_options = {
          :logger_color     => 33,
          :validator        => C32VALIDATOR,
          :inspection_type  => ::CONTENT_INSPECTION
        }
        ComponentScope.new(default_options.merge(local_options)).validate
      end

    end

  end

end
