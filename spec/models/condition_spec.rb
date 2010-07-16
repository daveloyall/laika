require File.dirname(__FILE__) + '/../spec_helper'

describe Condition, "can validate itself" do
  fixtures :conditions, :problem_types, :snowmed_problems
  
  before(:each) do
    @cond = conditions(:joes_condition)
    @snomed = snowmed_problems(:abdominal_mass_finding)
  end  
  
  it "should validate without errors" do
    document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/conditions/joes_condition.xml'))
    errors = @cond.validate_c32(document.root)
    pending("joes_condition.xml gold data needs to be fixed in order to be valid") do
      errors.should be_empty
    end
  end

  it "should belong to a snowmed_problem" do
    @cond.snowmed_problem.should == @snomed
  end

  it "should have a problem_code accessor for snowmed_problem code" do
    @cond.problem_name.should == @snomed.name
    @cond.problem_code.should == @snomed.code
  end

  it "should handle nil snowmed_problem when problem_name matches nothing" do
    @cond.problem_name = 'foo'
    @cond.snowmed_problem.should be_nil
    @cond.problem_code.should be_nil
  end

end

describe Condition, "can create a C32 representation of itself" do
  fixtures :conditions, :problem_types


  
  it "should create valid C32 content" do
    cond = conditions(:joes_condition)
    
    document = LaikaSpecHelper.build_c32 do |xml|

        xml.component {
          xml.structuredBody {
            xml.component {
              xml.section {
                xml.templateId("root" => "2.16.840.1.113883.10.20.1.11", 
                               "assigningAuthorityName" => "CCD")
                xml.code("code" => "11450-4", 
                         "displayName" => "Problems", 
                         "codeSystem" => "2.16.840.1.113883.6.1", 
                         "codeSystemName" => "LOINC")
                xml.title "Conditions or Problems"
                xml.text {
                  xml.content(cond.problem_name, "ID" => "problem-"+cond.id.to_s) 
                }
                
                cond.to_c32(xml)
              }
            }
          }
        }
       
    end
    
    errors = cond.validate_c32(document.root)
    errors.should be_empty
  end
end
