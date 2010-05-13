require 'integration_spec_helper'

describe "GenerateAndFormats" do

  before do
    @user = login
    @test_plan = create_test_plan(:type => "GenerateAndFormatPlan")
    @c32_file = File.new(File.join(RAILS_ROOT, 'spec', 'test_data', 'joe_c32.xml'))
  end

  it "should be able to create a generate and format test" do
    visit vendor_test_plans_path(:vendor_id => @test_plan.vendor)
    xhr :get, test_action_path(:id => @test_plan.id, :action => :doc_upload)
    select 'C32 v2.5'
    attach_file "upload_#{@test_plan.id}", @c32_file.path
    click_button 'Attach'
    click_link "test_plan_#{@test_plan.id}_doc_inspect"
    body.should contain('6')
    body.should contain('XML Validation Errors')
  end

end
