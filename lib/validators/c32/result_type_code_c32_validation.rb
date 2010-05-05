module ResultTypeCodeC32Validation

  include MatchHelper

  def validate_c32(result_type_code)

    unless result_type_code
      return [Laika::ValidationError.new]
    end

    errors = []

    return errors.compact

  end

end
