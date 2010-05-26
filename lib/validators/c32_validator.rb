# Initial cut at separating the C32 validation routines form the models.  All
# this currently does is to reinject the models with the validation classes.
# The C32Validator then just calls the validate 32 method on the pateint data
# object
module Validators

  # Raised if the Validator itself encounters a problem in execution. 
  class ValidatorException < RuntimeError; end

  # Raised if a C83 component section has not been defined in the
  # SECTION_DIRECTIVES_MAP yet.
  class SectionDerectiveException < ValidatorException; end
 
  module C32Validation
    C32VALIDATOR = "C32Validator"
   
    # Has all of the validation code for specific C32/C83 components. 
    module Routines

      DEFAULT_NAMESPACES = {
        "cda"  => "urn:hl7-org:v3",
        "sdtc" => "urn:hl7-org:sdtc",
      }

      # Maps sections to the actions which should be taken to validate them.
      #
      # Each section is defined by a lookup key related to its C32 section.
      # It points to a hash which should have an action, a locator and other
      # optional keys depending on the action and any subsections which need
      # to be checked afterwords.
      #
      # :action => the command which should be performed when this section
      #   is reached in the validation process.
      #   * :validate_sections - extract all sections matching the given locator
      #     and then validate each gold_model_array() member against the
      #     xml_section_nodes() of :subsection_type 
      #   * :match_section - identify using :locator and :keys the
      #     xml_section_nodes() member matching the current gold_model()
      #   * :match_value - check that the value returned by the :locator
      #     on the current xml_component() equals the :matches expression
      #     evaluated against the gold_model()
      #   * :match_value_if_exists_in_model - :match_value, but only if
      #     gold_model()'s value is non-nil.
      # :locator => xpath expression used by the :action to identify the
      #   node or nodes we are currently validating.
      # :keys => if present, this is hash of keys that may be used
      #   to specify values to be looked up from the current gold_model and
      #   substituted back into the locator to identify an element matching
      #   the current gold_model.  (This is how we tell which of many sections
      #   of a given type match a specific gold_model object of the same type)
      #   The values should be the xpath of the corresponding key in the xml for
      #   reverse lookups when building validation error output when no matching
      #   section is found.
      # :subsection_type => identifies the section type returned by the current
      #   :validate_sections call.  This key must map back to the
      #   SECTION_DIRECTIVES_MAP. 
      # :subsections => array specifying the set of sections within the current
      #   section to be evaluated next.  These keys must map back to the 
      #   SECTION_DIRECTIVES_MAP. 
      # :matches => a String expression or method Symbol that will be evaled or
      #   sent against the current gold_model() when processing a :match_value 
      #   action for a section.
      # :field_name => field name to us in a comparison error after a failed
      #   match action.  If not given, defaults to matches.to_s.
      SECTION_DIRECTIVES_MAP = {
        # Language Component Module validation
        :languages => {
          :action  => :validate_sections,
          :locator => %q{//cda:recordTarget/cda:patientRole/cda:patient/cda:languageCommunication},
          :subsection_type => :language_communication,
        },
        :language_communication => {
          :action  => :match_section,
          :locator => %q{cda:languageCode[@code='${language_code}']},
          :keys    => {
            :language_code => 'cda:languageCode/@code',
          },
          :subsections => [:mode_code, :preference_ind],
        },
        :mode_code => {
          :action  => :match_value_if_exists_in_model,
          :locator => "cda:modeCode/@code",
          :matches => "language_ability_mode.try(:code)",
          :field_name => "language_ability_mode",
        },
        :preference_ind => {
          :action  => :match_value_if_exists_in_model,
          :locator => "cda:preferenceInd/@value",
          :matches => :preference,
        },
        # Healthcare Providers Component Module validation

        # Person Information Component Module validation
      
      }

      def section_directives_map_entry(section_key = section)
        section_directives = SECTION_DIRECTIVES_MAP[section_key] 
        raise(SectionDerectiveException, "SECTION_DIRECTIVES_MAP entry missing or malformed for the given key: #{section_key}\n#{SECTION_DIRECTIVES_MAP.inspect}") if section_directives.nil? || !section_directives.kind_of?(Hash)
        return section_directives
      end

      [:action, :locator, :matches, :subsection_type].each do |m|
        define_method(m) do |*args|
          section_key = args.shift || self.section
          section_directives_map_entry(section_key)[m]
        end
      end

      def field_name(section_key = section)
        field = section_directives_map_entry(section_key)[:field_name] ||
        field ||= (matches(section_key).nil? ? nil : matches(section_key).to_s)
        return field
      end

      [[:keys, Hash], [:subsections, Array]].each do |m,default_class|
        define_method(m) do |*args|
          section_key = args.shift || self.section
          section_directives_map_entry(section_key)[m] || default_class.new
        end
      end

      # Lookup the matching xpath from SECTION_DIRECTIVE_MAP and ensure that
      # any keys are evaluated.
      def xpath(section_key = section)
        xpath = locator(section_key)
        keys(section_key).each_key do |k|
          xpath = xpath.gsub(%r|\$\{#{k}}|, gold_model.send(k))
        end
        logger.debug("constructed xpath locator: #{xpath}")
        return xpath
      end

      # Attempt to find the matching section from xml_section_nodes based on a
      # locator keyed from the current gold_model().  If it is found, and a
      # block is given, we will yield to it.
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
        locator = xpath(section_key)
        if node = match_in_nodes(locator) # try each xml_section_nodes node in sequenc until we get a match
          errors << yield(node) if block_given?
          subsections.each do |subsection|
            errors << descend(
              :section => subsection,
              :xml_component => node
            ).validate
          end
        else
          add_no_matching_section_error(locator)
        end
        return errors
      end

      # Lookup a section absolutely.  If it is found, and a block is given,
      # we will yield to it.  Otherwise a SectionNotFound error is
      # generated. 
      def get_section(section_key = section)
        locator = xpath(section_key)
        if node = extract_first_node(locator)
          yield(node) if block_given?
        else
          add_section_not_found_error(locator)
        end
        return errors
      end

      # Lookup all the xml sections matching the given locator.  If any
      # are found, descend into a new ComponentScope for each gold_model
      # instance so that it can attempt to match against them.  Otherwise a
      # SectionNotFound error is generated.
      def validate_sections(section_key = section)
        logger.debug("validate_sections: #{section_key}")
        locator = xpath(section_key)
        unless (nodes = extract_all_nodes(locator)).empty?
          gold_model_array.each do |gold|
            errors << descend(
              :section => subsection_type(section_key),
              :gold_model => gold,
              :xml_section_nodes => nodes
            ).validate
          end
        else
          add_section_not_found_error(locator)
        end
      end

      # If the current section directive has a matches field, interogates
      # gold_model, either with instance_eval (if matches is a String) or
      # by sending the matches value if it is a Symbol (method call).
      #
      # Returns nil or a String for comparison.
      def gold_expected_value(section_key = section)
        logger.debug("gold_expected_value for section: #{section_key}")
        matches_expression = matches(section_key)
        expected_value = case matches_expression
          when String then gold_model.instance_eval(matches_expression)
          when Symbol then gold_model.send(matches_expression)
        end
        expected_value = expected_value.to_s unless expected_value.nil?
        logger.debug("gold_expected_value = #{expected_value.nil? ? '<nil>' : expected_value.inspect }")
        return expected_value
        # RuntimeErrors from malformed expressions or matches chains with nil
        # should be caught by the main validate() method.
      end

      # Perform a match_value action, but only if the gold_model()
      # has a non-nil value to check.
      def match_value_if_exists_in_model(section_key = section)
        match_value(section_key) unless gold_expected_value(section_key).nil?
      end

      # Lookup a value in the current xml_component() and compare for
      # equality with a value from the current gold_model().
      def match_value(section_key = section)
        logger.debug("match_value: #{section_key}")
        locator = xpath(section_key)
        expected_value = gold_expected_value(section_key)
        if desired_node = extract_first_node(locator)
          actual_value = extract_node_value(locator)
          add_comparison_error(field_name, expected_value, actual_value) unless expected_value.eql?(actual_value)

        elsif !expected_value.nil?
          add_section_not_found_error(locator, :field_name => field_name)
        else
          # If expected_value is nil and desired_node is nil, we assume
          # that there is no error because the node is not required.
          # If the node is in fact required, it's up to the schematron rules
          # to point this out. 
        end
      end
 
      # Constructs a hash of relevant gold_model() values based on subsection
      # fields.  This is used by errors to compare expected versus provided
      # sections when unable to match sections.
      def gold_expected_section_hash(section_key = self.section)
        logger.debug("gold_expected_section_hash: #{section_key}")
        expected_section = {}
        keys(section_key).each_key do |field_name|
          expected_section[field_name.to_sym] = gold_model.send(field_name)
        end 
        subsections(section_key).inject(expected_section) do |hash,subsection|
          logger.debug("subsection: #{subsection}, hash: #{hash.inspect}")
          if field = field_name(subsection)
            hash[field.to_sym] = gold_expected_value(subsection)
          end
          hash
        end
      end

      # Constructs an array of relevant field value hashes for each element in
      # xml_section_nodes().   This is used by errors to compare expected versus
      # provided.  sections when unable to match sections.
      def xml_provided_sections_array(section_key = self.section)
        logger.debug("xml_provided_sections_array: #{section_key}")
        xml_section_nodes.map do |node|
          logger.debug("node: #{node.inspect}")
          provided_section = {}
          keys(section_key).each do |field_name,value_xpath|
            provided_section[field_name.to_sym] = extract_node_value(value_xpath, node)
          end
          subsections(section_key).inject(provided_section) do |hash,subsection|
            logger.debug("subsection: #{subsection}")
            if field = field_name(subsection)
              hash[field.to_sym] = extract_node_value(xpath(subsection), node)
            end
            hash
          end
        end
      end

      # Applies the given xpath to each node in the passed array of nodes (defaults
      # to xml_section_nodes()), and returns the first node for which the xpath
      # expression is successful.
      def match_in_nodes(xpath, nodes = xml_section_nodes, namespaces = DEFAULT_NAMESPACES)
        nodes.find { |n| !extract_first_node(xpath, n, namespaces).nil? }
      end

      # Return an array of all nodes the given xpath matches within the passed
      # node (defaults to xml_component).
      def extract_all_nodes(xpath, node = xml_component, namespaces = DEFAULT_NAMESPACES)
        _extract_nodes(:match, xpath, node, namespaces)
      end

      # Returns the first node matched by the given xpath within the given node
      # (defaults to xml_component), or returns nil.
      def extract_first_node(xpath, node = xml_component, namespaces = DEFAULT_NAMESPACES) 
        _extract_nodes(:first, xpath, node, namespaces)
      end

      # Returns the textual value of the node obtained by following the given
      # locator in the current xml_component().
      def extract_node_value(xpath, node = xml_component, namespaces = DEFAULT_NAMESPACES)
        node = extract_first_node(xpath, node, namespaces)
      
        value = nil 
        if node.kind_of?(String) ||
          node.kind_of?(TrueClass)||
          node.kind_of?(FalseClass) ||
          node.kind_of?(NilClass)
          value = node           
        elsif node.respond_to?(:text)
          value = node.text
        else
          value = node.value
        end
      end

      # Backs through the given section's locator to find the 
      # first non-nil Element node.  Given a locator such as 
      # 'foo/bar/baz' will try 'foo/bar/baz', then 'foo/bar'
      # then 'foo' looking for a non-nil Element to return.
      #
      # If no match is made, returns the node we've been 
      # searching in.
      #
      # This is useful to pinpoint validation errors as close
      # to their problem source as possible.
      def find_innermost_element(locator = xpath, search_node = xml_component)
        logger.debug("find_innermost_element using #{locator} in #{search_node.inspect}")
        until node = extract_first_node(locator, search_node)
          # clip off the left most [*] predicate or /* path
          md = %r{
            \[[^\]]+\]$ |
            /[^/\[]*$
          }x.match(locator)
          break if md.nil? || md.pre_match == '/'
          locator = md.pre_match
        end
        node = node || search_node
        node = node.element if node.kind_of?(REXML::Attribute)
        node = node.parent if node.kind_of?(REXML::Text)
        return node || search_node
      end
 
#      def validate_languages
#        errors << get_section do |language_nodes|
#          self.section_nodes = language_nodes
#          gold_model.each do |language|
#            self.descend(:subsection => :language, :gold_model => language) do
#              errors << match_section do |language_communication_element|
#                if gold_model.language_ability_mode
#                  errors << match_value(language_communication_element, 
#                                        "cda:modeCode/@code", 
#                                        "language_ability_mode", 
#                                        language.language_ability_mode.code)
#                end
#                if gold_model.preference
#                  errors << match_value(language_communication_element, 
#                                        "cda:preferenceInd/@value", 
#                                        "preference", 
#                                        language.preference.to_s)        
#                end
#              end
#            end
#          end
#        end
#        errors.compact
#      end

      private
 
      def _extract_nodes(command, xpath, node = xml_component, namespaces = DEFAULT_NAMESPACES)
        logger.debug("_extract_nodes: #{command}, #{xpath}, #{node.inspect}, #{namespaces.inspect}")
        begin
          REXML::XPath.send(command, node, xpath, namespaces)
        rescue REXML::ParseException => e
          logger.info("REXML::ParseException thrown attempting to follow: #{xpath} in node:\n#{xml_component.inspect}\nException: #{e}, #{e.backtrace}")
          add_validation_error("Unparseable xml or bad xpath attempting: #{xpath} in node:\n#{xml_component.inspect}", :severity => :fatal, :exception => e)
        end
      end

    end

    # Holds the scope and general helper routines needed to validate a
    # C83 xml component against the values in a gold model object.
    class ComponentScope
      include Laika::AttributesHashAccessor
      include Routines

      # Symbol identifying the overarching C83 content model section
      # we are currently evaluating, such as Allergies or Medications
      attr_hash_accessor :component_module

      # Symbol used to identify the C83 section element being validated
      # in the current scope.
      attr_hash_accessor :section

      # The model of section values that we are validating the xml against.
      attr_hash_accessor :gold_model

      # An array of gold models to be validated in turn.
      attr_hash_accessor :gold_model_array

      # XML object for the section being validated in the current scope.
      attr_hash_accessor :xml_component

      # If we have evaluated a section that repeats, any nodes of the matching
      # section type will be found here.
      attr_hash_accessor :xml_section_nodes

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
      end

      alias :unguarded_xml_component= :xml_component=
      def xml_component=(node)
        self.unguarded_xml_component = node.kind_of?(REXML::Document) ?
          node.root :
          node
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
            :message => "Unable to find #{section_name} by following #{locator} in the current element.",
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
            :message => "No #{section_name} section was found matching the given xpath: #{xpath}",
            :expected_section => gold_expected_section_hash,
            :provided_sections => xml_provided_sections_array,
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
            :message    => "Expected #{ !expected_value.nil? ? expected_value.to_s : 'nil' } got #{ !actual_value.nil? ? actual_value : 'nil' }",
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
        section.to_s.humanize
      end

      # The validation to be performed against the current section in scope.
      def current_action
        action(section)
      end

      def validate
        logger.debug("validating: #{current_action}(#{section}, #{xml_component.inspect})")
        begin
          send(current_action)
        rescue RuntimeError => e
          logger.error("C32Validator failure: #{e.inspect}\n#{e.backtrace}")
          raise(ValidatorException, "C32Validator failure: #{e.inspect}", e.callback)

          # evil? Basically just looking to get the original trace in a more
          # specific exception type
        end
        logger.debug("done validating: #{current_action}(#{section}, #{xml_component.inspect})")
        return errors.flatten.compact
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
          association = patient.send(association_key)
          association.respond_to?(:each) ?
            gold_model_array = association :
            gold_model = association

          logger.debug("Validating component: #{component_module}, association_key: #{association_key}")
          logger.debug("gold_model: #{gold_model}")
          logger.debug("gold_model_array: #{gold_model_array}")

          ComponentScope.new(
            :component_module => component_module,
            :section          => component_module,
            :gold_model       => gold_model,
            :gold_model_array => gold_model_array,
            :xml_component    => document,
            :validation_type  => validation_type,
            :logger           => logger,
            :validator        => C32VALIDATOR,
            :inspection_type  => ::CONTENT_INSPECTION
          ).validate

        end.flatten!.compact!
      end

    end

  end

end
