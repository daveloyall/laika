  module AllergyTypeCodeC32Validation

    include MatchHelper

    def validate_c32(allergy_type_code)

      unless allergy_type_code
        return [Laika::ValidationError.new]
      end

      errors = []

      return errors.compact

    end

  end

