require File.dirname(__FILE__) + '/../spec_helper'

describe ContentError do

  before do
    @error = ContentError.factory.create
  end

  it "should have no children when initialized" do
    @error.children.should be_empty
  end

  it "should be possible to add children" do
    error = @error
    error.children << ContentError.factory.create
    error.children << ContentError.factory.create
    error.children.count.should == 2
  end

  it "should have a parent" do
    parent = @error
    parent.children << (child = ContentError.factory.create)
    child.parent.should == parent
  end

  it "should initialize in the failed state" do
    @error.state.should == 'failed'
  end

  it "should shift to passed if pass is called" do
    @error.tap(&:pass).state.should == 'passed'
  end

  it "should shift to review if review is called" do
    @error.tap(&:review).state.should == 'review'
  end

  it "should shift to failed if fail is called" do
    @error.tap(&:fail).state.should == 'failed'
  end

  describe "from validation errors" do

    before do
      @validation_error = Laika::ValidationError.new(
        :section         => 'section',
        :subsection      => 'subsection',
        :field_name      => 'field',
        :message         => 'foo',
        :location        => '//xpath',
        :severity        => 'error',
        :validator       => 'test',
        :inspection_type => 'conversion'
      )
    end

    it "should construct a content error given a Laika Validation::Error" do
      content_error = ContentError.from_validation_error!(@validation_error)
      content_error.should be_kind_of(ContentError)
      content_error.section.should == 'section'
      content_error.subsection.should == 'subsection'
      content_error.field_name.should == 'field'
      content_error.error_message.should == 'foo'
      content_error.location.should == '//xpath'
      content_error.msg_type.should == 'error'
      content_error.validator.should == 'test'
      content_error.inspection_type.should == 'conversion'
      content_error.error_type.should == 'ValidationError'
      content_error.children.should be_empty
    end

    it "should set expected and provided if methods are present" do
      content_error = ContentError.from_validation_error!(Laika::ComparisonError.new(:validator => 'test', :expected => 'expected', :provided => 'provided'))
      content_error.error_type.should == 'ComparisonError'
      content_error.expected.should == 'expected'
      content_error.provided.should == 'provided'
    end

    it "should set expected_section and provided_sections if methods are present" do
      content_error = ContentError.from_validation_error!(Laika::SectionMissing.new(:validator => 'test', :expected_section => { :foo => :bar }, :provided_sections => []))
      content_error.error_type.should == 'SectionMissing'
      content_error.expected_section.should == { :foo => :bar }
      content_error.provided_sections.should == []
    end
    describe "with nested errors" do

      before do
        fields = { :validator => 'conversion' }
        @validation_error.suberrors << (@bar = Laika::ValidationError.new(fields.merge(:message => 'bar')))
        @validation_error.suberrors << (@baz = Laika::ValidationError.new(fields.merge(:message => 'baz')))
        @bar.suberrors << (@grandchild = Laika::ValidationError.new(fields.merge(:message => 'grandchild')))
        @content_error = ContentError.from_validation_error!(@validation_error)
      end

      it "should handle trees of validation errors" do
        @content_error.children.should_not be_empty
        @content_error.children.size.should == 2
      end

      it "should reach recursively into descendants" do
        @content_error.children.first.children.first.error_message.should == 'grandchild'
      end 
    end
  end
end
