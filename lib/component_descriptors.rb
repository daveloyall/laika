require 'delegate'

# In order to be able to parse and validate a particular form of XML based
# medical document, we need to be able to describe the logical components of
# the document such that we can extract key fields for comparison with or
# export to some other model.
#
# components - a base component module of a patient document, like medications
# or allergies.
#
# section - a node in the document which may contain other sections or fields.
#
# repeating_section - a section which may occur one or more times, keyed by a
# value or set of values.
#
# field - a value in the document.
#
# attribute - shortcut for a field whose xpath locator is simply the key value
# as an attribute of the current node ("@#{key}").
#
# Every descriptor has a section_key which uniquely identifies it within its
# current section.  This key serves as the method used to look up a matching
# element in an object model of the patient document.  Every descriptor also
# has an xpath locator, either explictly declared or implicit from the
# section_key, which is used to identify a node within the document.  These
# locators nest.  So a descriptor's locator is within the context of it's
# parent's xml node (as identified by the parent's locator), and so on, up to
# the root section, whose context is the document.
#
# Every descriptor also has an index_key which uniquely identifies it within
# the nested hash of descriptors that it is a part of.
module ComponentDescriptors

  class DescriptorError < RuntimeError; end
  class DescriptorArgumentError < DescriptorError; end

  module OptionsParser

    KNOWN_KEYS = [:required, :repeats, :template_id, :matches_by, :locate_by, :accessor, :dereference]

    # Parses the different argument styles accepted by section/field methods.
    #
    # method(:key)
    # method(:key, :option => :foo)
    # method(:key => :locator, :option => :foo)
    # method([...original arguments...], :injected => :options)
    #
    # (The last variation is used internally by methods which need to inject
    # additional options into the call.  The original arguments are passed as
    # an array, with additional options as a final hash argument)
    #
    # Any other combination will raise an error.
    #
    # In the case of a key, locator pair, this special argument is isolated by
    # removing all of the known_keys from the hash.  The remaining key is taken
    # to be the key, locator pair.  If there are multiple keys remaining, an
    # error is raised.
    #
    # Returns [key, locator = nil, options = {}]
    def parse_args(args, known_keys = KNOWN_KEYS)
      local_args = args.dclone
      known_keys = Array(known_keys)

      validate = lambda do |arguments|
        raise(DescriptorArgumentError, "No arguments given.") if arguments.empty?
        raise(DescriptorArgumentError, "Two many arguments given (expected two at most): #{arguments.inspect}") if arguments.size > 2
      end
      validate.call(local_args)

      first, options = local_args
      locator, key, injected_options = nil, nil, nil
      if first.kind_of?(Array)
        # original arguments were stashed in an array so that additional options could be added
        validate.call(first)
        injected_options = options
        first, options = first
      end  
      options ||= {}
      raise(DescriptorArgumentError, "Expected an options hash; got: #{options.inspect}") unless options.kind_of?(Hash)
  
      case first
        when Hash 
        then 
          known_keys.each do |k|
            options[k] = first.delete(k) if first.key?(k)
          end
          first.each do |k,v|
            # Allows for VALIDATION_TYPE => {} overrides
            options[k] = first.delete(k) if v.kind_of?(Hash)
          end
          raise(DescriptorArgumentError, "Ambiguous arguments.  Too many options left in #{first.inspect} to identify the key and locator values.") if first.size > 1
          key, locator = first.shift
        else key = first
      end
 
      options.merge!(injected_options) if injected_options
      return key, locator, options
    end

  end

  # Include this in your module to enable creation of ComponentDescriptors.
  # 
  # Then begin generating descriptors by making calls to components()
  module Mapping
    def self.included(base)
      base.extend(ClassMethods)
    end
  
    module ClassMethods
      include ComponentDescriptors::OptionsParser
 
      def descriptors
        @descriptors_map = {} unless @descriptors_map
        return @descriptors_map
      end
   
      # Declares a component module that repeats.  The associated block may be used to define
      # sections and fields within the component, as shown in ComponentDescriptors::DSL.
      # This block of descriptors may occur one or more times, so components() is the
      # way to begin a module that is a repeating_section(), such as the C83 Languages
      # module
      # 
      # components :languages => %q{//cda:recordTarget/cda:patientRole/cda:patient/cda:languageCommunication}, :matches_by => :language_code do
      #   field :language_code => %q{cda:languageCode/@code}
      #   field :language_ability_mode => %q{cda:modeCode/@code}, :required => false
      #   field :preference_id => %q{cda:preferenceInd/@value}, :required => false
      # end
      # 
      def components(*args, &descriptors)
        _component_definition(args, :repeats => true, &descriptors)
      end
 
      # Declares a component module that starts with a single, non-repeating base section.
      # That section may contain a repeating_section however.
      #
      # component :allergies, :template_id => '2.16.840.1.113883.10.20.1.2' do
      #   repeating_section :allergy => %q{cda:entry/cda:act[cda:templateId/@root='2.16.840.1.113883.10.20.1.27']/cda:entryRelationship[@typeCode='SUBJ']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.1.18']}, :matches_by => :free_text_product do
      #     field :free_text_product => %q{cda:participant[@typeCode='CSM']/cda:participantRole[@classCode='MANU']/cda:playingEntity[@classCode='MMAT']/cda:name/text()}
      #     field :start_event => %q{cda:effectiveTime/cda:low/@value}
      #     ...
      #   end
      # end
      #
      def component(*args, &descriptors)
        _component_definition(args, :repeats => false, &descriptors)
      end

      # Declares a common set of descriptors which may be included in multiple
      # component definitions with a reference() call.
      #
      # TODO -> clip in example of abstract_result here
      def common(key, &descriptors)
        _component_definition([key], :common => true, &descriptors)
      end
  
      def get_component(name, options = {})
        descriptors[name].instantiate(options.merge(:mapping => self)) if descriptors.key?(name)
      end

      def get_common(key)
        descriptors[key] || raise(DescriptorError, "No common descriptor found for key: #{key.inspect} in mapping: #{descriptors.pretty_inspect}")
      end
 
      private

      def _component_definition(descriptor_args, component_options, &descriptors)
        key, locator, options = parse_args(descriptor_args)
        definition = ComponentDefinition.new(descriptor_args, component_options, &descriptors)
        self.descriptors[key] = definition
      end 
    end
  end

  # These methods can be used to construct nested descriptors.
  #
  # repeating_section :insurance_provider => %q{cda:entry/cda:act[cda:templateId/@root='2.16.840.1.113883.10.20.1.20']/cda:entryRelationship/cda:act[cda:templateId/@root='2.16.840.1.113883.10.20.1.26']} do
  #   field :group_number => %q{cda:id/@root}, :required => false
  #   section :insurance_type => %q{cda:code[@codeSystem='2.16.840.1.113883.6.255.1336']}, :required => false do
  #     attribute :code
  #     field :name => %q{@displayName}
  #   end
  #   field :represented_organization => %q{cda:performer[@typeCode='PRF']/cda:assignedEntity[@classCode='ASSIGNED']/cda:representedOrganization[@classCode='ORG']/cda:name}, :required => false
  # end
  module DSL
    include OptionsParser

    # Set a local reference to a ComponentDescriptors::Mapping.
    def mapping_class=(mapping_class)
      @mapping_class = mapping_class 
    end

    def mapping_class
      mapping_class = @mapping_class
      mapping_class ||= parent.try(:mapping_class) if respond_to?(:parent)
      return mapping_class
    end

    # Accessor for descriptors in our original ComponentDescriptor::Mapping.
    # Used to lookup references to common descriptors when instantiating.
    # Raises a DescriptorError if mapping_class is not set or descriptor cannot
    # be found.
    def mapping(key)
      raise(DescriptorError, "No Mapping class set.") unless mapping_class
