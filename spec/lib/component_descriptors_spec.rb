require File.dirname(__FILE__) + '/../spec_helper'

module Testing
  include ComponentDescriptors
end

describe ComponentDescriptors do

  after do
    Testing.descriptors.clear
  end

  it "should create a lazily initalized accessor for a descriptors hash" do
    Testing.descriptors.should == {}
    Testing.descriptors[:foo] = :bar
    Testing.descriptors.should == {:foo => :bar}
  end

  describe "HashExtensions" do

    class TestHash < ComponentDescriptors::DescriptorHash
      include ComponentDescriptors::NodeTraversal
    end
    class TestLeaf; include ComponentDescriptors::NodeTraversal; end

    before do
      @r = TestHash.new
      @r.store(:child, @c = TestHash[:child => TestLeaf.new])
    end

    it "should raise an error if node has no parent method" do
      lambda { @r.store(:foo, :bar) }.should raise_error(NoMethodError)
    end

    it "should reference parent" do
      @c.parent.should == @r
    end

    it "should allow a child to find the root node" do
      @c.root.should == @r
    end
    
    it "should allow a descendent to find the root node" do
      @c.store(:grandchild, d = TestHash.new)
      d.parent.should == @c
      d.root.should == @r
    end

    it "should allow root to find the root node" do
      @r.root.should == @r
    end

    it "should find a particular descendent" do
      @r.descendent(:child).should == @c
    end

    it "should return nil if no descendent matches" do
      @r.descendent(:foo).should be_nil
    end

    it "should handle non-hash leaves" do
      @r.store(:foo, TestLeaf.new)
      @r.descendent(:dingo).should be_nil
    end

    it "should find a particular descendent at arbitrary depth" do
      @c.store(:grandchild1, g1 = TestHash[:grandchild1 => TestLeaf.new])
      @c.store(:grandchild2, g2 = TestHash[:grandchild2 => TestLeaf.new])
      g2.store(:greatgrandchild1, gg1 = TestHash[:greatgrandchild1 => TestLeaf.new])
      g2.store(:greatgrandchild2, gg2 = TestHash[:greatgrandchild2 => TestLeaf.new])
      @r.descendent(:grandchild1).should == g1
      @r.descendent(:grandchild2).should == g2
      @r.descendent(:greatgrandchild1).should == gg1
      @r.descendent(:greatgrandchild2).should == gg2
      @c.descendent(:grandchild1).should == g1
      @c.descendent(:grandchild2).should == g2
      @c.descendent(:greatgrandchild1).should == gg1
      @c.descendent(:greatgrandchild2).should == gg2
    end
  end

  describe "Logging" do

    class TestLogging < Hash
      include ComponentDescriptors::HashExtensions
      include ComponentDescriptors::NodeTraversal
      include ComponentDescriptors::Logging
    end

    before do
      @l = TestLogging.new
      @mock_logger = mock("logger")
    end

    it "should use logger if logger is set" do
      @l.logger = @mock_logger
      @mock_logger.should_receive(:debug).once.with("ComponentDescriptors : foo")
      @l.debug("foo")
    end

    it "should print to STDERR if logger is not set" do
      silence_warnings do
        old_fallback = ComponentDescriptors::Logging::FALLBACK
        ComponentDescriptors::Logging::FALLBACK = @mock_logger
        @mock_logger.should_receive(:puts).once.with("DEBUG : ComponentDescriptors : foo")
        @l.debug("foo")
        ComponentDescriptors::Logging::FALLBACK = old_fallback
      end
    end

    it "should use logger if root logger is set" do
      @l.logger = @mock_logger
      @mock_logger.should_receive(:debug).once.with("ComponentDescriptors : foo")
      @l.store(:bar, c = TestLogging.new)
      c.debug("foo")
    end

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

    it "should parse original arguments with injected options" do
      @component.parse_args([[{:foo => :bar, :option => :baz}], {:injected => :option}], [:option]).should == [:foo, :bar, {:option => :baz, :injected => :option}]
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

    it "should create a component definitions hash" do
      Testing.components(:foo).should be_true
      Testing.descriptors[:foo].should be_kind_of(ComponentDescriptors::ComponentDefinition)
    end

    it "should parse options" do
      lambda { Testing.components }.should raise_error(ArgumentError)
      Testing.components(:foo)
      Testing.components(:foo, :bar => :dingo)
    end

    it "should be possible to instantiate a defined component" do
      Testing.components(:foo) do
        field(:bar)
      end
      Testing.get_component(:foo).should == { :bar => ComponentDescriptors::Field.new(:bar, nil, nil) }
    end

  end

  describe "ComponentDefinition" do
    
    it "should retain all the component definition arguments" do
      i = 0
      cd = ComponentDescriptors::ComponentDefinition.new(:foo) do 
        i += 1 
      end
      cd.name.should == :foo
      c = cd.instantiate
      i.should == 1
    end

  end

  describe "Descriptors" do

    class Foo; include ComponentDescriptors::DescriptorInitialization; end

    before do
      @template_id = '1.2.3.4.5'
    end
  
    it "should be required if no required option set" do
      Foo.new(:foo, nil, nil)
      Foo.new(:foo, nil, nil).required?.should be_true 
    end

    it "should not be required if required option is false" do
      Foo.new(:foo, nil, :required => false).required?.should be_false
    end

    it "should be requied if required option is true" do
      Foo.new(:foo, nil, :required => true).required?.should be_true 
    end

    it "should identify template_id from key" do
      foo = Foo.new(@template_id, nil, nil)
      foo.key.should == @template_id
      foo.template_id.should == @template_id
    end
 
    it "should identify template_id from options" do
      foo = Foo.new(:a_section, nil, :template_id => @template_id)
      foo.key.should == :a_section
      foo.template_id.should == @template_id
    end

    it "should construct a locator based on template_id if there is no locator" do
      foo = Foo.new(@template_id, nil, nil)
      foo.locator.should == "//cda:section[./cda:templateId[@root = '#{@template_id}']]"
    end

    it "should construct a locator based on key as element" do
      foo = Foo.new(:element_name, nil, nil)
      foo.locator.should == "cda:elementName"
    end

    it "should construct a locator based on key as attribute" do
      foo = Foo.new(:element_name, nil, {:locate_by => :attribute})
      foo.locator.should == "@elementName"
    end

    it "should assume key as locator if key seems to be an xpath expression" do
      foo = Foo.new('ns:element', nil, nil)
      foo.locator.should == 'ns:element'
    end

    TEST_XML = <<-EOS
