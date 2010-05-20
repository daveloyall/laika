require 'test/unit'
require 'rubygems'
require 'sqlite3'
require 'active_support'
require 'active_support/test_case'
require 'active_record'

require "#{File.dirname(__FILE__)}/../init"

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

def setup_db
  silence_stream(STDOUT) do 
    ActiveRecord::Schema.define(:version => 1) do
      create_table :documents do |t|
        t.column :name, :string
      end
      create_table :multiple_sections do |t|
        t.column :name, :string
        t.column :document_id, :integer
      end
      create_table :single_sections do |t|
        t.column :name, :string
        t.column :document_id, :integer
      end
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end
