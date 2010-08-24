# Inject validate_c32() methods into Patient.c32_modules for the convenience of
# being able to call a validation method directly on a Medication or Allergy
# instance for example.
Patient.class_eval do

  def validate_c32(document, options = {})
    validation_type = options[:validation_type] || Validation::C32_V2_5_TYPE
    content_validator = Validation.get_validator(validation_type).validators.find { |v| v.kind_of?(Validators::C32Validation::Validator) }
    content_validator.validate(self, document)
  end

  c32_modules.each do |module_name,association_name|
    klass = association_name.to_s.singularize.classify.constantize
    klass.class_eval do
      define_method(:validate_c32) do |xml,*optional|
        options = optional.first || {} 
        validation_type = options[:validation_type] || Validation::C32_V2_5_TYPE
        Validators::C32Validation::Validator.validate_component({
          :component_module => module_name,
          :reference_model  => self,
          :document         => xml,
          :validation_type  => validation_type,
        }.merge(options))
      end
    end
  end

end
