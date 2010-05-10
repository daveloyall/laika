require 'spec_helper'
require 'webrat'

# Uncomment the next line to use webrat's matchers
require 'webrat/integrations/rspec-rails'

Webrat.configure do |config|
  config.mode = :rails
end

# Create a user and set them in the session so that we are logged in as this user
# for the purpose of authentication checks.
def login(user_attributes = {})
  user = User.factory.create(user_attributes)
  post login_path(:email => user.email, :password => "password")
  return user
end

# Establish a new test plan for the current user.
#
# :type => name of the test plan class
# :patient => patient object to test against
# :vendor_name => name of the vendor inspection the test plan is grouped in
#
# You must at least specify the :type.
def create_test_plan(options = {})
  test_plan_type = options[:type]
  patient = options[:patient] || Patient.factory.create
  vendor = Vendor.find_by_public_id(options[:vendor_name])

  test_plan_parameters = { :patient_id => patient.id, :test_plan => { :type => test_plan_type }} 
  vendor.nil? ?
    test_plan_parameters[:vendor_name] = options[:vendor_name] || 'Foo Vendor' :
    test_plan_parameters[:test_plan][:vendor_id] = vendor.id

  post test_plans_path(test_plan_parameters)
  
  vendor ||= Vendor.find_by_public_id('Foo Vendor')
  return vendor.test_plans(:order => 'created_at DESC').first
end
