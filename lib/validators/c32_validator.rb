require 'forwardable'

# Initial cut at separating the C32 validation routines form the models.  All
# this currently does is to reinject the models with the validation classes.
# The C32Validator then just calls the validate 32 method on the pateint data
# object
module Validators

  # Raised if the Validator itself encounters a problem in execution. 
  class ValidatorException < RuntimeError; end

  # Raised if a C83 component section has not been defined in the
  # SECTION_DIRECTIVES_MAP yet.
#  class SectionDirectiveException < ValidatorException; end
 
  module C32Validation
    C32VALIDATOR = "C32Validator"
  
    module DirectiveMap
      extend Forwardable

      def_delegators :descriptor, :key, :locator, :template_id, :field_name, :find_innermost_element

#      [:action, :locator, :template_id, :matches, :subsection_type].each do |m|
#        define_method(m) do |*args|
#          section_key = args.shift || self.section
#          section_directives_map_entry(section_key)[m]
#        end
#      end
#
#      def field_name(section_key = section)
#        field = section_directives_map_entry(section_key)[:field_name]
#        field ||= (matches(section_key).nil? ? nil : matches(section_key).to_s)
#        field ||= section_key.to_s
#        return field
#      end
#
#      [[:keys, Hash], [:subsections, Array]].each do |m,default_class|
#        define_method(m) do |*args|
#          section_key = args.shift || self.section
#          section_directives_map_entry(section_key)[m] || default_class.new
#        end
#      end

    end

    # Any action may also be called with the extension _if_exists_in_model.  This
    # will perform the action, but only if the gold_model() has a non-nil value for
    # the matches() field. So:
    #
    # :get_section_if_exists_in_model
    #
    # is just like calling the :get_section action, but it only fires if the
    # evaluation of gold_model and the matches expression is non-nil.
    #
    # = Telecom
    #
    # In order to match a telecom field you must indicate the use type.  The
    # actions for this are:
    #
    # * match_telecom_as_hp => home phone
    # * match_telecom_as_wp => work phone
    # * match_telecom_as_mc => mobile phone
    # * match_telecom_as_hv => vacation home phone
    # * match_telecom_as_email => email
    #
    module Actions

      def self.included(base)
        base.send(:include, InstanceMethods)
        base.alias_method_chain :method_missing, :actions
      end

      module InstanceMethods
        # Lookup all the xml sections matching the given locator.  If any are
        # found descend into a new ComponentScope of subsection_type() once for
        # each gold_model_array() member so that it can attempt to match
        # against them.
        #
        # If no sections were found a SectionNotFound error is generated.
        def validate_sections(section_key = section, dereference = false)
          logger.debug("validate_sections: #{section_key}") unless dereference
          _get_sections(section_key) do |nodes|
            gold_model_array.each do |gold|
              options =  {
                :section => subsection_type(section_key),
                :gold_model_array => nil,
                :gold_model => gold,
                :xml_section_nodes => nodes,
              }
              options[:xml_sections_hash] = dereference(section_key, nodes) if dereference
              errors << descend(options).validate
            end
          end
        end

        # validate_sections() but set xml_sections_hash() with dereferenced
        # pointers from external freetext.  This allows us to identify sections
        # matching a particular gold_model when the section cannot be
        # identified by an internal xpath.  See match_dereferenced_section
        # for details.
        def validate_dereferenced_sections(section_key = section)
          logger.debug("validate_dereferenced_sections: #{section_key}")
          validate_sections(section_key, true)
        end
 
        # Lookup all the xml sections matching the given locator.  Then descend
        # into the subsections() for the current gold_model() object.  Xml sections
        # are stored the in xml_section_nodes().
        #
        # If no sections were found a SectionNotFound error is generated.
        def get_sections(section_key = section)
          logger.debug("get_sections: #{section_key}")
          _get_sections(section_key) do |nodes|
            _descend_into_subsections(section_key, nodes)
          end
        end

        # Attempt to find the matching section from xml_section_nodes() or
        # xml_sections_hash() based on a locator keyed from the current
        # gold_model().  If it is found, and a block is given, we will yield to
        # it.
        #
        # If subsections have been designated, we will descend into each 
        # subsection.
        #
        # Otherwise if no node is matched, a NoMatchingSection error, with
        # details regarding the expected and the provided sections, will be added
        # to the list.  These errors are reviewable because they may be due to
        # differences in human interpretation of codes (different encodings for
        # equivalent drugs, for instance).
        def match_section(section_key = section)
          logger.debug("match_section: #{section_key}")
          locator = xpath(section_key) || gold_model.send(keys.keys.first)
          if node = match_in_nodes(locator) || match_from_hash(locator) # try each xml_section_nodes node in sequence until we get a match
            logger.debug("node is: #{node.inspect}")
            errors << yield(node) if block_given?
            _descend_into_subsections(section_key, node)
          else
            add_no_matching_section_error(locator)
          end
          return errors
        end

        # Lookup a section absolutely.  If it is found, and a block is given,
        # we will yield to it.
        #
        # If subsections have been designated, we will descend into each
        # subsection.
        #
        # Otherwise a SectionNotFound error is generated. 
        def get_section(section_key = section, must_exist = true)
          logger.debug("get_section: #{section_key}")
          locator = xpath(section_key)
          if node = extract_first_node(locator)
            errors << yield(node) if block_given?
            _descend_into_subsections(section_key, node)
          else
            add_section_not_found_error(locator) if must_exist
          end
          return errors
        end

        # Lookup a section absolutely and act on it just like get_section(), except that
        # if no section is found, no error is entered.
        def get_section_if_exists(section_key = section)
          get_section(section_key, false)
        end
 
        # See if the current gold_model matches the descriptor's extracted_value. 
        def match_value
          logger.debug("match_value")
          expected_value = gold_model
          actual_value = descriptor.extracted_value
          add_comparison_error(field_name, expected_value.to_s, actual_value) unless _equal_values?(expected_value, actual_value)
        end

        # Handles: <action>_if_exists_in_model and match_telecom<_as_use_code>
        def method_missing_with_actions(method_id, *args)
          case method_id.to_s
            when /(.+)_if_exists_in_model/
              send($1, *args) unless gold_expected_value(*args).nil?
            when /telecom_as_(.+)/
              send(:_match_telecom, $1.to_sym, *args)
            else
              method_missing_without_actions(method_id, *args)
          end
        end
  
        private

        def _get_sections(section_key = section)
          locator = xpath(section_key)
          unless (nodes = extract_all_nodes(locator)).empty?
            yield(nodes)
          else
            add_section_not_found_error(locator)
          end
        end

        def _equal_values?(expected, provided)
          case expected
            when Date
              expected.to_formatted_s(:brief).eql?(provided)
            else
              expected.to_s.eql?(provided)
          end 
        end

        # Tries to find a single telecom value in a list of telecoms.
        # Will return nil and do nothing if desired_value is nil.
        # Will return nil if it finds a matching telecom element
        # Will return a ValidationError if it can't find a matching telecom value or
        # if there is a mismatch in the use attributes
        #
        # The :use argument should be one of the following symbols:
        # * :hp    => home phone
        # * :wp    => work phone
        # * :mc    => mobile phone
        # * :hv    => vacation home phone
        # * :email => email
        def _match_telecom(use, section_key = section)
          desired_value = gold_expected_value(section_key)
          unless desired_value.nil?
            stripped_desired_value = desired_value.gsub(/[-\(\)s]/, '')
            possible_use_attribute = nil
            if use == :email 
              stripped_desired_value = 'mailto:' + stripped_desired_value
            else
              stripped_desired_value = 'tel:' + stripped_desired_value
              possible_use_attribute = use.to_s.upcase
            end
            xml_section_nodes.each do |telecom_element|
              stripped_telecom_value = telecom_element.attributes['value'].gsub(/[-\(\)s]/, '')
              if stripped_desired_value.eql? stripped_telecom_value
                if provided_telecom_use = telecom_element.attributes['use']
                  if provided_telecom_use.eql? possible_use_attribute
                    # Found the correct value and use
                    return nil
                  else
                    # Mismatch in the use attribute
                    add_comparison_error(field_name(section_key), possible_use_attribute, provided_telecom_use, :location => telecom_element.xpath)
                    return nil
                  end
                else
                  # no use attribute... assume we have a match... the C32 isn't real clear on
                  # how to treat these
                  return nil
                end
              end
            end
  
            # Fell through... couldn't find a match, so return an error
            add_no_matching_section_error(locator,
              :message => "Couldn't find the telecom for #{use.to_s.upcase}",
              :expected_section => { :use => use.to_s.upcase, :value => desired_value },
              :provided_sections => xml_section_nodes.map do |t| {
                  :use => t.attributes['use'],
                  :value => t.attributes['value'],
                }
              end 
            )
