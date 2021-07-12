# frozen_string_literal: true
class ChangeDataTypeForVersion < ActiveRecord::Migration[6.0]
  def self.up
    change_table :task_executions do |t|
      t.change :version, :bigint
    end
  end

  def self.down
    change_table :task_executions do |t|
      t.change :version, :float
    end
  end
end
