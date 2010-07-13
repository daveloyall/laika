require File.dirname(__FILE__) + '/../../spec_helper'

describe Validators::C32Descriptors do

  it "should produce a descriptor hash" do
    languages = Validators::C32Descriptors.get_component(:languages)
    languages.should be_kind_of ComponentDescriptors::ComponentModule
    languages.size.should == 3
    languages.repeats?.should be_true
    languages.pretty_inspect.should =~ %r|<RepeatingSection:\d+ :languages => "//cda:recordTarget/cda:patientRole/cda:patient/cda:languageCommunication" :index_key => :languages
  @options = {:matches_by=>:language_code}
  :language_code => <Field:\d+ :language_code => "cda:languageCode/@code" :index_key => :languages_language_code>
  :language_ability_mode => <Field:\d+ :language_ability_mode => "cda:modeCode/@code" :index_key => :languages_language_ability_mode
    @options = {:required=>false, :reference=>:language_ability_mode_code}
  >
  :preference => <Field:\d+ :preference => "cda:preferenceInd/@value" :index_key => :languages_preference
    @options = {:required=>false}
  >
>|
  end

end
