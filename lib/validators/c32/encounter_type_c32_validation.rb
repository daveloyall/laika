module EncounterTypeC32Validation

  include MatchHelper

  def validate_c32(encounter_type)

    unless encounter_type
      return [Laika::ValidationError.new]
    end

    errors = []
    return errors.compact

  end

end
