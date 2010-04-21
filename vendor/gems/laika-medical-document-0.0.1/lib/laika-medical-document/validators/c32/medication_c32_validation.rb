 module MedicationC32Validation

    include MatchHelper

    #Reimplementing from MatchHelper
    def section_name
      "Medications Module"
    end

    # Accepts an options hash.
    #
    # * options
    #   :validation_type => which must be on of Validation::*_TYPE constants
    #   :substance_administration_hash => if given Hash of v2.5
    #    substanceAdministration sections keyed by their dereferenced
    #    medication name
    def validate_c32(document, options = {})
      options ||= {}
      validation_type = options[:validation_type] || Validation::C32_V2_5_TYPE
      substance_administration_hash = options[:substance_administration_hash] || {}
      errors=[]
      errors << safe_match(document) do 
        errors << match_required(
          document,
          "//cda:section[./cda:templateId[@root = '2.16.840.1.113883.10.20.1.8']]",
          MatchHelper::DEFAULT_NAMESPACES,
          {},
          nil,
          "C32 Medication section with templateId 2.16.840.1.113883.10.20.1.8 not found",
          document.xpath
        ) do |section|

          match_args = case 
            when validation_type == Validation::C32_V2_5_TYPE
            then {
              # v2.5 substanceAdministration can only be indirectly
              # identified through the dereferenced
              # substance_administration_hash
              :element => substance_administration_hash[product_coded_display_name],
              :xpath => ".",
            }
            else {
              :element => section,
              # IF there is an entry for this medication then there will be a
              # substanceAdministration element that contains a consumable
              # that contains a manufacturedProduct that has a code with the
              # original text equal to the name of the generic medication.
              # The consumeable/manfucaturedProduct/code/originalText is a
              # required field if the substanceAdministration entry is
              # present
              :xpath => "./cda:entry/cda:substanceAdministration[ ./cda:consumable/cda:manufacturedProduct/cda:manufacturedMaterial/cda:code/cda:originalText/text() = '#{product_coded_display_name}']",
            }
          end
          errors << match_required(
            match_args[:element],
            match_args[:xpath],
            MatchHelper::DEFAULT_NAMESPACES,
            {},
            "substanceAdministration",
            "A substanceAdministration section does not exist for the medication",
             section.xpath
          ) do |substance_administration|
            errors << _validate_substance_administration(substance_administration) 
          end

        end
      end
      errors.flatten.compact
    end

    private

    def _validate_substance_administration(substance_administration)
      errors = []
      #consumable product and assorted sub elements
      consumable = REXML::XPath.first(substance_administration,"./cda:consumable",MatchHelper::DEFAULT_NAMESPACES)
    
      errors << content_required(consumable,"consumable","A consumable entry does not exist",substance_administration.xpath) do |consumable|
        manufactured = REXML::XPath.first(consumable,"./cda:manufacturedProduct",MatchHelper::DEFAULT_NAMESPACES)
        code = REXML::XPath.first(manufactured,"./cda:manufacturedMaterial/cda:code",MatchHelper::DEFAULT_NAMESPACES)
        translation = REXML::XPath.first(code,"cda:translation",MatchHelper::DEFAULT_NAMESPACES)
    
        # test for the manufactured content
        errors << content_required(manufactured,"manufacturedMaterial","A manufacturedProduct entry does not exist",consumable) do 
          errors << match_value(manufactured, "cda:manufacturedMaterial/cda:name/text()", 'free_text_brand_name', free_text_brand_name)
        end
      end
    
      # validate the medication type Perscription or over the counter
      errors << match_value(substance_administration, 
                           "cda:entryRelationship[@typeCode='SUBJ']/cda:observation[cda:templateId/@root='2.16.840.1.113883.3.88.11.32.10']/cda:code/@displayName",
                           'medication_type', 
                           medication_type.try(:name))
      # validate the status
      errors << match_value(substance_administration,
                           "cda:entryRelationship[@typeCode='REFR']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.1.47']/cda:statusCode/@code", 
                           'status', 
                           status)
    
      # validate the order quantity
      if order = REXML::XPath.first(substance_administration,
                                    "cda:entryRelationship[@typeCode='REFR']/cda:supply[@moodCode='INT']", 
                                    MatchHelper::DEFAULT_NAMESPACES)
        errors << match_value(order, "cda:quantity/@value", "quantity_ordered_value", quantity_ordered_value)
        # This differs from the XPath expression given in the C32 spec which claims that the value should be under cda:high
        # however, the CCD schema claims that it should be an effectiveTime with no children
        errors << match_value(order, "cda:effectiveTime/@value", "expiration_time", expiration_time.try(:to_formatted_s, :brief))
      end
      return errors
    end
  end