#      pp mapping_class
      common_descriptor = mapping_class.get_common(key)
    end

    # Adds a subsection to this section.
    def section(*args, &descriptors)
      _instantiate_and_store(:section, *args, &descriptors)
    end

    # Adds a repeating section which occurs one or more times.
    def repeating_section(*args, &descriptors)
      _instantiate_and_store(:repeating_section, *args, &descriptors)
    end

    # Adds a field with a single value in the document. 
    def field(*args)
      _instantiate_and_store(:field, *args)
    end

    # Shortcut for adding a field whose xpath locator is simply the key value
    # as an attribute of the current node ("@#{key}").
    def attribute(*args)
      _instantiate_and_store(:field, args, :locate_by => :attribute)
    end

    # Evaluates the descriptors of a common descriptor section used by multiple
    # components.
    def reference(key)
      descriptors = mapping(key).descriptors
      instance_eval(&descriptors)
    end

    # Factory creation method for descriptors of :type.
    def self.create(type, key, locator, options, &descriptors)
      "ComponentDescriptors::#{type.to_s.classify}".constantize.send(:new, key, locator, options, &descriptors)
    end

    private
 
    def _initialize_subsections
      instance_eval(&descriptors) if descriptors
    end

    def _instantiate_and_store(type, *args, &descriptors)
      key, locator, options = parse_args(args)
      options[:logger] = logger unless options.key?(:logger) || logger.nil?
      options[:mapping] = mapping_class unless options.key?(:mapping) || mapping_class.nil?
      debug("_instantiate_and_store: #{key} => #{type} in #{self}")
      store(key, DSL.create(type, key, locator, options, &descriptors))
      self
    end

  end

  module XMLManipulation

    def self.included(base)
      base.send(:attr_accessor, :error)
    end

    CDA_NAMESPACE = "cda"
    SDTC_NAMESPACE = "sdtc"
    DEFAULT_NAMESPACES = {
      CDA_NAMESPACE  => "urn:hl7-org:v3",
      SDTC_NAMESPACE => "urn:hl7-org:sdtc",
    }

    # Returns the external free text associated with the given node's internal
    # reference id.
    #
    # For example, if given a substanceAdministration section, this will find
    # consumable/manufacturedProduct/manufacturedMaterial/code/reference@value,
    # and use it to lookup the medication name in the free text table for 
    # a v2.5 C32 doc.
    def dereference(node = xml)
      return unless node
      debug("dereference(#{node.inspect})")
      if reference = extract_first_node(".//#{CDA_NAMESPACE}:reference[@value]", node)
        debug("dereference reference: #{reference.inspect}")
        if name = extract_first_node("//[@ID='#{reference.attributes['value'].gsub("#",'')}']/text()", root_element)
          debug("dereference name: #{name.inspect}")
          name.value
        end
      end
    end

    # Return an array of all nodes the given xpath matches within the passed
    # node (defaults to xml_component).
    def extract_all_nodes(xpath, node = xml, namespaces = DEFAULT_NAMESPACES)
      _extract_nodes(:match, xpath, node, namespaces)
    end

    # Returns the first node matched by the given xpath within the given node
    # (defaults to xml_component), or returns nil.
    def extract_first_node(xpath, node = xml, namespaces = DEFAULT_NAMESPACES) 
      _extract_nodes(:first, xpath, node, namespaces)
    end

    # Returns the textual value of the node obtained by following the given
    # locator in the current xml_component().
    def extract_node_value(xpath, node = xml, namespaces = DEFAULT_NAMESPACES)
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

    # True if an error has been recorded while attempting to attach a node to
    # this descriptor.
    def error?
      !error.nil?
    end

    private

    def _extract_nodes(command, xpath, node = xml, namespaces = DEFAULT_NAMESPACES)
      debug("_extract_nodes: #{command}, #{xpath}, #{node.inspect}, #{namespaces.inspect}")
      return ( command == :match ? [] : nil ) if xpath.blank? 
      begin
        result = REXML::XPath.send(command, node, xpath, namespaces)
        debug("_extract_nodes: found #{result.inspect}")
        result
      rescue REXML::ParseException => e
        info("REXML::ParseException thrown attempting to follow: #{xpath} in node:\n#{node.inspect}\nException: #{e}, #{e.backtrace}")
        error = { :message => "Unparseable xml or bad xpath: attempting #{xpath} in node:\n#{node.inspect}", :severity => :fatal, :exception => e }
        return nil
      end
    end

  end

  # Methods needed by descriptors to travel up and down the descriptor tree.
  module NodeTraversal
    def self.included(base)
      base.send(:attr_accessor, :parent)
    end

    # Returns the root Component
    def root 
      parent.nil? ? self : parent.root
    end

    # True if this is the root component
    def root?
      parent.nil?
    end

    # Returns the root xml element
    def root_element
      root.xml 
    end

    # Walks up the chain of ancestors, returning the first non-nil
    # result for the given method, or nil if no result.
    def first_ancestors(method)
      return nil if root?
      if value = parent.send(method)
        return value
      end
      parent.first_ancestors(method) 
    end

    # Returns the first descendent matching the given section_key or nil.
    def descendent(section_key)
      return nil unless respond_to?(:fetch)
      unless descendent = fetch(section_key, nil)
        values.each do |v|
          raise(NoMethodError, "Node #{v} does not respond to descendent()") unless v.respond_to?(:descendent)
          descendent = v.descendent(section_key)
          break unless descendent.nil?
        end
      end
      return descendent 
    end

    # Array of all the descendent descriptors of the current descriptor.
    def descendents
      respond_to?(:values) ? values.map { |d| d.branch }.flatten : []
    end

    def parent_section_key
      parent.try(:section_key)
    end
  
    def parent_index_key
      parent.try(:index_key)
    end
 
    # Looks up a descriptor in the tree by index_key.
    def find(index_key)
      index[index_key]
    end

    # Self plus all descendent descriptors.
    def branch
      descendents.unshift(self)
    end

    # Array of all descriptor tree members.
    def all
      root.branch
    end

    # Lazily initialized index of all tree members by index_key().
    def index
      unless @descriptor_index
        @descriptor_index = all.inject({}) do |hash,d|
          hash[d.index_key] = d
          hash
        end
      end
      @descriptor_index
    end

    # Clears the index hash.
    def clear_index
      @descriptor_index.clear if @descriptor_index
    end
  end

  # Extensions to Hash used by node descriptors to keep track of parents.
  module HashExtensions
    # Ensure that we keep a reference to the parent hash when new elements are
    # stored. 
    def store(key, value)
      value.parent = self
      super
    end
  end

  # All Descriptors have a number of important attributes.
  #
  # * @section_key => uniquely identifies the descriptor within it's parent Hash.
  #
  # * @locator => xpath locator indicating how to find the associated xml value
  #   for this descriptor within the xml node of it's parent.
  #
  # * @accessor => the method to call to find the associated value from an attached
  #   model.  Defaults to section_key.
  #
  # * @descriptors => a block of ComponentDescriptors::DSL code describing any
  #   subsections or fields of this descriptor.
  #
  # * @xml => an xml node attached to the descriptor.  This is the node we would
  #   search in to produce an @extracted_value using the @locator.
  #
  # * @model => a document model element attached to the descriptor.  This is the 
  #   element we would send @method to to look up an associated model value.
  #
  # * @extracted_value => if we have attached an xml node or model element to this
  #   descriptor.  @extracted_value will hold the results of applying the @locator
  #   or @section_key to it.
  #
  # * @options => the hash of options first passed to the descriptor 
  module DescriptorInitialization

    def self.included(base)
      base.class_eval do
        attr_accessor :section_key, :locator, :accessor, :options, :descriptors, :extracted_value
        attr_reader :xml, :model
        include Logging
        include XMLManipulation
        include NodeTraversal
        include DSL

        include InstanceMethods
        alias_method :unguarded_locator, :locator
        def locator
          guarded_locator
        end
        alias_method :unguarded_accessor, :accessor
        def accessor
          guarded_accessor
        end
      end
    end

    module InstanceMethods
      def initialize(section_key, locator, options, &descriptors)
        self.section_key = section_key
        self.locator = locator
        self.options = options || {}
        self.logger = self.options[:logger]
        self.mapping_class = self.options[:mapping]
        self.descriptors = descriptors
        _initialize_subsections
      end

      def validation_type
        options[:validation_type] || first_ancestors(:validation_type)
      end

      # Hash of options specific to the current validation_type.  Typically empty.
      def validation_type_overrides
        options[validation_type] || {}
      end

      # First checks to see if the options was specified specially for the
      # current validation_type.  If so, returns it, if not, returns the base
      # option.
      def options_by_type(key)
        validation_type_overrides[key] || options[key]
      end

      # Sets and attaches the given xml node to the descriptor, extracting a value
      # based on locator. 
      def xml=(value)
        @model, @extracted_value = nil, nil
        @xml = value.kind_of?(REXML::Document) ? value.root : value
        attach_xml
        @xml
      end

      # Sets and attaches the given model node to the descriptor, extracting a 
      # value based on the section_key.
      def model=(value)
        @xml, @extracted_value = nil, nil
        @model = value
        attach_model
        @model
      end
 
      # True if an xml or model node has been attached to this Descriptor.
      # Useful for distinguishing between a Descriptor with a nil
      # extracted_value and one which has never been attached.
      def attached?
        xml || model 
      end

      # A model may be flat.  Or a model may provide an accessor for a 
      # a section of a document, rather than just for fields. 
      #
      # Raises an error if no model attached.
      def model_has_section?
        raise(DescriptorError, "No model attached.") unless model
        model_has_section = accessor && model.respond_to?(accessor.to_s)
        model_has_section ||= model.kind_of?(Hash) && model.key?[accessor.to_s]
      end
 
      def index_key
        key = [parent_index_key, section_key].compact.join('_')
        key.blank? ? nil : key.to_sym
      end
  
      # If an xml node has been set for the descriptor, use the
      # descriptor's locator on it and store the result in the
      # @extracted_value attribute.  Returns the newly stored extracted_value or
      # nil.
      def extract_values_from_xml
        debug "DescriptorInitialization#extract_values_from_xml xml: #{xml.inspect}"
        self.extracted_value = xml.nil? ? nil : extract_first_node(locator) unless self.extracted_value
      end
  
      # If a model node has been set for the descriptor, call the descriptor's
      # section_key on it, or if the model is a Hash, look up the section_key,
      # and store the result in the @extracted_value attribute.
      # Returns the newly stored extracted_value or nil.
      def extract_values_from_model
        debug "DescriptorInitialization#extract_values_from_model calling: #{accessor.inspect} on model: #{model.inspect}"
        self.extracted_value = _extract_values_from_model unless extracted_value
        extracted_value
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
      def find_innermost_element(locator = self.locator, search_node = xml)
        debug("DescriptorInitialization:find_innermost_element using #{locator} in #{search_node.inspect}")
        until node = extract_first_node(locator, search_node)
          # clip off the left most [*] predicate or /* path
          md = %r{
            \[[^\]]+\]$ |
            /[^/\[]*$
          }x.match(locator)
          break if md.nil? || md.pre_match == '/'
          locator = md.pre_match
        end
        node ||= search_node 
        node = node.element if node.kind_of?(REXML::Attribute)
        node = node.parent if node.kind_of?(REXML::Text)
        return node
      end
   
      def template_id
        unless @template_id_established
          @template_id = options_by_type(:template_id)
          @template_id ||= section_key.to_s if section_key.to_s =~ /(?:\d+\.\d+)+/
          @template_id_established = true
        end
        @template_id
      end
  
      # If a locator has not been specified, we can assume a locator based on
      # the section_key, but we need to know whether to construct xpath as an
      # element or an attribute.  This returns either :element, or :attribute
      # as a guide for how to construct the locator.
      def locate_by
        options_by_type(:locate_by) || :element
      end

      # Note that the original locator accessor is aliased to :unguarded_locator
      # when DescriptorInitialization is included. 
      def guarded_locator
        return unguarded_locator if unguarded_locator
        self.locator = case 
          when template_id   
            then %Q{//#{XMLManipulation::CDA_NAMESPACE}:section[./#{XMLManipulation::CDA_NAMESPACE}:templateId[@root = '#{template_id}']]}
          when locate_by == :attribute
            then "@#{section_key.to_s.camelcase(:lower)}"
          when section_key =~ /[^\w]/
            # non word characters--asume an xpath locator is the section_key
            then section_key
          when section_key.to_s =~ /^\w+/
            # all word characters--assume an element reference
            then "#{XMLManipulation::CDA_NAMESPACE}:#{section_key.to_s.camelcase(:lower)}"
        end 
      end
 
      # Note that the original reference accessor is aliased to 
      # :unguarded_accessor when DescriptorInitialization is included.
      def guarded_accessor
        return unguarded_accessor if unguarded_accessor
        self.accessor = options[:accessor] || section_key
      end

      # True if this descriptor describes a section which must be present.
      def required?
        unless @required
          @required = options_by_type(:required)
          @required = true if @required.nil?
        end
        return @required
      end
  
      # True if this descriptor may occur one or more times.
      def repeats?
        false
      end
  
      # True if this is a field leaf node.
      def field?
        false 
      end
  
      def field_name
        section_key if field?
      end
  
      def to_s
        "<#{self.class.to_s.demodulize}:#{self.object_id} #{section_key.inspect} => #{locator.inspect}#{' {...} ' if descriptors}>"
      end
      
      def pretty_print(pp)
        had_attributes, had_descriptors = false, false 
        pp.group(2, "<#{self.class.to_s.demodulize}:#{self.object_id} #{section_key.inspect} => #{locator.inspect} :index_key => #{index_key.inspect}") do
          had_attributes = _pretty_print_attributes(pp)
          had_descriptors = _pretty_print_descriptors(pp)
        end
        pp.breakable if had_attributes || had_descriptors
        pp.text ">"
      end
  
      # Produces an unattached but instantiated copy of this descriptor and its
      # children.  (This is different than dup or clone.)
      def copy
        self.class.new(section_key, locator, options, &descriptors)
      end

      protected

      # Associates a REXML node with this Descriptor.  The tree of subdescriptors
      # will be walked and values will be set wherever we are able to match
      # locators in the given document.
      def attach_xml
        attach(:xml, xml)
      end

      def attach_model
        attach(:model, model)
      end

      def attach(mode, source)
        raise(DescriptorError, "SectionDescriptors#attach accepts only two modes: :xml or :model") unless [:xml, :model].include?(mode)
        debug "attach mode: #{mode}, source: #{source.inspect} to #{self}"
        self.send("extract_values_from_#{mode}")
        each_value { |v| v.send("#{mode}=", extracted_value || source) } if respond_to?(:each_value)
        self
      end

      private
 
      def _extract_values_from_model
        value = nil
        if model && accessor
          value = model.send(accessor.to_s) if model.respond_to?(accessor.to_s)
          value ||= model[accessor] if model.kind_of?(Hash)
          debug "DescriptorInitialization#_extract_values_from_model extracted: #{value.inspect}" if value
        end
        value
      end

      def _pretty_print_attributes(pp)
        had_attributes = false
        [:options, :xml, :model, :extracted_value].each do |m|
          if !(value = send(m)).nil? && (value.respond_to?(:empty?) ? !value.empty? : true)
            if m == :options
              value = value.reject { |k,v| k == :mapping }
              next if value.empty?
            end
            pp.breakable
            pp.text "@#{m} = "
            pp.pp value 
            had_attributes = true
          end
        end
        had_attributes
      end
  
      def _pretty_print_descriptors(pp)
        had_descriptors = false
        if respond_to?(:each)
          had_descriptors = true
          pp.breakable
          i = 1
          each do |k,v|
            pp.text "#{k.inspect} => "
            pp.pp v
            pp.breakable unless i == size
            i += 1
          end
        end
        had_descriptors
      end
    end
  end

  # Used for returning nested hashes of descriptor keys and extracted values
  # for comparison and error reporting.
  class ValuesHash < Hash

    # Collapses all nested section hashes, merging their leaf nodes into
    # a single hash.  Duplicated keys are avoided by adding the parent 
    # hash's key to the child's.  This is not foolproof but should work
    # for most descriptor schemes that don't go out of their way to violate
    # it.  This returns a new hash, it does not alter original.
    def flatten
      inject(ValuesHash.new) do |hash,pair|
        key, value = pair
        case value
          when ValuesHash then
            value.flatten.each do |child_key,child_value|
              if key?(child_key) || hash.key?(child_key)
                child_key = "#{key}_#{child_key}".to_sym
                raise(DescriptorError, "Duplicate key #{child_key} found in #{self.inspect} while attempting to flatten a ValuesHash.") if key?(child_key) || hash.key?(child_key)
              end
              hash[child_key] = child_value
            end
          else hash[key] = value
        end
        hash
      end
    end

  end

  # Base Hash implementation used by all descriptors which contain other
  # descriptors.
  class DescriptorHash < Hash
    include HashExtensions
    alias :subdescriptors :values

    # Convert from a hash of descriptors to a hash of keys and 
    # extracted values.  Useful for error reporting and comparisons.
    def to_values_hash
      values_hash = inject(ValuesHash.new) do |hash,pair|
        k, v = pair
        hash[k] = case v
          when DescriptorHash then v.to_values_hash
          else v.try(:extracted_value)
        end
        hash
      end 
    end

    # A flattened values hash (no nested hashes).
    def to_field_hash
      to_values_hash.flatten
    end
  end

  # Describes the mapping for fields and subsections of a section
  # of a component module.
  class Section < DescriptorHash 
    include DescriptorInitialization

    # Array of field section_keys used to uniquely identify a section. 
    def matches_by
      Array(options_by_type(:matches_by))
    end

  end

  class RepeatingSectionInstance < Section
    # Returns a hash of the section's matches_by keys and their values.  If any
    # key descriptor is missing or is unattached, an empty hash will be
    # returned.  All of the key descriptors must exist for a section_key to be
    # established, however any of the key values may be nil, so long as a node
    # has been attached (making it possible to have obtained a value).
    def section_key_hash
      matches_by.inject({}) do |hash,k|
        key_descriptor = descendent(k)
        unless key_descriptor && key_descriptor.attached?
          # not all key_descriptors in place yet (perhaps we are still
          # processing the descriptors)
          return {}
        else
          hash[k] = key_descriptor.extracted_value.try(:canonical)
        end
        hash
      end
    end

    alias :unguarded_section_key :section_key
    def section_key
      return unguarded_section_key if unguarded_section_key
      if key = repeating_section_instance_key
        debug("setting section_key to #{key.inspect}")
        self.section_key = key
      end
    end

    # Returns a key built from matches_by keys (optionally dereferenced) used
    # to uniquely identify an instance of a repeating section.
    def repeating_section_instance_key 
      unless matches_by.empty?
        RepeatingSectionInstance.section_key(section_key_hash)
      end
    end

    # Returns the given hash as an array of key, value pairs
    # sorted by keys.  If evaluated as strings, this keys will
    # be unique and consistently ordered.
    #
    # An empty key_values hash produces a nil section_key.
    def self.section_key(key_values)
      return nil if key_values.empty?
      key_values.to_a.sort { |a,b| a[0].to_s <=> b[0].to_s }
    end
  end

  # Describes the mapping for a section that may occur one or more times.
  class RepeatingSection < Section

    def attach(mode, source)
      raise(DescriptorError, "RepeatingSection#attach accepts only two modes: :xml or :model") unless [:xml, :model].include?(mode)
      debug "attach mode: #{mode}, source: #{source.inspect} to #{self}"
      self.send("extract_values_from_#{mode}")
      instantiate_section_nodes(mode)
      self
    end

    # If an xml node has been set for the descriptor, extract all the matching
    # nodes using the descriptor's locator and store the result in the
    # @extracted_value attribute. Returns the newly stored extracted_value
    # or nil.
    def extract_values_from_xml
      debug("extract_values_from_xml xml: #{xml.inspect}")
      self.extracted_value = (xml.nil? ? nil : extract_all_nodes(locator))
    end

    # Clears the hash (dropping any existing sections) and creates a new
    # section for each node in extracted_values.  Each node will be attached
    # and injected with associated xml or model values depending on mode. 
    def instantiate_section_nodes(mode)
      raise(DescriptorError, "RepeatingSection#instantiate_section_nodes accepts only two modes: :xml or :model") unless [:xml, :model].include?(mode)
      debug "instantiate_section_nodes mode: #{mode}"
      clear
      (Array(extracted_value || send(mode))).try(:each_with_index) do |node,i|
        node_position = i + 1
        debug("instantiate_section_node node ##{node_position} -> #{node.inspect}")
        section_locator = "#{locator}[#{node_position}]"
        section = DSL.create(:repeating_section_instance, nil, section_locator, :logger => logger, :mapping => mapping_class, :matches_by => matches_by, &descriptors)
        section.parent = self # without this, we can't access root options like :validation_type
        section.send("#{mode}=", node)
        section.extracted_value = node unless section.extracted_value
        section.section_key = section.locator unless section.section_key
        store(section.section_key, section)
      end
    end

    # True if this descriptor may occur one or more times.
    def repeats?
      true 
    end

  end

  # Wrapper around field node values used to compare and convert. 
  class FieldValue < SimpleDelegator
    
    # Returns the authoritative string form of a Laika value.
    def canonical
      case internal = __getobj__ 
        when String then internal
        when Date then internal.to_formatted_s(:brief)
        else internal.to_s
      end
    end

    def ==(other)
      case
        when nil?
          then other.nil? || other == ""
        when other.kind_of?(FieldValue)
          then canonical == other.canonical
        else
          __getobj__.==(other) 
      end 
    end

    def nil?
      __getobj__.nil?
    end

    # SimpleDelegator seems to short circuit try() by sending it strait to the
    # to the internal reference.
    def try(method)
      send(method) if respond_to?(method)
    end

  end

  # Describes the mapping for a single field.
  class Field
    include DescriptorInitialization
    include InstanceEquality
    
    equality_and_hashcode_from :section_key, :locator, :options

    # If an xml node has been set for the descriptor, extract the textual value
    # of the descriptor's locator and store the result in the @extracted_value
    # attribute.  Returns the newly stored extracted_value or nil.
    def extract_values_from_xml
      debug("Field#extract_values_from_xml xml: #{xml.inspect}")
      unless extracted_value || xml.nil? || locator.nil?
        value = dereference? ? dereference(extract_first_node(locator)) : extract_node_value(locator)
        # since we have both xml and locator , a nil is the real return value
        # and should be wrapped just like any other
        self.extracted_value = FieldValue.new(value)
      end
      extracted_value
    end

    def extract_values_from_model
      debug("Field#extract_values_from_model calling #{accessor.inspect} on model: #{model.inspect}")
      unless extracted_value || model.nil? || accessor.nil?
        value = _extract_values_from_model
        # since we have both model and accessor, a nil is the real return value
        # and should be wrapped just like any other
        self.extracted_value = FieldValue.new(value)
      end
      extracted_value
    end

    # True if this is a field leaf node.
    def field?
      true 
    end
 
    # True if we need to dereference the xml value for this field when extracting.
    def dereference?
      options_by_type(:dereference)
    end
 
  end

  # Captures all of the information needed to describe a Component.
  # Calling instantiate() will return a new Component
  class ComponentDefinition
    include InstanceEquality

    equality_accessors :descriptor_args, :component_options, :descriptors

    def initialize(descriptor_args, component_options, &descriptors)
      self.descriptor_args = descriptor_args
      self.component_options = component_options
      self.descriptors = descriptors
    end

    def instantiate(options = {})
      ComponentModule.new(descriptor_args, component_options.merge(options), &descriptors)
    end

  end

  # Describes the mapping between key sections and fields of one component module
  # from a patient document.  This is a wrapper class around the root descriptor
  # intended to provide a uniform handle on any base component module.
  class ComponentModule < SimpleDelegator
    include OptionsParser 
    include Logging

    attr_accessor :original_arguments, :repeats, :component_descriptors, :root_descriptor

    def initialize(*args, &descriptors)
      self.original_arguments = args
      key, locator, options = parse_args(args)
      self.repeats = options.delete(:repeats)
      self.logger = options[:logger]
      self.component_descriptors = descriptors
      # XXX make this safer then a private call into the DSL module...factory method?
      self.root_descriptor = ComponentDescriptors::DSL.create(repeats? ? :repeating_section : :section, key, locator, options, &descriptors)
      super(root_descriptor)
      self
    end

    def name
      root_descriptor.section_key
    end
 
    def repeats?
      @repeats
    end

    def to_s
      root_descriptor.to_s
    end

    # Create an unattached copy of the ComponentModule
    def copy
      ComponentModule.new(*original_arguments, &component_descriptors)
    end

  end

end
