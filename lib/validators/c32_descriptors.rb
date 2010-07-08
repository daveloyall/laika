module Validators
  module C32Descriptors
    include ComponentDescriptors
  
    # need to be able to identify whether we are locating a single element or
    # an array of similar elements
  
    components :languages do
      repeating_section %q{//cda:recordTarget/cda:patientRole/cda:patient/cda:languageCommunication}, :matches_by => :language_code do
        field :language_code => %q{cda:languageCode/@code}
        field :language_ability_mode => %q{cda:modeCode/@code}, :required => false
        field :preference_id => %q{cda:preferenceInd/@value}, :required => false
      end
    end
  
    components :healthcare_providers do
      repeating_section %q{//cda:documentationOf/cda:serviceEvent/cda:performer}, :matches_by => [:first_name, :last_name] do
        section :provider_role => %q{cda:functionCode}, :required => false do
          attribute :code
          field :name => %q{@displayName}
        end
        section :time do
          field :start_service => %q{cda:low/@value}
          field :end_service => %q{cda:high/@value}
        end
        section :assigned_entity do
          section :provider_type => %q{cda:code}, :required => false do
            attribute :code
            field :name => %q{@displayName}
          end
          section :assigned_person => %q{cda:assignedPerson/cda:name}, :required => false do
            field :name_prefix => %q{cda:prefix}
            field :first_name => %q{cda:given[1]} 
            field :middle_name => %q{cda:given[2]} 
            field :last_name => %q{cda:family} 
            field :name_suffix => %q{cda:suffix}
          end
          section :address => %q{cda:addr}, :required => false do
            field :street_address_line_one => %q{cda:streetAddressLine[1]}
            field :street_address_line_two => %q{cda:streetAddressLine[2]}
            field :city
            field :state
            field :postal_code
            field :iso_country_code => %q{cda:country}
          end
  #        # 'with' is transparent to the output, unlike 'section'
  #        with :telecom => %q{cda:telecom}, :required => :false do
  #          field :home_phone => %q{[@use='hp'}, :validates => :match_telecom_as_hp
  #          field :work_phone => %q{[@use='wp'}, :validates => :match_telecom_as_wp
  #          field :mobile_phone => %q{[@use='mc'}, :validates => :match_telecom_as_mc
  #          field :vacation_home_phone => %q{[@use='hv'}, :validates => :match_telecom_as_hv
  #          field :email => %q{[@use='email'}, :validates => :match_telecom_as_email
  #        end
          field :patient_identifier => %q{sdtc:patient/sdtc:id/@root}, :required => false 
        end
      end
    end
  
    components :medications, :template_id => '2.16.840.1.113883.10.20.1.8' do
      repeating_section %q{cda:entry/cda:substanceAdministration}, :matches_by => :product_coded_display_name, Validation::C32_V2_5_TYPE => { :matches_by_reference => true } do
        field :product_coded_display_name => %q{cda:consumable/cda:manufacturedProduct/cda:manufacturedMaterial/cda:code/cda:originalText/text()}
        section :consumable do
          section :manufactured_product do
            field :free_text_brand_name => %q{cda:manufacturedMaterial/cda:name}
          end
        end
        field :medication_type => %q{cda:entryRelationship[@typeCode='SUBJ']/cda:observation[cda:templateId/@root='2.16.840.1.113883.3.88.11.32.10']/cda:code/@displayName}
        field :status => %q{cda:entryRelationship[@typeCode='REFR']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.1.47']/cda:statusCode/@code}
        section :order => %q{cda:entryRelationship[@typeCode='REFR']/cda:supply[@moodCode='INT']}, :required => false do
          field :quantity_ordered_value => %q{cda:quantity/@value}
          field :expiration_time => %q{cda:effeciveTime/@value}
        end
      end
    end
  
    components :allergies, :template_id => '2.16.840.1.113883.10.20.1.2' do
      repeating_section %q{cda:entry/cda:act[cda:templateId/@root='2.16.840.1.113883.10.20.1.27']/cda:entryRelationship[@typeCode='SUBJ']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.1.18']}, :matches_by => :free_text_product do
        field :free_text_product => %q{cda:participant[@typeCode='CSM']/cda:participantRole[@classCode='MANU']/cda:playingEntity[@classCode='MMAT']/cda:name/text()}
        field :start_event => %q{cda:effectiveTime/cda:low/@value}
        field :end_event => %q{cda:effectiveTime/cda:high/@value}
        field :product_code => %q{cda:participant[@typeCode='CSM']/cda:participantRole[@classCode='MANU']/cda:playingEntity[@classCode='MMAT']/cda:code[@codeSystem='2.16.840.1.113883.6.88']/@code}
      end
    end
  
    components :insurance_providers, :template_id => '2.16.840.1.113883.10.20.1.9' do
      repeating_section %q{cda:entry/cda:act[cda:templateId/@root='2.16.840.1.113883.10.20.1.20']/cda:entryRelationship/cda:act[cda:templateId/@root='2.16.840.1.113883.10.20.1.26']} do
        field :group_number => %q{cda:id/@root}, :required => false
        section :insurance_type => %q{cda:code[@codeSystem='2.16.840.1.113883.6.255.1336']}, :required => false do
          attribute :code
          field :name => %q{@displayName}
        end
        field :represented_organization => %q{cda:performer[@typeCode='PRF']/cda:assignedEntity[@classCode='ASSIGNED']/cda:representedOrganization[@classCode='ORG']/cda:name}, :required => false
      end
    end
  
  end
end
