# Copyright Josh Partlow 2010

# This module provides a class method macro for defining ==, eql?
# and hashcode methods based on a specified set of instance
# variables.
#
# class Foo
#   attr_accessors :bar, :baz
#   extend InstanceEquality
#   equality_and_hashcode_from :bar, :baz
#
#   ...
#
# end
#
# a,b = Foo.new, Foo.new
# a.bar = b.bar = 1
# a.baz = b.baz = 2
#
# a == b # => true
# a.eql?(b) # => true
# a.hashcode == b.hashcode # => true
#
# also reflexive and transitive, but not subclasses.  Classes must
# be equal.
module InstanceEquality

  def self.included(klass)
    klass.extend(ClassMethods)
  end   

  module ClassMethods

    # Creates accessors, per attr_accessor, for each of the passed
    # arguments, and then adds ==, eql? and hashcode methods per
    # equality_and_hashcode_from().
    #
    # May be given an options hash.
    def equality_accessors(*args)
      options = _equality_extract_options(args)
      args.each { |a| self.send(:attr_accessor, a.to_sym) }
      equality_and_hashcode_from(*(args.push(options)))
    end
   
    # Adds ==, eql? and hashcode methods to the current class.
    #
    # Accepts an array of symbols representing accessors for instance
    # attributes that are considered to be factors determining equality
    # between two instances of a the class.
    #
    # A terminal option hash may be provided.
    #
    # Options:
    # * :hashcode_prime => a prime number used to offset values for the
    #   hashcode.  If none is given, 17 will be used.
    # 
    # For example:
    #
    # class Star
    #   attr_accessor :mass, :age, :ascension, :declination, :name
    #   include InstanceEquality
    #   equality_and_hash_code_from :mass, :age, :ascension, :declination,
    #     :hashcode_prime => 31
    # end
    #   
    def equality_and_hashcode_from(*args)
      hashcode_prime = _equality_extract_options(args)[:hashcode_prime] || 17
  
      unless args.empty?

        define_method(:==) do |other|
          return true if self.equal?(other)
          return self.class == other.class &&
            args.all? { |a| self.send(a) == other.send(a) }
        end
    
        define_method(:eql?) do |other|
          return true if self.equal?(other)
          return self.class.eql?(other.class) &&
            args.all? { |a| self.send(a).eql?(other.send(a)) }
        end
        
        define_method(:hash) do
          hashcode = hashcode_prime * self.send(args[0]).hash
          args[1..args.size-1].each { |a| hashcode = hashcode_prime * ((hashcode << 2) + (hashcode >> 2)) + self.send(a).hash }
          return hashcode
        end

      end
    end

    # Pops off the last Hash in an array of arguments.  Will return
    # an empty Hash if no Hash in found the passed array.
    def _equality_extract_options(args)
      (args.pop if args.last.kind_of?(Hash)) || {}
    end
 
    private :equality_accessors, :equality_and_hashcode_from, :_equality_extract_options

  end # module ClassMethods
end
