require File.dirname(__FILE__) + '/../spec_helper'

module Testing
  include ComponentDescriptors::Mapping
end

# Set to STDERR or STDOUT for debugging output
Logging.fallback = nil #STDERR

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
      attr_accessor :an_attribute
    end
    class TestLeaf; include ComponentDescriptors::NodeTraversal; end

    before do
      @r = TestHash.new
      @r.store(:child, @c = TestHash.new)
      @c.store(:child, @gc = TestLeaf.new)
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

    it "should find first non-nil ancestor value" do
      @gc.first_ancestors(:an_attribute).should be_nil
      @r.an_attribute = 'at the root'
      @gc.first_ancestors(:an_attribute).should == 'at the root'
      @c.an_attribute = 'at the parent'
      @gc.first_ancestors(:an_attribute).should == 'at the parent'
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

  describe "XMLManipulation" do

    before do
      @document = REXML::Document.new(File.new(RAILS_ROOT + '/spec/test_data/c32v2.5.xml'))
      @section = ComponentDescriptors::Section.new(:foo, nil, nil)
    end

    it "should return nil if extract_first_node is given a nil locator" do
      @section.extract_first_node("", @document.root).should be_nil
      @section.extract_first_node(nil, @document.root).should be_nil
    end

    it "should return empty array if extract_all_nodes is given a nil locator" do
      @section.extract_all_nodes("", @document.root).should == []
      @section.extract_all_nodes(nil, @document.root).should == []
    end

    describe "dereference" do
  
      before do
        @nodes = REXML::XPath.match(@document.root, '//substanceAdministration')
        @nodes.should_not be_empty
        @section = ComponentDescriptors::Section.new(:foo, nil, nil)
        @section.xml = @nodes.first
        @section.stub!(:root_element).and_return(@document.root)
      end
  
      it "should be able to produce a hash of dereferenced subsections" do
        @section.dereference.should == 'Augmentin'
      end
  
      it "should handle attempts to dereference a section without referenced content" do
        @document.elements.delete_all('//text')
        @section.dereference.should be_nil 
      end
  
      it "should handle attempts to dereference a section without references" do
        @document.elements.delete_all('//reference')
        @section.dereference.should be_nil 
      end
    end

  end

  describe "parse_args" do

    before do
      @component = ComponentDescriptors::ComponentModule.new(:foo)
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

    it "should parse unknown keys that reference hashes as overrides" do
      @component.parse_args([:foo => :bar, :matches_by => :bar, :special => { :matches_by => :biscuit }]).should == [:foo, :bar, {:matches_by => :bar, :special => { :matches_by => :biscuit }}]
    end

    it "should not change arguments" do
      original_args = {:foo => :bar, :matches_by => :baz}
      args = original_args.dup
      key, locator, options = @component.parse_args(args)
      args.should == original_args
    end

    it "should not change arguments when references are nested" do
      args = [{:foo => :bar, :matches_by => :baz}]
      key, locator, options = @component.parse_args(args)
      args.should == [{:foo => :bar, :matches_by => :baz}]
    end
  end

  describe "components" do

    it "should create a component definitions hash" do
      Testing.components(:foo).should be_true
      Testing.descriptors[:foo].should be_kind_of(ComponentDescriptors::ComponentDefinition)
    end

    it "should parse options" do
      lambda { Testing.components }.should raise_error(ComponentDescriptors::DescriptorArgumentError)
      Testing.components(:foo)
      Testing.components(:foo, :bar => :dingo)
    end

    it "should retain arguments in component definition" do
      Testing.components(:foo => '//path', :matches_by => :bar)
      definition = Testing.descriptors[:foo]
      definition.descriptor_args.should == [{:foo => '//path', :matches_by => :bar}]
      definition.component_options.should == {:repeats => true}
    end

    it "should be possible to instantiate a defined component" do
      Testing.component(:foo) do
        field(:bar)
      end
      component = Testing.get_component(:foo)
      component.root_descriptor.should be_instance_of(ComponentDescriptors::Section)
      component.root_descriptor.should == { :bar => ComponentDescriptors::Field.new(:bar, nil, :mapping => Testing) }
      component.should == { :bar => ComponentDescriptors::Field.new(:bar, nil, :mapping => Testing) }
    end

    it "should be possible to instantiate a defined repeating component" do
      Testing.components(:foos) do
        field(:bar)
      end
      component = Testing.get_component(:foos)
      component.root_descriptor.should be_instance_of(ComponentDescriptors::RepeatingSection)
      component.root_descriptor.should == { :bar => ComponentDescriptors::Field.new(:bar, nil, :mapping => Testing) }
      component.should == { :bar => ComponentDescriptors::Field.new(:bar, nil, :mapping => Testing) }
    end
  end

  describe "ComponentDefinition" do
    
    it "should retain all the component definition arguments" do
      i = 0
      cd = ComponentDescriptors::ComponentDefinition.new(:foo, {:bar => :baz}) do 
        i += 1 
      end
      cd.descriptor_args.should == :foo
      cd.component_options.should == {:bar => :baz}
      c = cd.instantiate
      c.section_key.should == :foo
      c.options.should == {:bar => :baz}
      i.should == 1
    end

  end

  describe "DescriptorInitialization" do

    class Foo; include ComponentDescriptors::DescriptorInitialization; end

    before do
      @template_id = '1.2.3.4.5'
    end
  
    it "should be required if no required option set" do
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
      foo.section_key.should == @template_id
      foo.template_id.should == @template_id
    end
 
    it "should identify template_id from options" do
      foo = Foo.new(:a_section, nil, :template_id => @template_id)
      foo.section_key.should == :a_section
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
      foo = Foo.new(:attribute_name, nil, {:locate_by => :attribute})
      foo.locator.should == "@attributeName"
    end

    it "should assume key as locator if key seems to be an xpath expression" do
      foo = Foo.new('ns:element', nil, nil)
      foo.locator.should == 'ns:element'
    end

    it "should recognize override to options by validation type" do
      foo = Foo.new(:foo, nil, :matches_by => 'not me', :validation_type => :version_test, :version_test => { :matches_by => 'this' })
      foo.options_by_type(:matches_by).should == 'this'
    end

    DESCRIPTOR_TEST_XML = <<-EOS
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
      document = @document = REXML::Document.new(DESCRIPTOR_TEST_XML)
      foo = Foo.new(:foo, nil, nil)
      foo.find_innermost_element('/foo/bar', @document.root).xpath.should == '/ClinicalDocument'
      foo.find_innermost_element('//foo/bar', @document.root).xpath.should == '/ClinicalDocument'
      foo.find_innermost_element('foo/bar', @document.root).xpath.should == '/ClinicalDocument'

      language = foo.find_innermost_element('//cda:recordTarget/cda:patientRole/cda:patient/cda:languageCommunication/bar', @document.root)

      foo.find_innermost_element("cda:languageCode[@code='en-US']", language).xpath.should == '/ClinicalDocument/recordTarget/patientRole/patient/languageCommunication[1]/languageCode'
      foo.find_innermost_element("cda:languageCode[@code='foo']", language).xpath.should == '/ClinicalDocument/recordTarget/patientRole/patient/languageCommunication[1]/languageCode'
      foo.find_innermost_element("cda:modeCode/@code]", language).xpath.should == '/ClinicalDocument/recordTarget/patientRole/patient/languageCommunication[1]/modeCode'
    end

    describe "mapping accessors" do

      before do
        Testing.descriptors[:bar] = :baz
        @foo = Foo.new(:foo, nil, nil)
      end

      it "be able to set a mapping_class" do
        @foo.mapping_class = Testing
        @foo.mapping_class.should == Testing
      end

      it "should lookup descriptors from mapping class" do
        @foo.mapping_class = Testing
        @foo.mapping(:bar).should == :baz
      end

      it "should read a mapping set from options" do
        foo = Foo.new(:foo, nil, :mapping => Testing)
        foo.mapping_class.should == Testing
        foo.mapping(:bar).should == :baz
      end

      it "should find mapping class from parent" do
        parent = Foo.new(:parent, nil, :mapping => Testing)
        @foo.parent = parent
        @foo.mapping_class.should == Testing
        @foo.mapping(:bar).should == :baz
      end

    end

  end

  describe "Component" do

    before do
      @component = ComponentDescriptors::ComponentModule.new(:test)
    end

    it "should build a section if given a template_id" do
      tid = '2.16.840.1.113883.10.20.1.8'
      component = ComponentDescriptors::ComponentModule.new(:foo, :template_id => tid )
      component.should == ComponentDescriptors::Section.new(nil, nil, :templae_id => tid)
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
      repeats = ComponentDescriptors::RepeatingSection.new(:foo, nil, nil)
      repeats.should be_kind_of(ComponentDescriptors::RepeatingSection)
      repeats.section_key.should == :foo 
    end

    it "should instantiate a template subsection" do
      rs = ComponentDescriptors::RepeatingSection.new(:foo, nil, nil) do
        field :bar
      end
      rs.should == { :bar => ComponentDescriptors::Field.new(:bar,nil,nil) } 
    end

    it "Cannot explicitly set section_key to a known option like :required.  Need to provide explicit options for :section_key and :locator"
  end

  describe "RepeatingSectionInstance" do

    before do
      @ri = ComponentDescriptors::RepeatingSectionInstance.new(nil, nil, :matches_by => :bar) do
        field :bar, :locate_by => :attribute
      end
      @xml = REXML::Document.new("<foo bar='dingo' />")
    end

    it "should lazily initialize its section_key from attached xml" do
      @ri.locator = "foo[1]"
      @ri.unguarded_section_key.should be_nil 
      @ri.xml = @xml
      @ri.section_key.should == [[:bar, "dingo"]]
    end

    it "should lazily initalize its section_key from attached model" do
      @ri.locator = "foo[1]"
      @ri.unguarded_section_key.should be_nil
      @ri.model = { :bar => "dingo" }
      @ri.section_key.should == [[:bar, "dingo"]]
    end

    it "should lazily initialize its locator" do
      @ri.section_key = :dingo
      @ri.unguarded_locator.should be_nil
      @ri.xml = @xml
      @ri.locator.should == "cda:dingo"
    end

    it "should handle requests to section_key when nothing attached yet" do
      @ri.unguarded_locator.should be_nil
      @ri.attached?.should be_false
      @ri.section_key.should be_nil
    end

    it "should handle requests to section_key when no matches_by is set" do
      ri = ComponentDescriptors::RepeatingSectionInstance.new(nil, nil, nil)
      ri.section_key.should be_nil
    end

    it "should produce consistently sorted section_key arrays" do
      ComponentDescriptors::RepeatingSectionInstance.section_key({:b => 2, :a => 1}).should == [[:a, 1], [:b, 2]]
    end

    it "should cope with error situations where two sections have the same key value"
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

  describe "FieldValue" do

    it "should convert to string for ==" do
      ComponentDescriptors::FieldValue.new("foo").should ==  ComponentDescriptors::FieldValue.new("foo")
      ComponentDescriptors::FieldValue.new(:foo).should == ComponentDescriptors::FieldValue.new("foo")
      ComponentDescriptors::FieldValue.new(1).should == ComponentDescriptors::FieldValue.new("1")
    end
  
    it "should handle time conversion when determining equality" do
      ComponentDescriptors::FieldValue.new(Date.new(2010,5,27)).should == ComponentDescriptors::FieldValue.new("20100527")
    end

  end

  describe "attaching" do
   
    before do
      @xml = REXML::Document.new(%Q{<patient xmlns='urn:hl7-org:v3'><foo oid='1'><bar baz='dingo'>biscuit</bar></foo><foo oid='2'/></patient>})
      @foo, @foo2 = REXML::XPath.match(@xml, '//cda:foo', ComponentDescriptors::XMLManipulation::DEFAULT_NAMESPACES)
      @foo.should_not be_nil
      @logger = nil#TestLoggerDevNull.new
    end
 
    it "should extend field xml extracted_value with FieldValue" do
      field = ComponentDescriptors::Field.new(:bar, nil, :logger => @logger)
      field.xml = @foo
      field.extracted_value.should be_kind_of(ComponentDescriptors::FieldValue)
      field.extracted_value.canonical.should == field.extracted_value
    end
 
    it "should extend field model extracted_value with FieldValue" do
      field = ComponentDescriptors::Field.new(:bar, nil, :logger => @logger)
      field.model = { :bar => Date.new(2010,1,2) }
      field.extracted_value.should be_kind_of(ComponentDescriptors::FieldValue)
      field.extracted_value.canonical.should == "20100102"
    end

    it "should attach an xml node to a section" do
      section = ComponentDescriptors::Section.new(:foo, nil, :logger => @logger)
      section.xml = @xml
      section.extracted_value.should == @foo 
    end

    it "should use custom locators" do
      section = ComponentDescriptors::Section.new(:foo, %Q{//cda:foo[@oid='2']}, :logger => @logger)
      section.xml = @xml
      section.extracted_value.should == @foo2
    end

    it "should extract a text value for a field" do
      field = ComponentDescriptors::Field.new(:bar, nil, :logger => @logger)
      field.xml = @foo
      field.extracted_value.should == 'biscuit'
    end

    it "should extract a text value for a field with a custom locator" do
      field = ComponentDescriptors::Field.new(:bar, %q{cda:bar/@baz}, :logger => @logger)
      field.xml = @foo
      field.extracted_value.should == 'dingo'
    end

    it "should extract a reference to a text value for a field" do
      xml = REXML::Document.new(%Q{<patient xmlns='urn:hl7-org:v3'><text ID='12345'>dereferenced text</text><foo oid='2'><bar><reference value='12345'/></bar></foo></patient>})
      field = ComponentDescriptors::Field.new(:bar, %q{cda:foo/cda:bar}, :dereference => true, :logger => @logger)
      field.xml = xml 
      field.extracted_value.should == 'dereferenced text'
    end

    it "should extract an array of sections for a repeating section" do
      repeating = ComponentDescriptors::RepeatingSection.new(:foo, nil, :logger => @logger)
      repeating.xml = @xml.root
      repeating.extracted_value.should == [@foo, @foo2]
    end

    it "should extract an array of sections for a repeating section keyed by xpath" do
      repeating = ComponentDescriptors::RepeatingSection.new('cda:foo', nil, :logger => @logger)
      repeating.xml = @xml.root
      repeating.extracted_value.should == [@foo, @foo2]
    end

    describe "with nested descriptors" do

      class DummyModel 
        attr_accessor :oid, :bar, :baz
        def initialize(oid, bar, baz)
          self.oid = oid
          self.bar = bar
          self.baz = baz
        end
      end
 
      before do
        @repeating = ComponentDescriptors::RepeatingSection.new(:foo, nil, :logger => @logger) do
          attribute :oid
          field :bar
          field :baz => %q{cda:bar/@baz}
        end
      end

      it "should handle a nested set of descriptors" do
        @repeating.xml = @xml.root
        @repeating.extracted_value.should == [@foo, @foo2]
        @repeating['cda:foo[1]'].extracted_value.should == @foo
        @repeating['cda:foo[1]'][:oid].extracted_value.should == '1'
        @repeating['cda:foo[1]'][:bar].extracted_value.should == 'biscuit'
        @repeating['cda:foo[1]'][:baz].extracted_value.should == 'dingo'
        @repeating['cda:foo[2]'].extracted_value.should == @foo2
        @repeating['cda:foo[2]'][:oid].extracted_value.should == '2'
        @repeating['cda:foo[2]'][:bar].extracted_value.should be_nil 
        @repeating['cda:foo[2]'][:baz].extracted_value.should be_nil 
      end

      it "should produce a values hash" do
        @repeating.xml = @xml.root
        values_hash = @repeating.to_values_hash
        values_hash.should be_kind_of(ComponentDescriptors::ValuesHash)
        values_hash.should == {"cda:foo[1]"=>{:oid=>"1", :bar=>"biscuit", :baz=>"dingo"}, "cda:foo[2]"=>{:oid=>"2", :bar=>nil, :baz=>nil}}
      end

      it "should produce a flattened values hash do" do
        @repeating.xml = @xml.root
        field_hash = @repeating.to_field_hash
        field_hash.should be_kind_of(ComponentDescriptors::ValuesHash)
        field_hash.should == {:oid=>"1", :bar=>"biscuit", :baz=>"dingo", :"cda:foo[2]_oid"=>"2", :"cda:foo[2]_bar"=>nil, :"cda:foo[2]_baz"=>nil}
      end

      it "should be possible to make an unattached deep copy of a descriptor" do
        clone = @repeating.copy
        clone.should == @repeating
        clone.should_not be_equal(@repeating) 
      end 

      it "should atach_model" do
        @repeating.xml = @xml
        f1 = DummyModel.new("1", "biscuit", "dingo")
        f2 = DummyModel.new("2", nil, nil)
        clone = @repeating.copy
        clone.model = [f1, f2]
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

    it "should nest multiple levels" do
      pending do
        ComponentDescriptors::ValuesHash[
          :foo => ComponentDescriptors::ValuesHash[
            :baz => 1,
            :bar => ComponentDescriptors::ValuesHash[
              :baz => 2,
            ],
            :dingo => ComponentDescriptors::ValueHash[
              :bing => 5,
            ],
          ],
          :another => ComponentDescriptors::ValuesHash[
            :baz => 3,
            :bar => ComponentDescriptors::ValuesHash[
              :baz => 4,
            ],
            :biscuit => ComponentDescriptors::ValuesHash[
              :bing => 6,
            ],
          ],
        ].flatten.should == {
          :foo_baz         =>1,
          :foo_bar_baz     =>2,
          :dingo_bing      => 5,
          :another_baz     =>3,
          :another_bar_baz =>4,
          :biscuit_bing    => 6,
        }
      end
    end
  end

  describe "indexing" do

    before do
      @base = ComponentDescriptors::Section.new(:base, nil, nil) do
        section :child do 
          field :grand
        end
      end
      @child = @base[:child]
      @grand = @child[:grand]
    end

    it "should provide an index_key" do
      @base.index_key.should == :base
      @child.index_key.should == :base_child
      @grand.index_key.should == :base_child_grand
    end

    it "should provide an index" do
      @base.index.should == {
        :base             => @base,
        :base_child       => @child,
        :base_child_grand => @grand,
      }
    end

    it "should find a descriptor by index" do
      @base.find(:base).should == @base
      @base.find(:base_child).should == @child
      @base.find(:base_child_grand).should == @grand
    end

    it "should find a descriptor by index regardless of current position" do
      @grand.find(:base).should == @base
      @grand.find(:base_child).should == @child
      @grand.find(:base_child_grand).should == @grand 
    end

    it "should find all descriptors in branch" do
      @base.branch.should == [@base, @child, @grand]
      @child.branch.should == [@child, @grand]
      @grand.branch.should == [@grand]
    end

    it "should find all descendants" do
      @base.descendents.should == [@child, @grand]
      @child.descendents.should == [@grand]
      @grand.descendents.should == []
    end

    it "should return all descriptors in tree" do
      @base.all.should == [@base, @child, @grand]
      @child.all.should == [@base, @child, @grand]
      @grand.all.should == [@base, @child, @grand]
    end
 
  end

  describe "pretty printing" do
    
    REPEATING_XML = <<-EOS
<base>
  <biscuits gravy='true' sour_cream='false' />
  <biscuits gravy='false' sour_cream='false' />
</base>
EOS

    before do
      @base = ComponentDescriptors::Section.new(:base, nil, nil) do
        section :child1 => 'foo/bar' do 
          field :grand
        end
        field :child2 => 'thing/path'
        repeating_section :repeating => '//biscuits', :matches_by => :gravy do
          field :gravy, :locate_by => :attribute
          field :sour_cream, :locate_by => :attribute
        end
      end
      @child1 = @base[:child1]
      @grand = @child1[:grand]
      @child2 = @base[:child2]
      @repeats = @base[:repeating]
      @repeating_doc = REXML::Document.new(REPEATING_XML)
    end

    it "should provide concise to_s for section" do
      @base.to_s.should =~ /<Section:\d+ :base => "cda:base" {...} >/
    end

    it "should provide concise to_s for field" do
      @grand.to_s.should =~ /<Field:\d+ :grand => "cda:grand">/
    end

    it "should provide concise to_s for repeating_section" do
      @repeats.to_s.should =~ %r|<RepeatingSection:\d+ :repeating => "//biscuits" {...} >|
    end

    it "should provide concise to_s for repeating_section_instance" do
      @repeats.xml = @repeating_doc
      @repeats.values.first.to_s.should =~ %r|<RepeatingSectionInstance:\d+ \[\[:gravy, "true"]] => "//biscuits\[1]" {...} >|
    end

    it "should provide pretty_printing for section" do
      @base.pretty_inspect.should =~
%r|<Section:\d+ :base => "cda:base" :index_key => :base
  :child1 => <Section:\d+ :child1 => "foo/bar" :index_key => :base_child1
    :grand => <Field:\d+ :grand => "cda:grand" :index_key => :base_child1_grand>
  >
  :child2 => <Field:\d+ :child2 => "thing/path" :index_key => :base_child2>
  :repeating => <RepeatingSection:\d+ :repeating => "//biscuits" :index_key => :base_repeating
    @options = {:matches_by=>:gravy}
    :gravy => <Field:\d+ :gravy => "@gravy" :index_key => :base_repeating_gravy
      @options = {:locate_by=>:attribute}
    >
    :sour_cream => <Field:\d+ :sour_cream => "@sourCream" :index_key => :base_repeating_sour_cream
      @options = {:locate_by=>:attribute}
    >
  >
>|
    end

    it "should provide pretty_printing for field" do
      @grand.pretty_inspect.should =~ %r|<Field:\d+ :grand => "cda:grand" :index_key => :base_child1_grand>|
    end
  end
end
