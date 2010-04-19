require File.dirname(__FILE__) + '/../../spec_helper'

if File.exists?("#{RAILS_ROOT}/#{CCR_RULES_VALIDATOR_XSD_LOCATION}")

  # Note: CCR Validator log output.  java.util.logging is used by the ccr
  # validator and there are some println's to system out buried in the rules
  # files as well.  silence_stream(STDOUT) doesn't seem to catch the println's.
  # So we're turning off logging manually and then pointing java.lang.System.out
  # to a null stream sink.

  ccr_logger = java.util.logging.Logger.get_logger('org.openhealthdata.validation.CCRV1SchemaValidator')
  ccr_logger.set_level(java.util.logging.Level::OFF)

  describe Validators::CCR::WaldrenRulesValidator do
 
    before(:all) do 
      @old_out = java.lang.System.out
      java.lang.System.set_out(java.io.PrintStream.new(org.apache.commons.io.output.NullOutputStream.new,true))
    end

    before do
#      puts java.lang.System.getProperty("java.class.path")
      @validator = Validators::CCR::WaldrenRulesValidator.new("Waldren Rules CCR Validator")
    end
  
    it "should load the waldren validator" do
      xml = "/../spec/test_data/ccr/trivial_ccr.xml"
      results = @validator.validate(nil, xml)
      results.empty?.should be_true
    end
  
    it "should test against non-trivial xml" do
      xml = "/../spec/test_data/ccr/ccrsample_Allscripts.xml"
      results = @validator.validate(nil, xml)
      results.empty?.should be_false
    end
  
    it "should run against all the available ccrs" do
      Dir[File.dirname(__FILE__) + "/../../test_data/ccr/ccr*.xml"].each do |f|
        results = nil
        results = @validator.validate(nil, "../#{f}")
        results.empty?.should be_false 
      end
    end
  
    after(:all) do 
      java.lang.System.set_out(@old_out)
    end

  end # spec


end # if ccr validator exists
