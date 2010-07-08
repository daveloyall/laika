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
# Every descriptor has a key which uniquely identifies it within its current
# section.  This key serves as the method used to look up a matching element in
# an object model of the patient document.  Every descriptor also has an xpath
# locator, either explictly declared or implicit from the key, which is used to
# identify a node within the document.  These locators nest.  So a descriptor's
# locator is within the context of it's parent's xml node (as identified by the
# parent's locator), and so on, up to the root section, whose context is the
# document.
module ComponentDescriptors

  def self.included(base)
    base.extend(ClassMethods)
  end

  class DescriptorError < RuntimeError; end
  class DescriptorArgumentError < DescriptorError; end

  module ClassMethods

    def descriptors
      @descriptors_map = {} unless @descriptors_map
      return @descriptors_map
    end
 
    # Declares a component module.
    def components(name, *args, &descriptors)
      self.descriptors[name] = ComponentDefinition.new(name, *args, &descriptors)
    end

    def get_component(name)
      descriptors[name].instantiate if descriptors.key?(name)
    end

  end

  # Included by all classes which describe some section of an xml patient document.
  module SectionDescriptors

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

    # Associates a REXML node with this Descriptor.  The tree of subdescriptors
    # will be walked and values will be set wherever we are able to match
    # locators in the given document.
    def attach_xml(xml)
      attach(:xml, xml.kind_of?(REXML::Document) ? xml.root : xml)
    end

    def attach_model(model)
      attach(:model, model)
    end

    def attach(mode, source)
      raise(DescriptorError, "SectionDescriptors#attach accepts only two modes: :xml or :model") unless [:xml, :model].include?(mode)
      debug "SectionDescriptors:attach mode: #{mode}, source: #{source.inspect}"
      self.send("#{mode}=", source)
      self.send("extract_values_from_#{mode}")
      each_value { |v| v.attach(mode, extracted_value || source) } if respond_to?(:each_value)
      self
    end

    # Produces an unattached but instantiated copy of this descriptor and its
    # children. 
    def copy
      self.class.new(key, locator, options, &descriptors)
    end

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
    def parse_args(args, known_keys)
      known_keys = Array(known_keys)

      validate = lambda do |arguments|
        raise(DescriptorArgumentError, "No arguments given.") if arguments.empty?
        raise(DescriptorArgumentError, "Two many arguments given (expected two at most): #{arguments.inspect}") if arguments.size > 2
      end
      validate.call(args)

      first, options = args
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
          raise(DescriptorArgumentError, "Ambiguous arguments.  Too any options left in #{first.inspect} to identify the key and locator values.") if first.size > 1
          key, locator = first.shift
        else key = first
      end
 
      options.merge!(injected_options) if injected_options
      return key, locator, options
    end

    private
 
    def _initialize_subsections
      instance_eval(&descriptors) if descriptors
    end

    def _instantiate_and_store(type, *args, &descriptors)
      key, locator, options = parse_args(args, :required)
      store(key, _instantiate(type, key, locator, options, &descriptors))
      self
    end

    def _instantiate(type, key, locator, options, &descriptors)
      "ComponentDescriptors::#{type.to_s.classify}".constantize.send(:new, key, locator, options, &descriptors)
    end
  end

  module NodeManipulation

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
        debug("_extract_nodes: extracted #{result.inspect}")
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

    # Returns the first descendent matching the given key or nil.
    def descendent(key)
      return nil unless respond_to?(:fetch)
      unless descendent = fetch(key, nil)
        values.each do |v|
          raise(NoMethodError, "Node #{v} does not respond to descendent()") unless v.respond_to?(:descendent)
          descendent = v.descendent(key)
          break unless descendent.nil?
        end
      end
      return descendent 
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

  module DescriptorInitialization

    def self.included(base)
      base.class_eval do
        attr_accessor :key, :options, :descriptors, :xml, :model, :extracted_value
        attr_writer :locator
        include SectionDescriptors
        include NodeManipulation
        include NodeTraversal
        include Logging
      end
    end

    def initialize(key, locator, options, &descriptors)
      self.key = key
      self.locator = locator
      self.options = options || {}
      self.logger = self.options[:logger]
      self.descriptors = descriptors
      _initialize_subsections
    end

    # If an xml node has been set for the descriptor, use the
    # descriptor's locator or key on it and store the result in the
    # @extracted_value attribute.  Returns the newly stored extracted_value or
    # nil.
    def extract_values_from_xml
      debug "DescriptorInitialization:extract_values_from_xml xml: #{xml.inspect}"
      self.extracted_value = xml.nil? ? nil : extract_first_node(locator) unless self.extracted_value
    end

    # If a modle node has been set for the descriptor, call the descriptor's
    # key on it and store the result in the @extracted_value attribute.
    # Returns the newly stored extracted_value or nil
    def extract_values_from_model
      debug "DescriptorInitialization:extract_values_from_model model: #{model.inspect}"
      self.extracted_value = model.nil? ? nil : model.send(key) unless self.extracted_value || !model.respond_to?(key)
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
        @template_id = options[:template_id]
        @template_id ||= key.to_s if key.to_s =~ /(?:\d+\.\d+)+/
        @template_id_established = true
      end
      @template_id
    end

    # If a locator has not been specified, we can assume a locator based on the 
    # key, but we need to know whether to construct xpath as an element or an 
    # attribute.  This returns either :element, or :attribute as a guide for
    # how to construct the locator.
    def locate_by
      options[:locate_by] || :element
    end

    def locator
      unless @locator
        if template_id   
          @locator = %Q{//#{NodeManipulation::CDA_NAMESPACE}:section[./#{NodeManipulation::CDA_NAMESPACE}:templateId[@root = '#{template_id}']]}
        elsif locate_by == :attribute
          @locator = "@#{key.to_s.camelcase(:lower)}"
        elsif key =~ /[^\w]/
          # non word characters--asume an xpath locator is the key
          @locator = key
        else
          @locator = "#{NodeManipulation::CDA_NAMESPACE}:#{key.to_s.camelcase(:lower)}"
        end 
      end
      @locator
    end

    # True if this descriptor describes a section which must be present.
    def required?
      unless @required
        pp 'required', options
        @required = options[:required]
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
      key if field?
    end

    def to_s
      "<#{self.class}:#{self.object_id} #{key} => #{locator} #{' {...} ' if descriptors}>"
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

  # Describes the mapping for key fields and subsections of a section
  # of a component module.
  class Section < DescriptorHash 
    include DescriptorInitialization

    # Array of field keys used to uniquely identify a section. 
    def matches_by
      Array(options[:matches_by])
    end

    # If true, then a section is identified by dereferencing a pointer
    # attribute ('//reference/@value') which matches the @ID of an element
    # in the main document whose text value is the key needed to match.
    def matches_by_reference?
      options[:matches_by_reference]
    end

    # Returns a hash of the section's matches_by keys and their values.
    def section_key_hash
      matches_by.inject({}) do |hash,k| 
        hash[k] = descendent(k).extracted_value
        hash
      end
    end

    # Returns a string built from matches_by keys (optionally dereferenced) used
    # to uniquely identify a section.
    def section_key 
      if matches_by_reference?
        raise('implement me')
      elsif !matches_by.empty?
        Section.section_key(section_key_hash)
      end
    end

    def self.section_key(key_values)
      key_values.keys.sort.map do |key|
        "#{key}:#{key_values[key]}"
      end.join("__")
    end
  end

  # Describes the mapping for a section that may occur one or more times.
  class RepeatingSection < Section

    def _initialize_subsections
      section(:_repeating_section_template, &descriptors) if descriptors 
    end
  
    def attach(mode, source)
      raise(DescriptorError, "RepeatingSection#attach accepts only two modes: :xml or :model") unless [:xml, :model].include?(mode)
      debug "RepeatingSection:attach mode: #{mode}, source: #{source.inspect}"
      self.send("#{mode}=", source)
      self.send("extract_values_from_#{mode}")
      instantiate_section_nodes(mode)
      self
    end

    # If an xml node has been set for the descriptor, extract all the matching
    # nodes using the descriptor's locator and store the result in the
    # @extracted_value attribute. Returns the newly stored extracted_value
    # or nil.
    def extract_values_from_xml
      debug("RepeatingSection#extract_values_from_xml xml: #{xml.inspect}")
      self.extracted_value = (xml.nil? ? nil : extract_all_nodes(locator))
    end

    # Clears the hash (dropping any existing sections) and creates a new
    # section for each node in extracted_values.  Each node will be attached
    # and injected with associated xml values. 
    def instantiate_section_nodes(mode)
      raise(DescriptorError, "RepeatingSection#instantiate_section_nodes accepts only two modes: :xml or :model") unless [:xml, :model].include?(mode)
      debug "RepeatingSection:instantiate_section_nodes mode: #{mode}"
      clear
      (extracted_value || send(mode)).try(:each_with_index) do |node,i|
        node_position = i + 1
        debug("RepeatingSection#instantiate_section_node node ##{node_position} -> #{node.inspect}")
        section = _instantiate(:section, nil, nil, :matches_by => matches_by, :matches_by_reference => matches_by_reference?, &descriptors)
        section.extracted_value = node 
        section.attach(mode, node)
        section.locator = "#{locator}[#{node_position}]"
        key = section.section_key || section.locator
        section.key = key 
        store(key, section)
      end
    end

    # Returns a hash of key values from the passed model; one value
    # for each entry in matches_by() which the model responds to.
    def get_section_key_hash_from(model)
      matches_by.inject({}) do |hash,k| 
        v = model.send(k) if model.respond_to?(k)
        hash[k] = v
        hash
      end
    end

    # Looks up matches_by key value(s) in the passed model and returns
    # the section whose key matches or nil if there is no match.
    def find_matching_section_for(model)
      fetch(Section.section_key(get_section_key_hash_from(model)), nil)
    end

    # True if this descriptor may occur one or more times.
    def repeats?
      true 
    end
  end

  # Describes the mapping for a single field.
  class Field
    include DescriptorInitialization
    include InstanceEquality
    
    equality_and_hashcode_from :key, :locator, :options

    # If an xml node has been set for the descriptor, extract the textual value
    # of the descriptor's locator and store the result in the @extracted_value
    # attribute.  Returns the newly stored extracted_value or nil.
    def extract_values_from_xml
      debug("Field#extract_values_from_xml xml: #{xml.inspect}")
      self.extracted_value = xml.nil? ? nil : extract_node_value(locator) unless self.extracted_value
    end

    # True if this is a field leaf node.
    def field?
      true 
    end
  end

  # Captures all of the information needed to describe a Component.
  # Calling instantiate() will return a new Component
  class ComponentDefinition
    include InstanceEquality

    equality_accessors :name, :args, :descriptors

    def initialize(name, *args, &descriptors)
      self.name = name
      self.args = args
      self.descriptors = descriptors
    end

    def instantiate
      Component.new(name, *args, &descriptors)
    end

  end

  # Describes the mapping between key sections and fields of one component module
  # from a patient document. 
  class Component < DescriptorHash
    include SectionDescriptors
    include NodeTraversal
    include Logging

    attr_accessor :name, :options, :template_id, :validation_type, :xml, :model, :descriptors

    def initialize(name, *args, &descriptors)
      self.options = args.first || {}
      self.name = name
      self.template_id = options[:template_id]
      self.validation_type = options[:validation_type]
      self.logger = options[:logger]
      self.descriptors = descriptors
      if template_id
        section(template_id, &descriptors)
      else
        _initialize_subsections
      end
    end

    # Associates a REXML document or gold modle with this component.  The tree
    # of descriptors will be walked and values will be set wherever we are able
    # to match locators/keys in the given document.
    def attach(mode, source)
      raise(DescriptorError, "Component#attach accepts only two modes: :xml or :model") unless [:xml, :model].include?(mode)
      debug "Component:attach mode: #{mode}, source: #{source.inspect}"
      self.send("#{mode}=", source)
      each_value { |v| v.attach(mode, source) }
      self
    end

    # No xml parsing for the base component.
    def error?
      false
    end

    # Component Modules are required.
    def required?
      true
    end

    def copy
      Component.new(name, options, &descriptors)
    end

  end

end
