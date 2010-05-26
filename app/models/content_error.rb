# Keeps state for any error produced by Validators when validating a particular test plan.
class ContentError < ActiveRecord::Base
  belongs_to :test_plan

  acts_as_tree 

  serialize :expected_section, Hash
  serialize :provided_sections, Array
  serialize :exception, Exception

  validates_presence_of :validator

  state_machine :initial => :failed do
    event :pass do
      transition all => :passed
    end
    event :fail do
      transition all => :failed
    end
    event :review do
      transition all => :review
    end
  end

  # Class methods for ContentError
  class << self
 
    # Constructor for generating a ContentError from a Laika::ValidationError.
    # May throw an ActiveRecord exception if unable to save!
    def from_validation_error!(validation_error)
      error = ContentError.new(
        :section          => validation_error.section,
        :subsection       => validation_error.subsection,
        :field_name       => validation_error.field_name,
        :error_message    => validation_error.message,
        :location         => validation_error.location,
        :msg_type         => validation_error.severity,
        :validator        => validation_error.validator,
        :inspection_type  => validation_error.inspection_type,
        :error_type       => validation_error.class.to_s.demodulize,
        :exception        => validation_error.exception
      )
      [:expected, :provided, :expected_section, :provided_sections].each do |m|
        error.send("#{m}=", validation_error.send(m)) if validation_error.respond_to?(m)
      end
      error.save!
      error.review! if validation_error.kind_of?(Laika::ComparisonError)
      validation_error.suberrors.each { |sub| error.children << ContentError.from_validation_error!(sub) } 
      return error
    end

  end
end
