#Dir['/home/jpartlow/dev/osourcery/elbe/ccrvalidator/ccrvalidator-0.9-war/WEB-INF/lib/**/*.jar'].each { |d| require d }
include_class Java::org.openhealthdata.validator.ValidationManager

module Validators
  module CCR
    class WaldrenRulesValidator < Validation::FileValidator
      attr_accessor :validator, :name
      def initialize(name)
        @name = name
        @validator = ValidationManager.new
      end

      # * :patient_data => ignored
      # * :document_path => this should be the path to the file relative
      #   to RAILS_ROOT, not the xml itself.
      def validate(patient_data, document_path)
        errors = []
        begin
          java_file_descriptor = java.io.File.new(RAILS_ROOT + "/public/#{document_path}")
          result = @validator.validateToString(java_file_descriptor)
        rescue org.drools.runtime.rule.ConsequenceException => e
          ContentError.logger.info("ERROR DURING WALDREN CCR RULES VALIDATION: #{e.inspect}\n#{e.backtrace.join("\n") if e.respond_to?(:backtrace)}")
          errors << ContentError.new(:error_message => "CCR rules validation engine threw an exception: #{e} (Plese check the logs).",
                                     :validator => name,
                                     :inspection_type => ::XML_VALIDATION_INSPECTION)
        end
    
        redoc = REXML::Document.new result
        # loop over failed assertions 
        redoc.elements.to_a("//Error/Message").each do |el|
          
          errors << ContentError.new(
            :error_message => el.text,
            :validator => name,
            :inspection_type => ::XML_VALIDATION_INSPECTION
          )

        end
        errors
      end

    end
  end
end
