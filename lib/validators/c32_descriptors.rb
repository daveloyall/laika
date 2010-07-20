module Validators
  module C32Descriptors
    include ComponentDescriptors::Mapping
  
    components :languages => %q{//cda:recordTarget/cda:patientRole/cda:patient/cda:languageCommunication}, :matches_by => :language_code do
      field :language_code => %q{cda:languageCode/@code}
      field :language_ability_mode => %q{cda:modeCode/@code}, :accessor => :language_ability_mode_code, :required => false
      field :preference => %q{cda:preferenceInd/@value}, :required => false
    end
  
    components :healthcare_providers => %q{//cda:documentationOf/cda:serviceEvent/cda:performer}, :matches_by => [:first_name, :last_name] do
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
          field :name_prefix => %q{cda:prefix}, :required => false
          field :first_name => %q{cda:given[1]}, :required => false
          field :middle_name => %q{cda:given[2]}, :required => false
          field :last_name => %q{cda:family}, :required => false
          field :name_suffix => %q{cda:suffix}, :required => false
        end
        section :address => %q{cda:addr}, :required => false do
          field :street_address_line_one => %q{cda:streetAddressLine[1]}, :required => false
          field :street_address_line_two => %q{cda:streetAddressLine[2]}, :required => false
          field :city, :required => false
          field :state, :required => false
          field :postal_code, :required => false
          field :iso_country => %q{cda:country}, :accessor => :iso_country_code, :required => false
        end
  #      # 'with' is transparent to the output, unlike 'section'
  #      with :telecom => %q{cda:telecom}, :required => :false do
  #        field :home_phone => %q{[@use='hp']}, :validates => :match_telecom_as_hp
  #        field :work_phone => %q{[@use='wp']}, :validates => :match_telecom_as_wp
  #        field :mobile_phone => %q{[@use='mc']}, :validates => :match_telecom_as_mc
  #        field :vacation_home_phone => %q{[@use='hv']}, :validates => :match_telecom_as_hv
  #        field :email => %q{[@use='email']}, :validates => :match_telecom_as_email
  #      end
        field :id => %q{sdtc:patient/sdtc:id/@root}, :accessor => :patient_identifier, :required => false 
      end
    end
  
    component :medications, :template_id => '2.16.840.1.113883.10.20.1.8' do
      repeating_section :medication => %q{cda:entry/cda:substanceAdministration}, :matches_by => :product_coded_display_name do
        field :product_coded_display_name => %q{cda:consumable/cda:manufacturedProduct/cda:manufacturedMaterial/cda:code/cda:originalText}, Validation::C32_V2_5_TYPE => { :dereference => true }
        section :consumable do
          section :manufactured_product do
            field :free_text_brand_name => %q{cda:manufacturedMaterial/cda:name}
          end
        end
        field :medication_type => %q{cda:entryRelationship[@typeCode='SUBJ']/cda:observation[cda:templateId/@root='2.16.840.1.113883.3.88.11.32.10']/cda:code/@displayName}, :accessor => :medication_type_name
        field :status => %q{cda:entryRelationship[@typeCode='REFR']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.1.47']/cda:statusCode/@code}, :required => false
        section :order => %q{cda:entryRelationship[@typeCode='REFR']/cda:supply[@moodCode='INT']}, :required => false do
          field :quantity_ordered_value => %q{cda:quantity/@value}
          field :expiration_time => %q{cda:effectiveTime/@value}
        end
      end
    end
  
    component :allergies, :template_id => '2.16.840.1.113883.10.20.1.2' do
      repeating_section :allergy => %q{cda:entry/cda:act[cda:templateId/@root='2.16.840.1.113883.10.20.1.27']/cda:entryRelationship[@typeCode='SUBJ']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.1.18']}, :matches_by => :free_text_product do
        field :free_text_product => %q{cda:participant[@typeCode='CSM']/cda:participantRole[@classCode='MANU']/cda:playingEntity[@classCode='MMAT']/cda:name/text()}
        field :start_event => %q{cda:effectiveTime/cda:low/@value}
        field :end_event => %q{cda:effectiveTime/cda:high/@value}
        field :product_code => %q{cda:participant[@typeCode='CSM']/cda:participantRole[@classCode='MANU']/cda:playingEntity[@classCode='MMAT']/cda:code[@codeSystem='2.16.840.1.113883.6.88']/@code}
      end
    end
  
    component :insurance_providers, :template_id => '2.16.840.1.113883.10.20.1.9' do
      repeating_section :insurance_provider => %q{cda:entry/cda:act[cda:templateId/@root='2.16.840.1.113883.10.20.1.20']/cda:entryRelationship/cda:act[cda:templateId/@root='2.16.840.1.113883.10.20.1.26']} do
        field :group_number => %q{cda:id/@root}, :required => false
        section :insurance_type => %q{cda:code[@codeSystem='2.16.840.1.113883.6.255.1336']}, :required => false do
          attribute :code
          field :name => %q{@displayName}
        end
        field :represented_organization => %q{cda:performer[@typeCode='PRF']/cda:assignedEntity[@classCode='ASSIGNED']/cda:representedOrganization[@classCode='ORG']/cda:name}, :required => false
        repeating_section :insurance_provider_guarantor => %q{cda:performer/cda:assignedEntity/cda:assignedPerson/cda:name}, :matches_by => [:first_name, :last_name], :required => false do
          field :name_prefix => %q{cda:prefix}, :required => false
          field :first_name => %q{cda:given[1]}, :required => false
          field :middle_name => %q{cda:given[2]}, :required => false
          field :last_name => %q{cda:family}, :required => false
          field :name_suffix => %q{cda:suffix}, :required => false
        end
      end
    end
 
    component :conditions, :template_id => '2.16.840.1.113883.10.20.1.11' do
      repeating_section :condition => %q{cda:entry/cda:act[cda:templateId/@root='2.16.840.1.113883.10.20.1.27']/cda:entryRelationship[@typeCode='SUBJ']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.1.28']}, :matches_by => [:problem_name, :start_event, :end_event] do
        field :problem_name => %q{cda:text}, :dereference => true
        field :problem_code => %q{cda:value[@codeSystem='2.16.840.1.113883.6.96']/@code}, :required => false
        field :start_event => %q{cda:effectiveTime/cda:low/@value}, :required => false
        field :end_event => %q{cda:effectiveTime/cda:high/@value}, :required => false
        section :problem_type => %q{cda:code[@codeSystem='2.16.840.1.113883.6.96']}, :required => false do
          attribute :code
          field :name => %q{@displayName}
        end
      end
    end
  
    component :personal_information => %q{/cda:ClinicalDocument/cda:recordTarget/cda:patientRole} do
      repeating_section :address => %q{cda:addr}, :matches_by => :street_address_line_one do
        field :street_address_line_one => %q{cda:streetAddressLine[1]}, :required => false
        field :street_address_line_two => %q{cda:streetAddressLine[2]}, :required => false
        field :city, :required => false
        field :state, :required => false
        field :postal_code, :required => false
        field :iso_country => %q{cda:country}, :accessor => :iso_country_code, :required => false
      end
      section :patient, :accessor => :do_not_access_patient_method do
        repeating_section :name, matches_by => [:first_name, :last_name] do
          field :name_prefix => %q{cda:prefix}, :required => false
          field :first_name => %q{cda:given[1]}, :required => false
          field :middle_name => %q{cda:given[2]}, :required => false
          field :last_name => %q{cda:family}, :required => false
          field :name_suffix => %q{cda:suffix}, :required => false
        end
        section :gender => %q{cda:administrativeGenderCode} do
          attribute :code
          field :name => %q{@displayName}
        end
        field :date_of_birth => %q{cda:birthTime/@value}
        section :marital_status => %q{cda:maritalStatusCode}, :required => false do
          attribute :code
          field :name => %q{@displayName}
        end
        section :religious_affiliation => %q{cda:religiousAffiliationCode}, :required => false, :accessor => :religion do
          attribute :code
          field :name => %q{@displayName}
        end
        section :race => %q{cda:raceCode}, :required => false do
          attribute :code
          field :name => %q{@displayName}
        end
        section :ethnicity => %q{cda:ethnicGroupCode}, :required => false do
          attribute :code
          field :name => %q{@displayName}
        end
      end
    end

    # Another nit-noid of the CCD specification... if there is an organizer
    # of a lab result, and that organizaer has an id, result type and a
    # status code, the XML is changed for the reults and is wrapped within
    # an organizer/component XML element.
    #
    # Otherwise, that XPath is not included in the XML and the result is
    # simply an observation...  This is specified in the CCD documentation
    # and NOT the C32 specification... so this really complicates things
    # for folks who only have access to the C32 spec.
    #
    # TODO Organizer XPath expressions and logic for deciding which set of
    # descriptors to employ.  Perhaps something like:
    #
    # common :abstract_result do
    #   if descendent(:organizer) && descendent(:result_type_code) && descendent(:act_status_code)
    #     reference :organizer_abstract_result
    #   else
    #     ...
    #   end
    # end
    # 
    # except that the above relies on the ability to find the :organizer
    # descriptor -- even though we are only just deciding whether that
    # descriptor will be included...

    common :abstract_result do
      repeating_section :result => %q{cda:entry/cda:observation}, :matches_by => :result_id do
        field :result_id => %q{cda:id/@root}
        section :code do
          field :result_code => %q{@code}
          field :result_code_display_name => %q{@displayName}
          attribute :code_system, :accessor => :code_system_code
          attribute :code_system_name
        end
        field :status_code => %q{cda:statusCode/@code}
        field :result_date => %q{cda:effectiveTime/@value}
        field :value_scalar => %q{cda:value/@value}
        field :value_unit => %q{cda:value/@unit}
      end
    end

    component :vital_signs, :template_id => '2.16.840.1.113883.10.20.1.16' do
      reference :abstract_result
    end

    component :results, :template_id => '2.16.840.1.113883.10.20.1.14' do
      reference :abstract_result
    end

  end
end
