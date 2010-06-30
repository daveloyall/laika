# In order to be able to parse and validate a particular form of XML based
# medical document, we need to be able to describe the logical components of
# the document such that we can extract key fields for comparison with or
# export to some other model.
#
# components
#
# section_array
#
# section
#
# field 
#
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
  
    def components(name, *args, &subdescriptors)
      descriptors[name] = Component.new(name, *args, &subdescriptors)
    end

  end

  module SectionDescriptors

    def section(*args, &subdescriptors)
      _instantiate(:section, *args, &subdescriptors)
    end

    def section_array(*args, &subdescriptors)
      _instantiate(:section_array, *args, &subdescriptors)
    end
 
    def field(*args)
      _instantiate(:field, *args)
    end

    def dereference(*args)
      store(:dereference_me, nil)
    end
 
    # Parses the different argument styles accepted by section/field methods.
    #
    # method(:key)
    # method(:key, :option => :foo)
    # method(:key => :locator, :option => :foo)
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
      raise(DescriptorArgumentError, "No arguments given.") if args.empty?
      raise(DescriptorArgumentError, "Two many arguments given (expected two at most): #{args.inspect}") if args.size > 2
      first, options = args
      locator, key = nil, nil
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
  
      return key, locator, options
    end

    private

    def _initialize_subsections(&subdescriptors)
      instance_eval(&subdescriptors) if block_given?
    end

    def _instantiate(type, *args, &subdescriptors)
      key, locator, options = parse_args(args, :required)
      store(key, "ComponentDescriptors::#{type.to_s.classify}".constantize.send(:new, key, locator, options, &subdescriptors))
      self
    end

  end

  module DescriptorInitialization

    def self.included(base)
      base.class_eval do
        include SectionDescriptors
        attr_accessor :key, :locator, :options
      end
    end

    def initialize(key, locator, options, &subdescriptors)
      self.key = key
      self.locator = locator
      self.options = options || {}
      _initialize_subsections(&subdescriptors)
    end

  end

  class Section < Hash
    include DescriptorInitialization
  end

  class SectionArray < Hash
    include DescriptorInitialization

    def import(fragment)
      raise "implement me"
    end
  end

  class Field
    include DescriptorInitialization
    include InstanceEquality
    
    equality_and_hashcode_from :key, :locator, :options
  end
 
  class Component < Hash
    include SectionDescriptors

    attr_accessor :name, :template_id

    def initialize(name, *args, &subdescriptors)
      options = args.first || {}
      self.name = name
      self.template_id = options[:template_id]
      if template_id
        section(template_id, &subdescriptors)
      else
        _initialize_subsections(&subdescriptors)
      end
    end

  end

end
