ENV["RAILS_ENV"] ||= 'test'
require File.expand_path(File.join(File.dirname(__FILE__),'..','config','environment'))
require 'spec/autorun'
require 'spec/rails'
require 'modelfactory'
require File.expand_path(File.dirname(__FILE__) + '/laika_spec_helper')

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

ModelFactory.configure do
  default(Setting) do
    name  { |i| "factory setting #{i}" }
    value { |i| "factory value #{i}" }
  end

  default(ContentError) do
    validator { 'factory' }
  end

  default(Patient) do
    name { "Harry Manchester" }
    user { User.factory.create }
  end

  default(InsuranceProvider) do
    insurance_provider_patient {
      InsuranceProviderPatient.factory.create(:insurance_provider => self)
    }
    insurance_provider_subscriber {
      InsuranceProviderSubscriber.factory.create(:insurance_provider => self)
    }
    insurance_provider_guarantor {
      InsuranceProviderGuarantor.factory.create(:insurance_provider => self)
    }
  end

  default(User) do
    email { |i| "factoryuser#{i}@example.com" }
    first_name { "Harry" }
    last_name { "Manchester" }
    password { "password" }
    password_confirmation { password }
  end

  default(Vendor) do
    public_id { |i| "FACTORYVENDOR#{i}" }
    user { User.factory.create }
  end

  default(TestPlan) do
    patient { Patient.factory.create }
    user { User.factory.create }
    vendor { Vendor.factory.create }
  end

  default(XdsProvideAndRegisterPlan) do
    patient { Patient.factory.create }
    user { User.factory.create }
    vendor { Vendor.factory.create }
    test_type_data { XDS::Metadata.new }
  end

  default(C62InspectionPlan) do
    patient { Patient.factory.create }
    user { User.factory.create }
    vendor { Vendor.factory.create }
    clinical_document { ClinicalDocument.factory.create(:doc_type => 'C62') }
  end

  default(ClinicalDocument) do
    size { 256 }
    filename { 'factory_document' }
  end

  default(Gender) do
    name { 'Male' }
    code { 'M' }
    description { 'Male' }
  end

end

class TestLogger
  [:debug, :info, :warn, :error].each do |m|
    define_method(m) { |message| puts "#{m.to_s.upcase}: #{message}" }
  end
end

class TestLoggerDevNull
  [:debug, :info, :warn, :error].each do |m|
    define_method(m) { |message|  } # crickets
  end
end

class ActiveSupport::TestCase

  # Fixtures needed to load patient records.  Excludes large, cumbersome
  # tables like snowmed_problems...
  def self.patient_fixtures
    fixtures %w[
act_status_codes addresses advance_directive_status_codes advance_directives
advance_directive_types adverse_event_types allergies allergy_status_codes
allergy_type_codes clinical_documents code_systems conditions contact_types
coverage_role_types encounter_location_codes encounters encounter_types ethnicities
genders immunizations information_sources insurance_provider_guarantors
insurance_provider_patients insurance_provider_subscribers insurance_providers
insurance_types iso_countries iso_languages iso_states language_ability_modes
languages loinc_lab_codes marital_statuses medical_equipments medications
medication_types no_immunization_reasons patients patient_identifiers person_names problem_types
procedures provider_roles providers provider_types races registration_information
relationships religions abstract_results result_type_codes role_class_relationship_formal_types
severity_terms supports telecoms users vaccines vendors zip_codes
    ]
  end

  def validation_error_stub(options = {})
    attributes = {
      :section         => 'section',
      :subsection      => 'subsection',
      :field_name      => 'field',
      :message         => 'foo',
      :location        => '//xpath',
      :severity        => 'error',
      :validator       => 'test',
      :inspection_type => 'testing',
      :error_type      => 'Testing',
      :exception       => nil,
      :suberrors       => [],
      :review?         => false,
    }.merge(options)
    stub('laika-validation-error', attributes)
  end

end

Spec::Runner.configure do |config|
  # If you're not using ActiveRecord you should remove these
  # lines, delete config/database.yml and disable :active_record
  # in your config/boot.rb
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false
  config.fixture_path = RAILS_ROOT + '/spec/fixtures/'

  # == Fixtures
  #
  # You can declare fixtures for each example_group like this:
  #   describe "...." do
  #     fixtures :table_a, :table_b
  #
  # Alternatively, if you prefer to declare them only once, you can
  # do so right here. Just uncomment the next line and replace the fixture
  # names with your fixtures.
  #
  # config.global_fixtures = :table_a, :table_b
  #
  # If you declare global fixtures, be aware that they will be declared
  # for all of your examples, even those that don't use them.
  #
  # You can also declare which fixtures to use (for example fixtures for test/fixtures):
  #
  # config.fixture_path = RAILS_ROOT + '/spec/fixtures/'
  #
  # == Mock Framework
  #
  # RSpec uses its own mocking framework by default. If you prefer to
  # use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  #
  # == Notes
  #
  # For more information take a look at Spec::Runner::Configuration and Spec::Runner
end
