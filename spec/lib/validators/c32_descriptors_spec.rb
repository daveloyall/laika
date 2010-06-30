require File.dirname(__FILE__) + '/../../spec_helper'

describe Validators::C32Descriptors do

  it "should produce a descriptor hash" do
    descriptors = Validators::C32Descriptors.descriptors
    pp descriptors

    pp "\n\n\nneed to figure out SectionArray is both hash and array...\n\n\n"
  end

end
