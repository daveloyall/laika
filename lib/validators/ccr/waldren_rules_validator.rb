#Dir['/home/jpartlow/dev/osourcery/elbe/ccrvalidator/ccrvalidator-0.9-war/WEB-INF/lib/**/*.jar'].each { |d| require d }
include_class Java::org.openhealthdata.validator.ValidationManager

module Validators
  module CCR
    class WaldrenRulesValidator < Validation::BaseValidator
      attr_accessor :validator 
      def initialize
        @validator = ValidationManager.new
      end

      def validate(patient_data, document)
        @validator.validateToString(document) 
      end

    end
  end
end
