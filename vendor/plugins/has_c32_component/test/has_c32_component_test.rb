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
    Document.has_many_c32 :multiple_sections, :component_module => 'foo'
    d = Document.new
    assert_equal :foo, d.multiple_sections.component_module
  end

  def test_can_provide_section_name_option_to_has_one_c32
    Document.has_one_c32 :single_section, :component_module => :foo
    d = Document.new
    d.single_section = SingleSection.new
    assert_equal :foo, d.single_section.component_module
  end

  def test_section_name_default_for_has_many_c32
    Document.has_many_c32 :multiple_sections
    d = Document.new
    assert_equal :multiple_sections, d.multiple_sections.component_module
  end

  def test_section_name_default_for_has_one_c32
    Document.has_one_c32 :single_section
    d = Document.new
    d.single_section = SingleSection.new
    assert_equal :single_section, d.single_section.component_module
  end

  def test_component_name_key
    Document.has_one_c32 :single_section, :component_module => 'Bacon and eggs'
    d = Document.new
    d.single_section = SingleSection.new
    assert_equal :bacon_and_eggs, d.single_section.component_module
  end

  def test_c32_reflection
    Document.has_many_c32 :multiple_sections
    Document.has_many_c32 :more_sections, :class_name => 'MultipleSection', :component_module => 'different_c32_name'
    reflection_with_default_component = Document.reflect_on_association(:multiple_sections)
    reflection_with_custom_component = Document.reflect_on_association(:more_sections) 
    assert_equal :multiple_sections, reflection_with_default_component.c32_component_module_name
    assert_equal :different_c32_name, reflection_with_custom_component.c32_component_module_name
  end
end
