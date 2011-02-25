class AddStatusCodeIdToAbstractResult < ActiveRecord::Migration
  def self.up
    add_column :abstract_results, :status_code_id, :integer
    execute('update abstract_results set status_code_id = act_status_codes.id from act_status_codes where abstract_results.status_code = act_status_codes.code')
    remove_column :abstract_results, :status_code
  end

  def self.down
    add_column :abstract_results, :status_code, :string
    execute('update abstract_results set status_code = act_status_codes.code from act_status_codes where abstract_results.status_code_id = act_status_codes.id')
    remove_column :abstract_results, :status_code
  end
end
