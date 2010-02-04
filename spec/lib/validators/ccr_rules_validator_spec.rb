
require File.dirname(__FILE__) + '/../../spec_helper'

describe Validators::CCR::WaldrenRulesValidator do

  before do
    puts java.lang.System.getProperty("java.class.path")
    @validator = Validators::CCR::WaldrenRulesValidator.new
  end

  it "should load the waldren validator" do
    puts @validator
    xml = java.io.File.new(File.dirname(__FILE__) + "/../../test_data/ccr/trivial_ccr.xml")
    results = @validator.validate(nil, xml)
    puts results
  end
end
