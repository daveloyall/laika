class InformationSource < ActiveRecord::Base  
  strip_attributes!
    
  belongs_to :patient_data  
  include PersonLike
  
end
