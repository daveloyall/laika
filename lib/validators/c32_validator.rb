# Initial cut at separating the C32 validation routines form the models.  All
# this currently does is to reinject the models with the validation classes.
# The C32Validator then just calls the validate 32 method on the pateint data
# object
module Validators

  # Raised if the Validator itself encounters a problem in execution. 
  class ValidatorException < RuntimeError; end

  # Raised if a C83 component section has not been defined in the
  # SECTION_DIRECTIVES_MAP yet.
  class SectionDirectiveException < ValidatorException; end
 
  module C32Validation
    C32VALIDATOR = "C32Validator"
  
    # Maps sections to the actions which should be taken to validate them.
    #
    # Each section is defined by a lookup key related to its C32 section.
    # It points to a hash which should have an action, a locator and other
    # optional keys depending on the action and any subsections which need
    # to be checked afterwords.
    #
    # :action => the command which should be performed when this section
    #   is reached in the validation process.
    # :locator => xpath expression used by the :action to identify the
    #   node or nodes we are currently validating.
    # :template_id => C83 component template id may be given in place of a full
    #   xpath expression to locate a C83 section. 
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
    # :field_name => field name to use in a comparison error after a failed
    #   match action.  If not given, defaults to matches.to_s.
    #
    # A directive entry may be configured for different C32 versions by subkeying 
    # the hash by Validation::C32_* constants:
    #
    # :some_section => {
    #   Validation::C32_V2_5_TYPE => {
    #     :action => :foo,
    #   },
    #   :action => :bar,
    # }
    #
    # Will default to performing the :bar action on C32's unless they are v2.5
    # in which case the :foo action will be performed instead.
    module DirectiveMap

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
        :healthcare_providers => {
          :action => :validate_sections,
          :locator => %q{//cda:documentationOf/cda:serviceEvent/cda:performer},
          :subsection_type => :performer,
        },
        :performer => {
          :action  => :match_section,
          :locator => %q{cda:assignedEntity/cda:assignedPerson/cda:name[cda:given='${first_name}' and cda:family='${last_name}']},
          :keys    => {
            :first_name => nil,
            :last_name  => nil,
          },
          :subsections => [:provider_role, :time, :assigned_entity], 
        },
        :provider_role => {
          :action       => :get_section_if_exists_in_model,
          :locator      => %q{cda:functionCode},
          :matches      => :provider_role,
          :subsections  => [:code, :display_name],
        },
        :time => {
          :action      => :get_section,
          :locator     => %q{cda:time},
          :subsections => [:low, :high],
        },
        :low => {
          :action  => :match_value,
          :locator => %q{cda:low/@value},
          :matches => :start_service,
        },
        :high => {
          :action  => :match_value,
          :locator => %q{cda:high/@value},
          :matches => :end_service,
        },
        :assigned_entity => {
          :action      => :get_section,
          :locator     => %q{cda:assignedEntity},
          :subsections => [:provider_type, :assigned_person, :addr, :telecom, :patient],
        },
        :code => {
          :action  => :match_value,
          :locator => %q{@code},
        },
        :display_name => {
          :action   => :match_value,
          :locator => %q{@displayName},
          :matches  => :name,
        },
        :provider_type => {
          :action      => :get_section_if_exists_in_model,
          :locator     => %q{cda:code},
          :matches     => :provider_type,
          :subsections => [:code, :display_name],
        },
        :assigned_person => {
          :action      => :get_section_if_exists_in_model,
          :locator     => %q{cda:assignedPerson/cda:name},
          :matches     => :person_name,
          :subsections => [:name_prefix, :first_name, :middle_name, :last_name, :name_suffix]
        },
        :name_prefix => {
          :action   => :match_value,
          :locator  => %q{cda:prefix'},
        },
        :first_name => {
          :action   => :match_value,
          :locator  => %q{cda:given[1]'},
          :matches  => :first_name,
        },
        :middle_name => {
          :action   => :match_value,
          :locator  => %q{cda:given[2]'},
        },
        :last_name => {
          :action   => :match_value,
          :locator  => %q{cda:family'},
        },
        :name_suffix => {
          :action   => :match_value,
          :locator  => %q{cda:suffix'},
        },
        :addr => {
          :action      => :get_section_if_exists_in_model,
          :locator     => %q{cda:addr},
          :matches     => :address,
          :subsections => [:street_address_line_one, :street_address_line_two, :city, :state, :postal_code, :iso_country_code],
        },
        :street_address_line_one => {
          :action   => :match_value,
          :locator  => %q{cda:streetAddressLine[1]},
        }, 
        :street_address_line_two => {
          :action   => :match_value,
          :locator  => %q{cda:streetAddressLine[2]},
        }, 
        :city => {
          :action   => :match_value,
          :locator  => %q{cda:city},
        }, 
        :state => {
          :action   => :match_value,
          :locator  => %q{cda:state},
        }, 
        :postal_code => {
          :action   => :match_value,
          :locator  => %q{cda:postalCode},
        }, 
        :iso_country_code => {
          :action     => :match_value_if_exists_in_model,
          :locator    => %q{cda:country},
          :matches    => "iso_country.code",
          :field_name => :iso_country,
        }, 
        :telecom => {
          :action      => :get_sections_if_exists_in_model,
          :locator     => %q{cda:telecom},
          :matches     => :telecom,
          :subsections => [:home_phone, :work_phone, :mobile_phone, :vacation_home_phone, :email],
        },
        :home_phone => {
          :action     => :match_telecom_as_hp,
        },
        :work_phone => {
          :action     => :match_telecom_as_wp,
        },
        :mobile_phone => {
          :action     => :match_telecom_as_mc,
        },
        :vacation_home_phone => {
          :action     => :match_telecom_as_hv,
        },
        :email => {
          :action     => :match_telecom_as_email,
        },
        :patient => {
          :action      => :match_value_if_exists_in_model,
          :locator     => %q{sdtc:patient/sdtc:id/@root},
          :matches     => :patient_identifier,
          :field_name  => "id",
        },
        # Medication Component Module validation
        :medications => {
          :action      => :get_section,
          :template_id => '2.16.840.1.113883.10.20.1.8',
          :subsections => [:substance_administrations],
        }, 
        :substance_administrations => {
          Validation::C32_V2_5_TYPE => {
            :action          => :validate_dereferenced_sections,
            :locator         => %q{//cda:substanceAdministration},
            :subsection_type => :medication,
          },
          :action          => :validate_sections,
          :locator         => %q{//cda:substanceAdministration},
          :subsection_type => :medication,
        },
        :medication => {
          Validation::C32_V2_5_TYPE => {
            :action      => :match_section,
            :keys        => {
              :product_coded_display_name => :dereferenced_key,
            },
            :subsections => [:consumable, :medication_type, :status, :order],
          },
          :action      => :match_section,
          :locator     => %q{cda:consumable/cda:manufacturedProduct/cda:manufacturedMaterial/cda:code[cda:originalText/text() = '${product_coded_display_name}']},
          :keys        => {
            :product_coded_display_name => %q{cda:consumable/cda:manufacturedProduct/cda:manufacturedMaterial/cda:code/cda:originalText/text()},
          },
          :subsections => [:consumable, :medication_type, :status, :order],
        },
        :consumable => {
          :action      => :get_section,
          :locator     => %q{cda:consumable},
          :subsections => [:manufactured_product],
        },
        :manufactured_product => {
          :action       => :get_section,
          :locator      => %q{cda:manufacturedProduct},
          :subsections  => [:manufactured_material],
        },
        :manufactured_material => {
          :action     => :match_value,
          :locator    => %q{cda:manufacturedMaterial/cda:name},
          :matches    => :free_text_brand_name, 
        },
        :medication_type => {
          :action     => :match_value,
          :locator    => %q{cda:entryRelationship[@typeCode='SUBJ']/cda:observation[cda:templateId/@root='2.16.840.1.113883.3.88.11.32.10']/cda:code/@displayName},
          :matches    => "medication_type.try(:name)",
          :field_name => :medication_type
        },
        :status => {
          :action     => :match_value,
          :locator    => %q{cda:entryRelationship[@typeCode='REFR']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.1.47']/cda:statusCode/@code},
        },
        :order => {
          :action     => :get_section,
          :locator    => %q{cda:entryRelationship[@typeCode='REFR']/cda:supply[@moodCode='INT']},
          :subsections => [:quantity_ordered_value, :expiration_time] 
        },
        :quantity_ordered_value => {
          :action   => :match_value,
          :locator  => %q{cda:quantity/@value},
        },
        :expiration_time => {
          :action   => :match_value,
          :locator  => %q{cda:effectiveTime/@value"},
        },
        # Allergy Component Module validation
        :allergies => {
          :action      => :get_section,
          :template_id => '2.16.840.1.113883.10.20.1.2',
          :subsections => [:acts],
        }, 
        :acts => {
          :action          => :validate_sections,
          :locator         => %q{//cda:act[cda:templateId/@root='2.16.840.1.113883.10.20.1.27']/cda:entryRelationship[@typeCode='SUBJ']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.1.18']},
          :subsection_type => :adverse_events,
        },
        :adverse_events=> {
          :action       => :match_section,
          :locator      => %q{cda:participant[@typeCode='CSM']/cda:participantRole[@classCode='MANU']/cda:playingEntity[@classCode='MMAT']/cda:name[text() = '${free_text_product}']},
          :keys => {
            :free_text_product => %q{cda:participant[@typeCode='CSM']/cda:participantRole[@classCode='MANU']/cda:playingEntity[@classCode='MMAT']/cda:name/text()},
          },
          :subsections  => [:start_event, :end_event, :product_code],
        },
        :start_event => {
          :action  => :match_value,
          :locator =>  %q{cda:effectiveTime/cda:low/@value},
        },
        :end_event => {
          :action  => :match_value,
          :locator =>  %q{cda:effectiveTime/cda:high/@value},
        },
        :product_code => {
          :action  => :match_value,
          :locator => %q{cda:participant[@typeCode='CSM']/cda:participantRole[@classCode='MANU']/cda:playingEntity[@classCode='MMAT']/cda:code[@codeSystem='2.16.840.1.113883.6.88']/@code},
        },
        # Person Information Component Module validation
      }

      def section_directives_map_entry(section_key = section)
        section_directives = SECTION_DIRECTIVES_MAP[section_key]
        section_directives = section_directives[validation_type] if section_directives.try(:key?, validation_type)
        raise(SectionDirectiveException, "SECTION_DIRECTIVES_MAP entry missing or malformed for the given key: #{section_key}, validation_type: #{validation_type}") if section_directives.nil? || !section_directives.kind_of?(Hash)
        return section_directives
      end

      [:action, :locator, :template_id, :matches, :subsection_type].each do |m|
        define_method(m) do |*args|
          section_key = args.shift || self.section
          section_directives_map_entry(section_key)[m]
        end
      end

      def field_name(section_key = section)
        field = section_directives_map_entry(section_key)[:field_name]
        field ||= (matches(section_key).nil? ? nil : matches(section_key).to_s)
        field ||= section_key.to_s
        return field
      end

      [[:keys, Hash], [:subsections, Array]].each do |m,default_class|
        define_method(m) do |*args|
          section_key = args.shift || self.section
          section_directives_map_entry(section_key)[m] || default_class.new
        end
      end

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
        def get_section(section_key = section)
          logger.debug("get_section: #{section_key}")
          locator = xpath(section_key)
          if node = extract_first_node(locator)
            errors << yield(node) if block_given?
            _descend_into_subsections(section_key, node)
          else
            add_section_not_found_error(locator)
          end
          return errors
        end

        # Lookup a value in the current xml_component() and compare for
        # equality with a value from the current gold_model().
        def match_value(section_key = section)
          logger.debug("match_value: #{section_key}")
          locator = xpath(section_key) || "@#{section_key.to_s.camelcase(:lower)}"
          expected_value = gold_expected_value(section_key, true)
          if desired_node = extract_first_node(locator)
            actual_value = extract_node_value(locator)
            add_comparison_error(field_name, expected_value.to_s, actual_value) unless _equal_values?(expected_value, actual_value)

          elsif !expected_value.nil?
            add_section_not_found_error(locator, :field_name => field_name)
          else
            # If expected_value is nil and desired_node is nil, we assume
            # that there is no error because the node is not required.
            # If the node is in fact required, it's up to the schematron rules
            # to point this out. 
          end
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

      DEFAULT_NAMESPACES = {
        "cda"  => "urn:hl7-org:v3",
        "sdtc" => "urn:hl7-org:sdtc",
      }

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

      # Extracts all the given sections from a passed REXML doc and return
      # them as a hash keyed by the external free text associated with an
      # internal reference id.
      #
      # For example, if given an array of substanceAdministration sections,
      # this will produce a hash of all the medication component's
      # substanceAdministration element's keyed by their own
      # consumable/manufacturedProduct/manufacturedMaterial/code/reference@value's
      # (which should key to the medication names in the free text table for
      # a v2.5 C32 doc...)
      def dereference(section_key = section, nodes = nil)
        logger.debug("dereference(#{section_key}, #{nodes.inspect})")
        nodes ||= xml_section_nodes
        nodes.inject({}) do |hash,section|
          logger.debug("dereference section: #{section.inspect}")
          if reference = REXML::XPath.first(section, './/cda:reference[@value]', MatchHelper::DEFAULT_NAMESPACES)
            logger.debug("dereference reference: #{reference.inspect}")
            if name = REXML::XPath.first(root_element, "//[@ID=$id]/text()", MatchHelper::DEFAULT_NAMESPACES, { "id" => reference.attributes['value'].gsub("#",'')} )
              logger.debug("dereference name: #{name.inspect}")
              hash[name.value] = section
            end
          end
          hash
        end
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
 
      private
 
      def _extract_nodes(command, xpath, node = xml_component, namespaces = DEFAULT_NAMESPACES)
        logger.debug("_extract_nodes: #{command}, #{xpath}, #{node.inspect}, #{namespaces.inspect}")
        return ( command == :match ? [] : nil ) if xpath.blank? 
        begin
          REXML::XPath.send(command, node, xpath, namespaces)
        rescue REXML::ParseException => e
          logger.info("REXML::ParseException thrown attempting to follow: #{xpath} in node:\n#{xml_component.inspect}\nException: #{e}, #{e.backtrace}")
          add_validation_error("Unparseable xml or bad xpath attempting: #{xpath} in node:\n#{xml_component.inspect}", :severity => :fatal, :exception => e)
        end
      end

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

      # An array of gold models to be validated in turn.
      attr_hash_accessor :gold_model_array

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
        section.to_s.humanize
      end

      # The root element of the XML document we are validating.
      def root_element
        (xml_component || xml_section_nodes.first).try(:root)
      end

      # The validation to be performed against the current section in scope.
      def current_action
        action(section) || raise(ValidatorException, "No Action set in directive mapping for current section: #{section}")
      end

      def validate
        logger.debug("validating: #{current_action}(#{section}, #{xml_component.inspect})")
        begin
          send(current_action)
        rescue ValidatorException => e
          raise e # just repropagate
        rescue RuntimeError => e
          logger.error("C32Validator failure: #{e.inspect}\n#{e.backtrace}")
          raise(ValidatorException, "C32Validator failure: #{e.inspect}", e.backtrace)

          # evil? Basically just looking to get the original trace in a more
          # specific exception type
        end
        logger.debug("done validating: #{current_action}(#{section}, #{xml_component.inspect})")
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
