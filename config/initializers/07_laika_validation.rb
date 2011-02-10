require 'xml_helper'
require 'laika/constants'
require 'validation'
require 'validation_error'
# convenience validator methods
require_dependency 'patient_validators'

# The Tale of Validator Initialization
#
# Originally this initializer used require to load all of the validation
# code once so that validators could be initialized once with their 
# associated xml/xslt resource files in the Validation::ValidationRegistry.
# 
# This led to GH#104 with config.cache_classes = false (*)
# because requiring validators/c32_validator would load an instance
# of MatchHelper which Rails would not track in its dependency tracking
# while other models would also load MatchHelper such that it would
# be tracked for reloading by Rails, with conflict in subsequent requests:
#
# http://www.ruby-forum.com/topic/153066
# http://spacevatican.org/2008/9/28/required-or-not
#
# (Summary: it is fine to require external sources (third party libraries
# and such), but requiring internal code that will reference other code
# which Rails will be doing dependency tracking on leads to pain.  Use
# require_dependency instead.)
#
# The problem with keeping this code in the initializer even after
# require had been switched to require_dependency, was that with
# config.cache_classes = false, the Validation::ValidationRegistry was reloaded
# with each request and a new Singleton ValidationRegistry was created.  But
# without the code below, which runs only during the bootstrap of a Rails
# process, it was initialized without any validators.
#
# So the initialization code was moved into lib/validation.rb, and ValidationRegistry
# was reloaded and reintialized with every request.  Although inefficient
# from the perspective of initialization, this resolved the MatchHelper dependency
# problem.
#
# However, this led to issue GH#130 which is an OutOfMemory error seemingly
# caused by a reference to ValidationRegistry or its resources being held after
# each request which reloaded and reinitialized the validation classes, consuming
# resources at, presumably, ~8MB (the size of the loaded schemas/schematron
# files) per reload.  There is some guesswork here; I know that the issue was
# reproducible at commit 668aa38ae7797b2102fbb51d45ee672e2a93d130, but not the
# previous commit be1e9d6b5b749fab1ca72865c50985ccdcfa0229, and that the only
# code touched in the culpable commit was the laika_validation and validation
# file, but I did not do an exhaustive analysis of the heap to pinpoint the
# memory leak.  Still not sure why the reference was being held; using a
# @@class_variable for the registry instance rather than Singleton had no
# effect.  I don't think threads were an issue.  Perhaps it's something murky in
# jruby, or perhaps app/views/test_plans/doc_upload.html.erb was hanging onto
# a reference because it calls Validation.types?
#
# One attempt to resolve this, was to move Validation::ValidationRegistry 
# out of lib/validation.rb and into lib/validation_registry/base.rb as
# ValidationRegistry::Base.  Then 'lib/validation_registry' was added to the
# config.load_once_paths in config/environment.rb to ensure that it is not
# reloaded.
#
# Unfortunately this had the same effect as simply requiring the validation code
# and again produced a #104 type problem where I believe
# ValidationRegistry had references to Validators which had since been
# reloaded.  ActiveSupport::Dependencies had gutted the old classes, and
# NameError's got thrown for unknown Validator constants when the registry
# validators were retrieved and asked to validate().
#
# GH#105 was tracking the need to remove MatchHelper from a last couple of
# references in the model code.  This had been done in a branch.  Switching
# to that branch and changing back the validation require_dependency
# calls to require did finally fix the memory leak for GH#130.  But we
# are now in danger of once more confusing our class loading by including
# some piece of the required validation code in a piece of code which Rails
# will be reloading.
#
# * (The reason cache_classes = false in production mode is 
# tied to issue #62...)
#
# XXX Evaluate a better validator initialization strategy.  At this point
# I think the best thing to do with the validation libraries is to remove
# all of the validation code as a separate project with its own test suite,
# and simply require the validation library as a vendor dependency for
# the Rails application.  This should provide a clean separation, both for
# development and production.  I'm not positive yet how much work would be
# required to pull the validation code out into vendor; I suspect it would
# mostly come down to additional work smoothing out configuration (how to
# find required xml resources and what validators to initialize), so long as
# the validation code is just operating on xml.
#
require 'validators/c62'
require 'validators/c32_validator'
require 'validators/schema_validator'
require 'validators/schematron_validator'
require 'validators/umls_validator'
require 'validators/xds_metadata_validator'

