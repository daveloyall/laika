# In order to be able to parse and validate a particular form of XML based
# medical document, we need to be able to describe the logical components of
# the document such that we can extract key fields for comparison with or
# export to some other model.
#
# components - a base component module of a patient document, like medications or allergies.
#
# section - a node in the document which may contain other sections or fields.
#
# repeating_section - a section which may occur one or more times, keyed by a value or set of values.
#
# field - a value in the document.
#
# attribute - shortcut for a field whose xpath locator is simply the key value
# as an attribute of the current node ("@#{key}").
#
# Every descriptor has a key which uniquely identifies it within its current section.  This key
# serves as the method used to look up a matching element in an object model of the patient
# document.  Every descriptor also has an xpath locator, either explictly
# declared or implicit from the key, which is used to identify a node within
# the document.  These locators nest.  So a descriptor's locator is within the
# context of it's parent's xml node (as identified by the parent's locator),
# and so on, up to the root section, whose context is the document.
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
      descriptors[name].instantiate
    end

  end

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
    # will be walked and values will be set wherever we are able to match locators in
    # the given document.
    def attach(xml)
      self.xml = xml
      extract_values_from_xml
      each_value { |v| v.attach(extracted_value) } if respond_to?(:each_value)
    end

    # Parses the different argument styles accepted by section/field methods.
    #
    # method(:key)
    # method(:key, :option => :foo)
    # method(:key => :locator, :option => :foo)
    # method([...original arguments...], :injected => :options)
    #
    # (The last variation is used internally by methods which need to inject additional
    # options into the call.  The original arguments are passed as an array, with additional
    # options as a final hash argument)
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
    def dereference_sections(section_key = section, nodes = nil)
      debug("dereference(#{section_key}, #{nodes.inspect})")
      nodes ||= xml_section_nodes
      nodes.inject({}) do |hash,section|
        debug("dereference section: #{section.inspect}")
        if reference = extract_first_node(".//#{CDA_NAMESPACE}:reference[@value]", section)
          debug("dereference reference: #{reference.inspect}")
          if name = extract_first_node("//[@ID=#{reference.attributes['value'].gsub("#",'')}]/text()", root_element)
            debug("dereference name: #{name.inspect}")
            hash[name.value] = section
          end
        end
        hash
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

  module Logging

    FALLBACK = STDERR

    def self.included(base)
      base.send(:attr_writer, :logger)
    end

    [:debug, :info, :warn, :error, :fatal].each do |level|
      define_method(level) do |message|
        _log(level, message)
      end
    end
  
    def logger
      @logger || (root? ? nil : root.logger)
    end
 
    private

    def _log(severity, original_message)
      message = "ComponentDescriptors : #{original_message}"
      if logger
        logger.send(severity, message)
      else
        FALLBACK.puts "#{severity.to_s.upcase} : #{message}"
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

    # Returns the first descendant matching the given key or nil.
    def descendant(key)
      return nil unless respond_to?(:fetch)
      descendant = fetch(key) if self.key?(key)
      values.each do |v|
        raise(NoMethodError, "Node #{v} does not respond to descendant()") unless v.respond_to?(:descendant)
        descendant = v.descendant(key)
        break unless descendant.nil?
      end unless descendant
      return descendant 
    end
    
  end

  # Extensions to Hash used by node descriptors to keep track of parents.
  module HashExtensions
    # Ensure that we keep a reference to the parent hash when new elements are stored. 
    def store(key, value)
      value.parent = self
      super
    end
  end

  module DescriptorInitialization

    def self.included(base)
      base.class_eval do
        attr_accessor :key, :options, :descriptors, :xml, :extracted_value
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

    # If an xml node has been set for the descriptor, use the descriptor's
    # locator on it and store the result in the @extracted_value attribute.
    # Returns the newly stored extracted_value or nil.
    def extract_values_from_xml
      debug "DescriptorInitialization:extract_values_from_xml xml: #{xml.inspect}"
      self.extracted_value = xml.nil? ? nil : extract_first_node(locator) unless self.extracted_value
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
        else
          @locator = "#{NodeManipulation::CDA_NAMESPACE}:#{key.to_s.camelcase(:lower)}"
        end 
      end
      @locator
    end
  end

  # Describes the mapping for key fields and subsections of a section
  # of a component module.
  class Section < Hash
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

    # Returns a string built from matches_by keys (optionally dereferenced) used
    # to uniquely identify a section.
    def matches_key
      if matches_by_reference?
        raise('implement me')
      elsif !matches_by.empty?
        matches_by.map do |key|
          "#{key}:#{descendent(key).extracted_value}"
        end.join("__")
      end
    end
  end

  # Describes the mapping for a section that may occur one or more times.
  class RepeatingSection < Section

    def _initialize_subsections
      section(:_repeating_section_template, &descriptors) if descriptors 
    end
  
    def attach(xml)
      self.xml = xml
      extract_values_from_xml
      instantiate_section_nodes
    end

    # If an xml node has been set for the descriptor, extract all the matching
    # nodes using the descriptor's locator and store the result in the
    # @extracted_value attribute.  We then clear and rebuild the sections based on the
    # actual document nodes.  Returns the newly stored extracted_value or
    # nil.
    def extract_values_from_xml
      debug("RepeatingSection#extract_values_from_xml xml: #{xml.inspect}")
      self.extracted_value = (xml.nil? ? nil : extract_all_nodes(locator))
    end

    # Clears the hash (dropping any existing sections) and creates a new
    # section for each node in extracted_values.  Each node will be attached
    # and injected with associated xml values. 
    def instantiate_section_nodes
      clear
      self.extracted_value.each_with_index do |node,i|
        node_position = i + 1
        debug("RepeatingSection#instantiate_section_node node ##{node_position} -> #{node}")
        section = _instantiate(:section, nil, nil, :matches_by => matches_by, :matches_by_reference => matches_by_reference?, &descriptors)
        section.extracted_value = node 
        section.attach(xml)
        section.locator = "#{locator}[#{node_position}]"
        key = section.matches_key || section.locator
        section.key = key 
        store(key, section)
      end
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
  class Component < Hash
    include SectionDescriptors
    include NodeTraversal
    include Logging

    attr_accessor :name, :template_id, :validation_type, :document, :descriptors

    def initialize(name, *args, &descriptors)
      options = args.first || {}
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

    # Associates a REXML document with this component.  The tree of descriptors
    # will be walked and values will be set wherever we are able to match locators in
    # the given document.
    def attach(document)
      self.document = document
      each_value { |v| v.attach(document) }
    end

  end

end
