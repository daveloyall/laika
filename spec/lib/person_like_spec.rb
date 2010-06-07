require File.dirname(__FILE__) + '/../spec_helper'

describe PersonLike do
  it "should find a PersonLike model with some attributes to not be blank" do
    ri = RegistrationInformation.new
    name = PersonName.new
    name.first_name = 'Andy'
    ri.person_name = name
    ri.person_blank?.should be_false
  end
  
  it "should find a PersonLike model with no attributes to be blank" do
    ri = RegistrationInformation.new
    ri.person_blank?.should be_true
  end

  it "should provide direct accessors for first and last name" do
    ri = RegistrationInformation.new(:person_name => PersonName.new( :first_name => 'Foo', :last_name => 'Bar' ))
    ri.full_name.should == 'Foo Bar'
    ri.first_name.should == 'Foo'
    ri.last_name.should == 'Bar'
  end
end
