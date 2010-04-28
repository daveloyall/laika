class ContentError < ActiveRecord::Base
  belongs_to :test_plan

  acts_as_tree 

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