<?xml version="1.0" encoding="UTF-8"?>
<ClinicalDocument
   xmlns="urn:hl7-org:v3" xmlns:sdct="urn:hl7-org:sdct">
   <recordTarget>
      <patientRole>
         <patient>
            <languageCommunication>
               <templateId root='2.16.840.1.113883.3.88.11.32.2' />
               <languageCode code="en-US" />
               <modeCode code='RWR' displayName='Recieve Written'
                  codeSystem='2.16.840.1.113883.5.60'
                  codeSystemName='LanguageAbilityMode' />
               <preferenceInd value='true' />
            </languageCommunication>
            <languageCommunication>
               <templateId root='2.16.840.1.113883.3.88.11.32.2' />
               <languageCode code="de-DE" />
               <modeCode code='RSP' displayName='Recieve Spoken'
                  codeSystem='2.16.840.1.113883.5.60'
                  codeSystemName='LanguageAbilityMode' />
               <preferenceInd value='false' />
            </languageCommunication>
         </patient>
      </patientRole>
   </recordTarget>
</ClinicalDocument>
EOS

    it "should find the innermost element" do
      document = @document = REXML::Document.new(TEST_XML)
      foo = Foo.new(:foo, nil, nil)
      foo.find_innermost_element('/foo/bar', @document.root).xpath.should == '/ClinicalDocument'
      foo.find_innermost_element('//foo/bar', @document.root).xpath.should == '/ClinicalDocument'
      foo.find_innermost_element('foo/bar', @document.root).xpath.should == '/ClinicalDocument'

      language = foo.find_innermost_element('//cda:recordTarget/cda:patientRole/cda:patient/cda:languageCommunication/bar', @document.root)

      foo.find_innermost_element("cda:languageCode[@code='en-US']", language).xpath.should == '/ClinicalDocument/recordTarget/patientRole/patient/languageCommunication[1]/languageCode'
      foo.find_innermost_element("cda:languageCode[@code='foo']", language).xpath.should == '/ClinicalDocument/recordTarget/patientRole/patient/languageCommunication[1]/languageCode'
      foo.find_innermost_element("cda:modeCode/@code]", language).xpath.should == '/ClinicalDocument/recordTarget/patientRole/patient/languageCommunication[1]/modeCode'
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

  describe "RepeatingSection" do

    it "should initialize" do
      ComponentDescriptors::RepeatingSection.new('foo', nil, nil).should be_kind_of(ComponentDescriptors::RepeatingSection)
    end

    it "should instantiate a template subsection" do
      rs = ComponentDescriptors::RepeatingSection.new('foo', nil, nil) do
        field :bar
      end
      rs.should == { :_repeating_section_template => { :bar => ComponentDescriptors::Field.new(:bar,nil,nil) } } 
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

  describe "attaching" do
   
    before do
      @xml = REXML::Document.new(%Q{<patient xmlns='urn:hl7-org:v3'><foo id='1'><bar baz='dingo'>biscuit</bar></foo><foo id='2'/></patient>})
      @foo, @foo2 = REXML::XPath.match(@xml, '//cda:foo', ComponentDescriptors::NodeManipulation::DEFAULT_NAMESPACES)
      @foo.should_not be_nil
      @logger = nil#TestLoggerDevNull.new
    end
  
    it "should attach an xml node to a section" do
      section = ComponentDescriptors::Section.new(:foo, nil, :logger => @logger)
      section.attach_xml(@xml.root)
      section.extracted_value.should == @foo 
    end

    it "should use custom locators" do
      section = ComponentDescriptors::Section.new(:foo, %Q{//cda:foo[@id='2']}, :logger => @logger)
      section.attach_xml(@xml)
      section.extracted_value.should == @foo2
    end

    it "should extract a text value for a field" do
      field = ComponentDescriptors::Field.new(:bar, nil, :logger => @logger)
      field.attach_xml(@foo)
      field.extracted_value.should == 'biscuit'
    end

    it "should extract a text value for a field with a custom locator" do
      field = ComponentDescriptors::Field.new(:bar, %q{cda:bar/@baz}, :logger => @logger)
      field.attach_xml(@foo)
      field.extracted_value.should == 'dingo'
    end

    it "should extract an array of sections for a repeating section" do
      repeating = ComponentDescriptors::RepeatingSection.new(:foo, nil, :logger => @logger)
      repeating.attach_xml(@xml.root)
      repeating.extracted_value.should == [@foo, @foo2]
    end

    it "should extract an array of sections for a repeating section keyed by xpath" do
      repeating = ComponentDescriptors::RepeatingSection.new('cda:foo', nil, :logger => @logger)
      repeating.attach_xml(@xml.root)
      repeating.extracted_value.should == [@foo, @foo2]
    end

    describe "with nested descriptors" do

      class DummyModel 
        attr_accessor :id, :bar, :baz
        def initialize(id, bar, baz)
          self.id = id
          self.bar =  bar
          self.baz = baz
        end
      end
 
      before do
        @repeating = ComponentDescriptors::RepeatingSection.new(:foo, nil, :logger => @logger) do
          attribute :id
          field :bar
          field :baz => %q{cda:bar/@baz}
        end
      end

      it "should handle a nested set of descriptors" do
        @repeating.attach_xml(@xml.root)
        @repeating.extracted_value.should == [@foo, @foo2]
        @repeating['cda:foo[1]'].extracted_value.should == @foo
        @repeating['cda:foo[1]'][:id].extracted_value.should == '1'
        @repeating['cda:foo[1]'][:bar].extracted_value.should == 'biscuit'
        @repeating['cda:foo[1]'][:baz].extracted_value.should == 'dingo'
        @repeating['cda:foo[2]'].extracted_value.should == @foo2
        @repeating['cda:foo[2]'][:id].extracted_value.should == '2'
        @repeating['cda:foo[2]'][:bar].extracted_value.should be_nil 
        @repeating['cda:foo[2]'][:baz].extracted_value.should be_nil 
      end

      it "should produce a values hash" do
        @repeating.attach_xml(@xml.root)
        values_hash = @repeating.to_values_hash
        values_hash.should be_kind_of(ComponentDescriptors::ValuesHash)
        values_hash.should == {"cda:foo[1]"=>{:id=>"1", :bar=>"biscuit", :baz=>"dingo"}, "cda:foo[2]"=>{:id=>"2", :bar=>nil, :baz=>nil}}
      end

      it "should produce a flattened values hash do" do
        @repeating.attach_xml(@xml.root)
        field_hash = @repeating.to_field_hash
        field_hash.should be_kind_of(ComponentDescriptors::ValuesHash)
        field_hash.should == {:id=>"1", :bar=>"biscuit", :baz=>"dingo", :"cda:foo[2]_id"=>"2", :"cda:foo[2]_bar"=>nil, :"cda:foo[2]_baz"=>nil}
      end

      it "should be possible to make an unattached deep copy of a descriptor" do
        clone = @repeating.copy
        clone.should == @repeating
        clone.should_not be_equal(@repeating) 
      end 

      it "should atach_model" do
        @repeating.attach_xml(@xml.root)
        f1 = DummyModel.new("1", "biscuit", "dingo")
        f2 = DummyModel.new("2", nil, nil)
        clone = @repeating.copy
        puts "attaching model now\n\n\n"
        clone.attach_model([f1, f2])
        clone.to_values_hash.should == @repeating.to_values_hash
      end
    end

  end 

  describe "ValuesHash" do
    
    before do
      @vh = ComponentDescriptors::ValuesHash[
        :foo => :bar, 
        :baz => ComponentDescriptors::ValuesHash[
          :foo => :dingo,
          1 => 2,
        ],
        :rupert => ComponentDescriptors::ValuesHash[
          3 => 4,
          1 => :collision,
          5 => ComponentDescriptors::ValuesHash[:bob => 5],
        ],
      ]
    end

    it "should flatten" do
      @vh.flatten.should == ComponentDescriptors::ValuesHash[ 
        :foo => :bar,
        :baz_foo => :dingo,
        1 => 2,
        :rupert_1 => :collision,
        3 => 4,
        :bob => 5,
      ]
    end

    it "should raise an error if keys collide" do
      @vh[:baz_foo] = :oopsie
      lambda { @vh.flatten }.should raise_error(ComponentDescriptors::DescriptorError)
    end
  end
end
