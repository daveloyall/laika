require 'test_helper'

class Document < ActiveRecord::Base; end
class MultipleSection < ActiveRecord::Base; end
class SingleSection < ActiveRecord::Base; end

class HasC32ComponentTest < ActiveSupport::TestCase


  def setup
    setup_db
  end

  def teardown
    teardown_db
  end

  def test_provides_a_has_many_c32_class_macro
    Document.has_many_c32 :multiple_sections
    d = Document.new
    assert_equal [], d.multiple_sections
  end

  def test_provides_a_has_one_c32_class_macro
    Document.has_one_c32 :single_section
    d = Document.new
    assert_nil d.single_section
  end

  def test_can_provide_section_name_option_to_has_many_c32
    Document.has_many_c32 :multiple_sections, :section => 'foo'
    d = Document.new
    assert_equal 'foo', d.multiple_sections.section
  end

  def test_can_provide_section_name_option_to_has_one_c32
    Document.has_one_c32 :single_section, :section => 'foo'
    d = Document.new
    d.single_section = SingleSection.new
    assert_equal 'foo', d.single_section.section
  end

  def test_section_name_default_for_has_many_c32
    Document.has_many_c32 :multiple_sections
    d = Document.new
    assert_equal 'multiple_sections', d.multiple_sections.section
  end

  def test_section_name_default_for_has_one_c32
    Document.has_one_c32 :single_section
    d = Document.new
    d.single_section = SingleSection.new
    assert_equal 'single_section', d.single_section.section
  end
end
