module Laika

  # Adds a class macro for defining accessors which read and write from an
  # instance variable hash.
  module AttributesHashAccessor
    def self.included(mod)
      mod.extend(ClassMethods)
    end
  
    protected

    def attributes_hash
      @__attributes_hash
    end

    private

    def _initialize_attributes_hash
      @__attributes_hash = {}
    end  

    def _initialize_attributes_hash_unless_exists
      _initialize_attributes_hash unless @__attributes_hash
    end
 
    public
   
    module ClassMethods
      def attr_hash_accessor(*args)
        args.each do |m|
          define_method(m) do 
            _initialize_attributes_hash_unless_exists
            @__attributes_hash[m]
          end
          define_method("#{m}=") do |value|
            _initialize_attributes_hash_unless_exists
            @__attributes_hash[m] = value
          end
        end
      end
    end
  end

  # Classes used to record errors and warnings produced by Validators.
  class ValidationError
    include Laika::AttributesHashAccessor

    attr_hash_accessor :section, :subsection, :field_name, :message, :location, :severity, :validator, :inspection_type, :error_type
    attr_accessor :suberrors

    def initialize(attributes = {})
      self.suberrors = []
      self.from_hash(attributes)
    end

    # Allows you to initialize this instance with a hash.  Any publically accessible attribute
    # writer methods may be set.  Returns self to allow chaining.
    def from_hash(attributes = {})
      attributes.each do |key, value|
        writer = "#{key}="
        send(writer, value) if respond_to?(writer) && self.class.public_method_defined?(writer)
      end
      return self
    end

    # Returns the ValidationError's attributes as a hash.
    def to_hash
      self.attributes_hash || {}
    end
  end

  # A ValidationError caused by comparing an expected field value with the provided field
  # value.
  class ComparisonError < ValidationError
    attr_hash_accessor :expected, :provided
  end

  # A ValidationError caused by inability to match an expected section with a provided
  # document section.
  class SectionMissing < ValidationError
    attr_hash_accessor :expected_section, :provided_sections
  end

end
