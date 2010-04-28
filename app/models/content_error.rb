# Keeps state for any error produced by Validators when validating a particular test plan.
class ContentError < ActiveRecord::Base
  belongs_to :test_plan

  acts_as_tree 

  serialize :expected_section, Hash
  serialize :provided_sections, Array

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

end
