require File.dirname(__FILE__) + '/../../spec_helper'

[
# [:component_module, :xml_path, :fixture, :model_reference, :repeating],
  [:vital_signs, 'vital_signs/jenny_vital_sign.xml', :abstract_results, :jennifer_thompson_vital_sign, true],
  [:test_results, 'results/jenny_result.xml', :abstract_results, :jennifer_thompson_result, true],
].each do |component_module,xml_path,fixture,model_reference,repeating|

  describe "C83 #{component_module.to_s.titleize} Validation" do
    patient_fixtures
    
    before(:each) do
      @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/' + xml_path))
      @model = send(fixture, model_reference)
      @scope = Validators::C32Validation::ComponentScope.new(
        :validation_type => Validation::C32_V2_5_C83_V2_0_TYPE,
        :logger => TestLoggerDevNull.new,
        :validator => "ComponentScopeTest",
        :inspection_type => "Testing",
        :component_module => component_module,
        :reference_model => repeating ? [@model] : @model,
        :document => @document
      )
    end
  
    it "should verify a #{component_module.to_s.humanize}  matches in a C32 doc" do
      pending "completion of abstract results descriptors" do
        errors = @scope.validate
        pp errors
        errors.should be_empty
      end
    end
  end

end
