require File.dirname(__FILE__) + '/../../spec_helper'

describe Validators::C32Descriptors do

  it "should produce a descriptor hash" do
    languages = Validators::C32Descriptors.get_component(:languages)
    languages.should be_kind_of ComponentDescriptors::Component
    repeating_section_template = languages.values.first
    repeating_section_template.values.first.size.should == 3
  end

end
