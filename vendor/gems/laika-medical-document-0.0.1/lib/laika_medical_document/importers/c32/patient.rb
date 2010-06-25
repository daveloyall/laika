require 'laika_medical_document/importers/c32/base'

module LaikaMedicalDocument
  module Importers
    module C32

      # Governs import of a C32.  This is the top level section of the document.
      class Patient < Base
      
        # The patient's given and family name extracted from the document.
        def name
          _method_cache(:name) do
            first_text("/cda:ClinicalDocument/cda:recordTarget/cda:patientRole/cda:patient/cda:name/cda:given") +
            " " + 
            first_text("/cda:ClinicalDocument/cda:recordTarget/cda:patientRole/cda:patient/cda:name/cda:family")
          end
        end

        # Return the document data in a hash.
        def to_hash
          _method_cache(:hash) do
            hash = {}
            if name
              hash[:name] = name
              
              registration_section = RegistrationInformationC32Importer.section(clinical_document)
              imported_info = RegistrationInformationC32Importer.import_entries(registration_section)
              new_patient.registration_information ||= imported_info.first
              
              directives_section = AdvanceDirectiveC32Importer.section(clinical_document)
              imported_directives = AdvanceDirectiveC32Importer.import_entries(directives_section)
              new_patient.advance_directive ||= imported_directives.first
              
              allergy_section = AllergyC32Importer.section(clinical_document)
              imported_allergies = AllergyC32Importer.import_entries(allergy_section)
              new_patient.allergies << imported_allergies
              
              condition_section = ConditionC32Importer.section(clinical_document)
              imported_conditions = ConditionC32Importer.import_entries(condition_section)
              new_patient.conditions << imported_conditions
              
              encounter_section = EncounterC32Importer.section(clinical_document)
              imported_encounters = EncounterC32Importer.import_entries(encounter_section)
              new_patient.encounters << imported_encounters
              
              provider_section = HealthcareProviderC32Importer.section(clinical_document)
              imported_providers = HealthcareProviderC32Importer.import_entries(provider_section)
              new_patient.providers << imported_providers
              
              immunization_section = ImmunizationC32Importer.section(clinical_document)
              imported_immunizations = ImmunizationC32Importer.import_entries(immunization_section)
              new_patient.immunizations << imported_immunizations
              
              insurance_provider_section = InsuranceProviderC32Importer.section(clinical_document)
              imported_insurance_providers = InsuranceProviderC32Importer.import_entries(insurance_provider_section)
              new_patient.insurance_providers << imported_insurance_providers
              
              medication_section = MedicationC32Importer.section(clinical_document)
              imported_medications = MedicationC32Importer.import_entries(medication_section)
              new_patient.medications << imported_medications
              
              #procedure_section = ProcedureC32Importer.section(clinical_document)
              #imported_procedures = ProcedureC32Importer.import_entries(procedure_section)
              #new_patient.procedures << imported_procedures
              
              support_section = SupportC32Importer.section(clinical_document)
              imported_support = SupportC32Importer.import_entries(support_section)
              new_patient.support ||= imported_support.first
              
              vitals_section = VitalSignC32Importer.section(clinical_document)
              imported_vitals = VitalSignC32Importer.import_entries(vitals_section)
              new_patient.vital_signs << imported_vitals
              
              result_section = ResultC32Importer.section(clinical_document)
              imported_results = ResultC32Importer.import_entries(result_section)
              new_patient.results << imported_results
              
              new_patient.save!
              
              return new_patient
            else
              false
            end
          end
        end

      end

    end
  end  
end
