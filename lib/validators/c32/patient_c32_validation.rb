module PatientC32Validation

    # Accepts an options hash.  This may be passed to any subsection which needs to validate
    # differently based on the C32 version.  Currently the only used option is:
    #
    #  :validation_type => which must be on of Validation::*_TYPE constants
    def validate_c32(clinical_document, options = {})
      errors = []

#      Patient.c32_modules.each do |module_name|
#        association = self.send(module_name)
#        if  association.singular?
#          errors.concat(association.validate_c32(clinical_document, options)) unless association.nil?
#        else
#          "#{module_name.singularize}_c32_validation".classify.constantize.send(:validate_c32_module, clinical_document, options))
#          association.each do |component|
#            errors.concat(component.validate_c32(clinical_document, options))
#          end
#        end
#      end

      Patient.c32_modules.each do |module_name|
        "#{module_name.singularize}_c32_validation".classify.constantize.send(
          :validate_c32_module,
          self.send(module_name), # the Patient#association
          clinical_document,      # the original xml document
          options                 # any options we've been given
        )
      end

#      # Registration information
#      errors.concat((self.registration_information.try(:validate_c32, clinical_document)).to_a)
#      # Languages
#      self.languages.each do |language|
#        errors.concat(language.validate_c32(clinical_document))
#      end
#
#      # Healthcare Providers
#
#      self.providers.each do |provider|
#        errors.concat(provider.validate_c32(clinical_document))
#      end
#
#      # Insurance Providers
#
#      self.insurance_providers.each do |insurance_providers|
#        errors.concat(insurance_providers.validate_c32(clinical_document))
#      end
#
#      # Medications
#      substance_administration_hash = XmlHelper.dereference('substanceAdministration', clinical_document)
#      self.medications.each do |medication|
#        errors.concat(medication.validate_c32(clinical_document, options.merge(:substance_administration_hash => substance_administration_hash)))
#      end
#
#      # Supports          
#      errors.concat(self.support.validate_c32(clinical_document)) if self.support
#
#      # Allergies
#      self.allergies.each do |allergy|
#        errors.concat(allergy.validate_c32(clinical_document))
#      end
#
#      # Conditions
#      self.conditions.each_with_index do |condition, i|
#        errors.concat(condition.validate_c32(clinical_document, i))
#      end  
#
#      # Information Source
#
#      # Need to pass in the root element otherwise the first XPath expression doesn't work
#      errors.concat(self.information_source.validate_c32(clinical_document.root))  if self.information_source
#
#      # Advance Directive      
#      errors.concat(self.advance_directive.validate_c32(clinical_document)) if self.advance_directive
#
#      # Results
#      self.results.each do |result|
#        errors.concat(result.validate_c32(clinical_document))
#      end
#
#      # Immunizations
#      self.immunizations.each do |immunization|
#        errors.concat(immunization.validate_c32(clinical_document))
#      end
#
#      # Encounters
#      self.encounters.each do |encounter|
#        errors.concat(encounter.validate_c32(clinical_document))
#      end
#
#      # Removes all the nils... just in case.
      errors.compact!
      errors
   end

end