validator_config = {
  Validation::C32_V2_1_2_3_TYPE => [
    Validators::C32Validation::Validator.new,
    Validators::Schema::Validator.new("C32 Schema Validator",
      "#{RAILS_ROOT}/resources/schemas/infrastructure/cda/C32_CDA.xsd"),
    Validators::Schematron::CompiledValidator.new("CCD Schematron Validator",
      "#{RAILS_ROOT}/resources/schematron/ccd_errors.xslt"),
    Validators::Schematron::CompiledValidator.new("C32 Schematron Validator",
      "#{RAILS_ROOT}/resources/schematron/c32_v2.1/c32_v2.1_errors.xslt"),
    Validators::Umls::UmlsValidator.new("warning")
  ],
  Validation::C32_V2_5_TYPE => [
    Validators::C32Validation::Validator.new,
    Validators::Schema::Validator.new("C32 Schema Validator",
      "#{RAILS_ROOT}/resources/schemas/infrastructure/cda/C32_CDA.xsd"),
    Validators::Schematron::CompiledValidator.new("CCD Schematron Validator",
      "#{RAILS_ROOT}/resources/schematron/ccd_errors.xslt"),
    Validators::Schematron::CompiledValidator.new("C32 Schematron Validator",
      "#{RAILS_ROOT}/resources/schematron/c32_v2.5/c32_v2.5_errors.xslt"),
    Validators::Umls::UmlsValidator.new("warning")
  ],
  Validation::C32_V2_5_C83_V2_0_TYPE => [
    Validators::C32Validation::Validator.new,
    Validators::Schema::Validator.new("C32 Schema Validator",
      "#{RAILS_ROOT}/resources/schemas/infrastructure/cda/C32_CDA.xsd"),
    Validators::Schematron::CompiledValidator.new("CCD Schematron Validator",
      "#{RAILS_ROOT}/resources/schematron/ccd_errors.xslt"),
    Validators::Schematron::CompiledValidator.new("C32 Schematron Validator",
      "#{RAILS_ROOT}/resources/schematron/c32_v2.5_c83_v2.0/c32_v2.5_c83_v2.0_errors.xslt"),
    Validators::Umls::UmlsValidator.new("warning")
  ],
}
if Laika.use_nhin
  validator_config[Validation::C32_NHIN_TYPE] = [
    Validators::C32Validation::Validator.new,
    Validators::Schema::Validator.new("C32 Schema Validator",
      "#{RAILS_ROOT}/resources/schemas/infrastructure/cda/C32_CDA.xsd"),
    Validators::Schematron::CompiledValidator.new("CCD Schematron Validator",
      "#{RAILS_ROOT}/resources/schematron/ccd_errors.xslt"),
    Validators::Schematron::CompiledValidator.new("C32 Schematron Validator",
      "#{RAILS_ROOT}/resources/schematron/c32_v2.1_errors.xslt"),
    Validators::Schematron::CompiledValidator.new("NHIN Schematron Validator",
      "#{RAILS_ROOT}/resources/nhin_schematron/nhin_errors.xsl"),
    Validators::Umls::UmlsValidator.new("warning")
  ]
end

# See INSTALL.rdoc for details of setting CCR validation
ccr_schema_path = "#{RAILS_ROOT}/#{CCR_XSD_LOCATION}"
ccr_schema_exists = File.exists?(ccr_schema_path)
ccr_rules_validator_schema_path = "#{RAILS_ROOT}/#{CCR_RULES_VALIDATOR_XSD_LOCATION}"
ccr_rules_validator_exists = File.exists?(ccr_rules_validator_schema_path)
if ccr_schema_exists || ccr_rules_validator_exists
  ccr_validators = [
    Validators::Umls::UmlsValidator.new("warning"),
  ]
  if ccr_rules_validator_exists
    require 'validators/ccr/waldren_rules_validator'
    ccr_validators.unshift Validators::CCR::WaldrenRulesValidator.new("CCR Rules Validator")
  end
  ccr_validators.unshift Validators::Schema::Validator.new("CCR Schema Validator", ccr_schema_path) if ccr_schema_exists
  validator_config[Validation::CCR_TYPE] = ccr_validators
end

validator_config.each do |type, validators|
  validators.each do |validator|
    Validation.register_validator type.to_sym, validator
  end
end
