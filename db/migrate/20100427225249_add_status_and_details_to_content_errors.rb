class AddStatusAndDetailsToContentErrors < ActiveRecord::Migration
  def self.up
    change_table :content_errors do |t|
      t.integer :parent_id
      t.text :expected, :provided
      t.string :state, :status_override_reason, :error_type
    end
  end

  def self.down
    change_table :content_errors do |t|
      t.remove :parent_id, :expected, :provided, :state, :status_override_reason, :error_type
    end
  end
end
