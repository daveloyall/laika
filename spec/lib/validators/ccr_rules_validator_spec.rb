require File.dirname(__FILE__) + '/../../spec_helper'

describe Validators::CCR::WaldrenRulesValidator do

  before do
#    puts java.lang.System.getProperty("java.class.path")
    @validator = Validators::CCR::WaldrenRulesValidator.new("Waldren Rules CCR Validator")
  end

  it "should load the waldren validator" do
    puts @validator
    xml = "/../spec/test_data/ccr/trivial_ccr.xml"
    results = @validator.validate(nil, xml)
    puts results.inspect
  end

  it "should test against non-trivial xml" do
    xml = "/../spec/test_data/ccr/ccrsample_Allscripts.xml"
    results = @validator.validate(nil, xml)
    puts results.inspect
  end

  it "should run against all the available ccrs" do
    errors = {}
    results = {}
    Dir[File.dirname(__FILE__) + "/../../test_data/ccr/*.xml"].each do |f|
      result = nil
      puts f
      begin
        result = @validator.validate(nil, "../#{f}")
        results[f.to_s] = result
      rescue RuntimeError => e
        errors[f.to_s] = e
      end 
    end
    results.keys.sort.each do |k|
      puts "File: #{k}"
      puts "  result: #{ results[k].to_s[0..150] }"
    end
    puts "------"
    errors.keys.sort.each do |k|
      puts "File: #{k} - error: #{ errors[k] }"
    end
  end

  it "should run against available ccrs that do not fail" do
    [
      'ccrsample_CapMed.xml',
      'ccrsample_Emdeon.xml',
      'ccrsample_MedCommons.xml',
      'ccrsample_emds.xml',
      'ccrsample_obeverywhere.xml',
      'ccrsample_recordsforliving.xml',
    ].each do |f|

      xml = "/../spec/test_data/ccr/#{f}"
      result = @validator.validate(nil, xml)
      puts "File: #{f}"
      puts result.inspect
      puts "\n"

    end
  end

end
