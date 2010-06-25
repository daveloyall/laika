require 'spec'
require 'spec/autorun'
require 'nokogiri'
require 'laika_medical_document'

module LaikaMedicalDocument
  SPEC_ROOT = File.dirname(__FILE__)
  SPEC_TEST_DATA = File.join(SPEC_ROOT,'test_data')

  module TestFileHelper

    # Find the given file in the spec/test_data directory, read it
    # and return it as a String.
    def get_test_file(file_name)
      File.read(File.join(SPEC_TEST_DATA, file_name))
    end

    # Find the given file in the spec/test_data directory, read it
    # and return it as a Nokogiri::XML::Document
    def get_test_file_as_nokogiri_document(file_name)
      Nokogiri.parse(get_test_file(file_name))
    end

  end
end


Spec::Runner.configure do |config|
  include LaikaMedicalDocument::TestFileHelper 
end
