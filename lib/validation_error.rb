module Laika

  # Classes used to record errors and warnings produced by Validators.
  class ValidationError
    include Laika::AttributesHashAccessor

    attr_hash_accessor :section, :subsection, :field_name, :message, :location, :severity, :validator, :inspection_type, :exception
    attr_accessor :suberrors

    def initialize(attributes = {})
      self.suberrors = []
      self.attributes=(attributes)
    end

    # True if this error should be manually reviewed.
    def review?
      false
    end
  end

  class ReviewableError < ValidationError
    def review?
      true
    end
  end

  # A ValidationError caused by comparing an expected field value with the
  # provided field value.
  class ComparisonError < ReviewableError
    attr_hash_accessor :expected, :provided
  end

  # Expected section cannot be matched with any of the provided sections
  # of the same type in the given document.
  class NoMatchingSection < ReviewableError
    attr_hash_accessor :expected_section, :provided_sections
  end

  # Section cannot be located in the document.
  class SectionNotFound < ValidationError
    attr_hash_accessor :locator
  end

end
