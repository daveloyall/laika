class AddExceptionToContentError < ActiveRecord::Migration
  def self.up
    add_column :content_errors, :exception, :text
  end

  def self.down
    remove_column :content_errors, :exception
  end
end
