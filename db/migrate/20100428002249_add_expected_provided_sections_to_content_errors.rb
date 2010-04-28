class AddExpectedProvidedSectionsToContentErrors < ActiveRecord::Migration
  def self.up
    change_column :content_errors, :expected, :string
    change_column :content_errors, :provided, :string
    change_table :content_errors do |t|
      t.text :expected_section, :provided_sections
    end
  end

  def self.down
    change_column :content_errors, :expected, :text
    change_column :content_errors, :provided, :text
    change_table :content_errors do |t|
      t.remove :expected_section, :provided_sections
    end
  end
end
