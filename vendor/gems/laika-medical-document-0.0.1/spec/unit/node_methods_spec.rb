require 'spec_helper'
require 'laika_medical_document/node_methods'

module LaikaMedicalDocument

  class NodeMethodsTester
    include NodeMethods

    def initialize(node)
      @node = node
    end
  end

  describe NodeMethods do

    it "should initialize and set the node" do
      importer = NodeMethodsTester.new("foo")
      importer.node.should == "foo"
    end

    it "should not have a node setter" do
      NodeMethodsTester.new("foo").should_not respond_to :node=
    end

    it "should perform an xpath check on a node" do
      mocknode = mock("Node")
      mocknode.should_receive(:xpath).once.and_return([])
      importer = NodeMethodsTester.new(mocknode) 
      importer.xpath('foo').should == []
    end

    it "should return an empty hash for namespaces" do
      NodeMethodsTester.new("foo").namespaces.should == {} 
    end

    context "when matching first text" do

      before(:each) do
        @joe = get_test_file_as_nokogiri_document('c32/joe_c32.xml').remove_namespaces!
      end

      it "should get text of the first matching node" do
        NodeMethodsTester.new(@joe.root).first_text('//patient/name/given').should == 'Joe'
        NodeMethodsTester.new(@joe.root).first_text('//patient/name/family').should == 'Smith'
      end 

      it "should handle cases where no node is found" do
        NodeMethodsTester.new(@joe.root).first_text('foo/bar').should be_nil 
      end

    end

  end

end
