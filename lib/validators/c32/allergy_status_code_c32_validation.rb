  module AllergyStatusCodeC32Validation

    include MatchHelper

    def validate_c32(allergy_status_code)

      unless allergy_status_code
        return [Laika::ValidationError.new]
      end

      errors = []

      return errors.compact

    end

  end
