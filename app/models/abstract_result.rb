# This is the base class for Result and VitalSign. You can use this class to
# find objects of either type, but you can only create new instances using
# Result and VitalSign.
class AbstractResult < ActiveRecord::Base

  class AbstractInstantiationError < StandardError; end
  def self.new(*args)
    if self.name == 'AbstractResult'
      raise AbstractInstantiationError, 'this is an abstract class, use Result or VitalSign'
    end
    super(*args)
  end

  strip_attributes!

  belongs_to :code_system
  belongs_to :loinc_lab_code
  belongs_to :result_type_code
  belongs_to :act_status_code
  belongs_to :status_code, :class_name => "ActStatusCode"

  include PatientChild
  include Commentable

  def requirements
    {
      :result_id => :required,
      :result_date => :required,
      :code_system_id => :required,
      :result_code => :required,
      :result_code_display_name => :required,
      :status_code => :required,
      :value_scalar => :required,
      :value_unit => :required,
    }
  end

  def code_system_code
    code_system.try(:code)
  end

  def code_system_name
    code_system.try(:name)
  end
 
  # Return a string representation of the value using value_scalar and value_unit.
  def value
    "#{value_scalar} #{value_unit}"
  end

  def statement_ccd_template_id
    '2.16.840.1.113883.10.20.1.31'
  end

  def c32_abstract_result_id
    "abstract-result-#{id}"
  end

  def to_c32(xml)

    xml.entry do
      # Another nit-noid of the CCD specification... if there is an organizer of a lab result, and that 
      # organizaer has an id, result type and a status code, the XML is changed for the reults and is 
      # wrapped within an organizer/component XML element.
      #
      # Otherwise, that XPath is not included in the XML and the result is simply an observation...  This
      # is specified in the CCD documentation and NOT the C32 specification... so this really complicates
      # things for folks who only have access to the C32 spec.
      if organizer_id && result_type_code && act_status_code

        xml.organizer("classCode" => "BATTERY", "moodCode" => "EVN") do
          xml.templateId("root" => "2.16.840.1.113883.10.20.1.32")
          xml.id("root" => organizer_id)
          xml.code("code" => result_type_code.code, 
                  "codeSystem" => "2.16.840.1.113883.6.96", 
                  "displayName" => result_type_code.name)
          xml.statusCode("code" => act_status_code.code)
          if self.result_date
            xml.effectiveTime("value" => self.result_date.to_formatted_s(:brief))
          end
          xml.component do
            append_result_data_to_c32(xml)
          end
        end

      else
        append_result_data_to_c32(xml)
      end
    end

  end

  def randomize()

    self.result_id = rand(100).to_s + 'd' + rand(100000).to_s + '-bd' + rand(100).to_s + '-4c90-891d-eb716d' + rand(10000).to_s + 'c4'
    self.result_date = DateTime.new(2000 + rand(9), rand(12) + 1, rand(28) + 1)
    self.code_system = CodeSystem.find_by_code("2.16.840.1.113883.6.1") # sets code system as LOINC
    self.status_code = ActStatusCode.find :random
    self.value_scalar = (100 + rand(100)).to_s

    if (rand < 0.5)
      self.value_unit = 'lbs'
      self.result_code_display_name = 'Body Weight'
      self.result_code = '3141-9'
    else
      self.value_unit = 'mg/dL'
      self.result_code_display_name = 'Cholesterol'
      self.result_code = '2093-3'
    end

    # Only create organizer data 1/2 the time
    if (rand < 0.5)
      organizer_id = "33d07056-bd27-4c90-891d-eb716d3170c4"
      result_type_code = ResultTypeCode.find :random
      act_status_code = ActStatusCode.find :random
    end

  end

  protected

  def append_result_data_to_c32(xml)

    xml.observation("classCode" => "OBS", "moodCode" => "EVN") do
      xml.templateId("root" => statement_ccd_template_id, "assigningAuthorityName" => "CCD")
      xml.templateId("root" => statement_c32_template_id, "assigningAuthorityName" => "HITSP/C83")
      xml.templateId("root" => statement_ihe_template_id, "assigningAuthorityName" => "IHE PCC")

      xml.id("root" => self.result_id) if self.result_id
      if self.result_code
        xml.code("code" => self.result_code, "displayName" => self.result_code_display_name,
                 "codeSystem" => self.code_system.try(:code),
                 "codeSystemName" => self.code_system.try(:name))
      end
      xml.text { xml.reference("value" => c32_abstract_result_id) }
      if self.status_code
        xml.statusCode("code" => self.status_code.code)
      end
      if self.result_date
        xml.effectiveTime("value" => self.result_date.to_formatted_s(:brief))
      end
      xml.value("xsi:type" => "PQ", "value" => self.value_scalar, "unit" => self.value_unit)
    end

  end

end