#              :message => "Couldn't find the telecom for #{desired_value}"
          end
        end

      end # module InstanceMethods
    end # module Actions

    module Routines

      include DirectiveMap

      # Lookup the matching xpath from SECTION_DIRECTIVE_MAP and ensure that
      # any keys are evaluated.
      def xpath(section_key = section)
        xpath = locator(section_key)
        unless xpath 
          template_id = template_id(section_key)
          xpath = "//cda:section[./cda:templateId[@root = '#{template_id}']]" if template_id
        else
          keys(section_key).each_key do |k|
            xpath = xpath.gsub(%r|\$\{#{k}}|, gold_model.send(k))
          end
        end
        logger.debug("constructed xpath locator: #{xpath}")
        return xpath
      end

      # If the current section directive has a matches field, interogates
      # gold_model, either with instance_eval (if matches is a String) or
      # by sending the matches value if it is a Symbol (method call).
      def gold_expected_value(section_key = section, raw = false)
        logger.debug("gold_expected_value for section: #{section_key}")
        matches_expression = matches(section_key) || section_key.to_sym
        logger.debug("gold_expected_value evaluating expression: #{matches_expression} against #{gold_model.inspect}")
        expected_value = case matches_expression
          when String then gold_model.instance_eval(matches_expression)
          when Symbol then gold_model.send(matches_expression) if gold_model.respond_to?(matches_expression)
        end
        expected_value = expected_value.to_s unless raw || expected_value.nil?
        logger.debug("gold_expected_value = #{expected_value.nil? ? '<nil>' : expected_value.inspect }")
        return expected_value
        # RuntimeErrors from malformed expressions or matches chains with nil
        # should be caught by the main validate() method.
      end

#      # Constructs a hash of relevant gold_model() values based on subsection
#      # fields.  This is used by errors to compare expected versus provided
#      # sections when unable to match sections.
#      def gold_expected_section_hash(section_key = self.section)
#        logger.debug("gold_expected_section_hash: #{section_key}")
#        expected_section = {}
#        keys(section_key).each do |field_name,value_xpath|
#          expected_section[field_name.to_sym] = gold_model.send(field_name) if value_xpath
#        end 
#        subsections(section_key).inject(expected_section) do |hash,subsection|
#          logger.debug("subsection: #{subsection}, hash: #{hash.inspect}")
#          if field = field_name(subsection)
#            hash[field.to_sym] = gold_expected_value(subsection)
#          end
#          hash
#        end
#      end

#      # Constructs an array of relevant field value hashes for each element in
#      # xml_section_nodes().   This is used by errors to compare expected versus
#      # provided.  sections when unable to match sections.
#      def xml_provided_sections_array(section_key = self.section)
#        logger.debug("xml_provided_sections_array: #{section_key}")
#        xml_section_nodes.map do |node|
#          logger.debug("node: #{node.inspect}")
#          provided_section = {}
#          keys(section_key).each do |field_name,value_xpath|
#            provided_section[field_name.to_sym] = extract_node_value(value_xpath, node) if value_xpath
#          end
#          subsections(section_key).inject(provided_section) do |hash,subsection|
#            logger.debug("subsection: #{subsection}")
#            if field = field_name(subsection)
#              hash[field.to_sym] = extract_node_value(xpath(subsection), node)
#            end
#            hash
#          end
#        end
#      end

      # Applies the given xpath to each node in the passed array of nodes (defaults
      # to xml_section_nodes()), and returns the first node for which the xpath
      # expression is successful.
      def match_in_nodes(xpath, nodes = xml_section_nodes, namespaces = DEFAULT_NAMESPACES)
        nodes.find { |n| !extract_first_node(xpath, n, namespaces).nil? }
      end

      # Looks up entry in node_hash (defaulting to xml_sections_hash).
      # Lookup using gold_model, calling the first key in current keys()
      # as the method.
      def match_from_hash(key, node_hash = xml_sections_hash)
        logger.debug("match_from_hash(#{key}, #{node_hash.inspect}")
        (node_hash || {})[key]
      end

      private

      def _descend_into_subsections(section_key = key, node = xml_component)
        subsections.each do |subsection|
          options = {
            :section => subsection,
          }
          options[node.kind_of?(Array) ? :xml_section_nodes : :xml_component] = node
          options[:gold_model] = gold_model.send(matches(section_key)) if matches(section_key)
          errors << descend(options).validate
        end
      end

    end

#    # Decorate the Descriptor classes with validator logic.
#    module Descriptors
#     
#      def self.decorate(descriptor)
#        klass = descriptor.class.to_s.demodulize
#        raise(ValidatorException, "Unknown decorator class #{klass} for #{descriptor}") unless constants.include?(klass)
#        klass.constantize.new(descriptor)
#      end
# 
#      class ValidationDecorator < SimpleDelegator
#        def validate
#          raise RuntimeError("Implement me.")
#        end
#      end
#
#      class Component < ValidationDecorator
#      end
#      
#      class RepeatingSection < ValidationDecorator
#      end
#
#      class Section < ValidationDecorator
#      end
#
#      class Field < ValidationDecorator
#      end
#    end

    # Holds the scope and general helper routines needed to validate a
    # C83 xml component against the values in a gold model object.
    class ComponentScope
      include Laika::AttributesHashAccessor
      include Routines
      include Actions

      # Symbol identifying the overarching C83 content model section
      # we are currently evaluating, such as Allergies or Medications
      attr_hash_accessor :component_module

      # Symbol used to identify the C83 section element being validated
      # in the current scope.
      attr_hash_accessor :section

      # The model of section values that we are validating the xml against.
      attr_hash_accessor :gold_model

#      # An array of gold models to be validated in turn.
#      attr_hash_accessor :gold_model_array

      # A ComponentDescriptors::SectionDescriptor instance detailing the model
      # key, xpath locator and exact node or text value for the the current
      # document element in scope.
      attr_hash_accessor :descriptor

      # XML object for the section being validated in the current scope.
      attr_hash_accessor :xml_component

      # If we have evaluated a section that repeats, any nodes of the matching
      # section type will be found here.
      attr_hash_accessor :xml_section_nodes

      # If we need to dereference a set of section nodes, this hash will
      # provide a lookup keyed by the freetext associated with each node's
      # reference id.
      attr_hash_accessor :xml_sections_hash

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

      def initialize(options)
        self.attributes=(options)
        self.xml_section_nodes = [] if self.xml_section_nodes.nil?
        self.xml_sections_hash = {} if self.xml_sections_hash.nil?
      end

      alias :unguarded_xml_component= :xml_component=
      def xml_component=(node)
        self.unguarded_xml_component = node.kind_of?(REXML::Document) ?
          node.root :
          node
      end

#      alias :original_descriptor_accessor :descriptor
#      def descriptor
#        Descriptors.decorate(original_descriptor_accessor)
#      end

      # Descend into a new component scope enclosed by the current scope,
      # with scope attributes overridden as specified in the passed options.
      #
      # If a block is also given, it is executed within this newly 
      # created ComponentScope.  This is used to drill down into subsections
      # of the document.
      #
      # Returns the new scope.
      def descend(options, &block)
        logger.debug("descending in scope from: #{self.to_s}")
        scope = ComponentScope.new(self.attributes.merge(options))
        scope.enclosing_scope = self
        logger.debug("descended into scope : #{scope.inspect}")
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
            :provided_sections => xml_section_nodes.map do |node|
              descend(:xml_component => node).collect_provided_values(section, xml_sections_hash.invert[node])
            end,
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

      # XPath pointer to find the current xml_component within it's parent document.
      def location
        xml_component.xpath
      end

      # Human readable section name.
      def section_name
        section.to_s.humanize.titleize
      end

      # The root element of the XML document we are validating.
      def root_element
        (xml_component || xml_section_nodes.first).try(:root)
      end

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

      def validate
        logger.debug("validating: #{descriptor}(#{section}, #{xml_component.inspect})")
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
          logger.error("C32Validator failure: #{e.inspect}\n#{e.backtrace}")
          raise(ValidatorException, "C32Validator failure: #{e.inspect}", e.backtrace)

          # evil? Basically just looking to get the original trace in a more
          # specific exception type
        end
        logger.debug("done validating: #{descriptor}(#{section}, #{xml_component.inspect})")
        return errors.flatten.compact
      end

      # Collect a hash of all the expected values from the current gold_model().
      def collect_expected_values(section_key = section)
        logger.debug("collect_expected_values: #{section_key}, #{gold_model.inspect}")
        expected_section = {}
        keys(section_key).each do |field_name,value_xpath|
          expected_section[field_name.to_sym] = gold_model.send(field_name) if value_xpath
        end 
        if action(section_key).to_s =~ /match_value/ && field = field_name(section_key)
          expected_section[field.to_sym] = gold_expected_value(section_key)
        end
        subsections(section_key).inject(expected_section) do |hash,subsection|
          logger.debug("subsection: #{subsection}, hash: #{hash.inspect}")
          options = { :section => subsection }
          options[:gold_model] = gold_model.send(matches(section_key)) if matches(section_key)
          hash.merge!(descend(options).collect_expected_values)
        end
        return expected_section 
      end

      # Collect a hash of all the values in the current xml_component().
      def collect_provided_values(section_key = section, key_value = nil)
        logger.debug("collect_provided_values: #{section_key}, #{xml_component.inspect}")
        provided_section = {}
        if key_value
          provided_section[keys(section_key).keys.first] = key_value
        else
          keys(section_key).each do |field_name,value_xpath|
            provided_section[field_name.to_sym] = extract_node_value(value_xpath, xml_component) if value_xpath
          end
        end
        if action(section_key).to_s =~ /match_value/ && field = field_name(section_key)
          provided_section[field.to_sym] = extract_node_value(xpath(section_key), xml_component)
        end
        subsections(section_key).inject(provided_section) do |hash,subsection|
          logger.debug("subsection: #{subsection}, hash: #{hash.inspect}")
          options = { :section => subsection }
          if action(section_key).to_s =~ /get_section($|_)/
            options[:xml_component] = extract_first_node(xpath(section_key))
            hash.merge!(descend(options).collect_provided_values) unless options[:xml_component].nil?
          else
            hash.merge!(descend(options).collect_provided_values)
          end
        end
        return provided_section
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

      def _gold_model_matching(descriptor)
        gold_model.send(descriptor.key) if gold_model.respond_to?(descriptor.key)
      end

      def _location_by_error_type(klass)
        logger.debug("_location_by_error_type for #{klass}")
        case 
          when klass == Laika::SectionNotFound
            find_innermost_element.try(:xpath)
          when klass == Laika::NoMatchingSection
            xml_section_nodes.first.try(:xpath)
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
        logger.debug("_add_error: #{klass}, #{final_args.inspect}")
        errors << klass.new(final_args)
      end

    end

    # This is the validation engine for content inspection.
    #
    # Validators::C32Validation::Validator.new.validate(patient, document)
    #
    class Validator < Validation::BaseValidator

      attr_accessor :logger

      def validate(patient, document)
        self.logger = patient.logger if logger.nil?
        logger.debug("#{self.class}.validate()\n  -> patient: #{patient}\n  -> document: #{document.inspect}")
        errors = Patient.c32_modules.each.map do |component_module, association_key|
          gold_model = patient.send(association_key)

          # temporary test for whether we have any directives set up for this component module
#          next unless C32Validation::DirectiveMap::SECTION_DIRECTIVES_MAP.key?(component_module)
          next unless descriptor = Validators::C32Descriptors.get_component(component_module)

          logger.debug("Validating component: #{component_module}, association_key: #{association_key}")
          descriptor.attach(document.root)
          logger.debug("descriptor: #{descriptor.inspect}")
          logger.debug("gold_model: #{gold_model}")

          unless gold_model.nil? || gold_model.empty?
            ComponentScope.new(
              :component_module => component_module,
              :section          => component_module,
              :gold_model       => gold_model,
              :xml_component    => document,
              :descriptor      => descriptor,
              :validation_type  => validation_type,
              :logger           => logger,
              :validator        => C32VALIDATOR,
              :inspection_type  => ::CONTENT_INSPECTION
            ).validate
          end

        end.flatten!.compact!
      end

    end

  end

end
