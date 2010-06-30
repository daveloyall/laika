require File.dirname(__FILE__) + '/../spec_helper'

module Testing
  include ComponentDescriptors
end

describe ComponentDescriptors do

  it "should create a lazily initalized accessor for a descriptors hash" do
    flunk "fails if whole test is run because descriptors is not reset between tests..."
    Testing.descriptors.should == {}
    Testing.descriptors[:foo] = :bar
    Testing.descriptors.should == {:foo => :bar}
  end

  describe "parse_args" do

    before do
      @component = ComponentDescriptors::Component.new(:foo)
    end

    it "should raise an error on no args" do
      lambda { @component.parse_args([], []) }.should raise_error(ComponentDescriptors::DescriptorArgumentError)
    end

    it "should parse a single argument" do
      @component.parse_args([:foo], []).should == [:foo, nil, {}]
    end

    it "should parse an arg and an option hash" do
      @component.parse_args([:foo, {:option => :bar}], []).should == [:foo, nil, {:option => :bar}]
    end

    it "should parse two hashes" do
      @component.parse_args([{:foo => :bar}, {:option => :baz}], []).should == [:foo, :bar, {:option => :baz}]
    end

    it "should parse a single hash" do
      @component.parse_args([{:foo => :bar}], [:option]).should == [:foo, :bar, {}]
    end

    it "should parse a single hash with options" do
      @component.parse_args([{:foo => :bar, :option => :baz}], [:option]).should == [:foo, :bar, {:option => :baz}]
    end

    it "should raise an error if unable to determine the key/locator pair" do
      lambda { @component.parse_args([{:foo => :bar, :option => :baz}], []).should == [:foo, :bar, {:option => :baz}] }.should raise_error(ComponentDescriptors::DescriptorArgumentError)
    end

    it "should raise an error for more than two args" do
      lambda { @component.parse_args([1,2,3], []) }.should raise_error(ComponentDescriptors::DescriptorArgumentError)
    end

    it "should raise an error if second arg is not a hash" do
      lambda { @component.parse_args([1,2], []) }.should raise_error(ComponentDescriptors::DescriptorArgumentError)
    end

  end

  describe "components" do

    it "should create a components hash" do
      Testing.components(:foo).should be_true
      Testing.descriptors.should == { :foo => {} }
    end

    it "should parse options" do
      lambda { Testing.components }.should raise_error(ArgumentError)
      Testing.components(:foo)
      Testing.components(:foo, :bar => :dingo)
    end

  end

  describe "Component" do

    before do
      @component = ComponentDescriptors::Component.new(:test)
    end

    it "should build a section if given a template_id" do
      tid = '2.16.840.1.113883.10.20.1.8'
      ComponentDescriptors::Component.new(:foo, :template_id => tid ).should == { tid => {} }
    end

    it "should create a section hash" do
      @component.section(:bar).should == { :bar => {} }
    end

    it "should include subsections if passed a block" do
      @component.section(:bar) do
        section(:baz)
        section(:dingo)
      end.should == { :bar => {
          :baz => {},
          :dingo => {},
        }
      }
    end

    it "should create a new field" do
      @component.field(:bar).should == { :bar => ComponentDescriptors::Field.new(:bar, nil, {}) }
    end

  end

  describe "SectionArray" do

    it "should initialize" do
      ComponentDescriptors::SectionArray.new('foo', nil, nil).should be_kind_of(ComponentDescriptors::SectionArray)
    end

  end

  describe "Section" do
  
    it "should initialize" do
      ComponentDescriptors::Section.new(:bar, nil, nil).should be_kind_of(ComponentDescriptors::Section)
    end
 
  end

  describe "Field" do
    
    it "should initialize" do
      ComponentDescriptors::Field.new(:foo, nil, nil).should be_kind_of(ComponentDescriptors::Field)
    end

    it "should define equality" do
      ComponentDescriptors::Field.new(:foo, 'bar', {:baz => :dingo}).should == ComponentDescriptors::Field.new(:foo, 'bar', {:baz => :dingo})
      ComponentDescriptors::Field.new(:foo, 'bar', {:baz => :dingo}).hash.should == ComponentDescriptors::Field.new(:foo, 'bar', {:baz => :dingo}).hash
    end
  end

end
