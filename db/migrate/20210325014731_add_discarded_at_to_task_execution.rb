# frozen_string_literal: true

class AddDiscardedAtToTaskExecution < ActiveRecord::Migration[6.0]
  def change
    add_column :task_executions, :discarded_at, :datetime
    add_index :task_executions, :discarded_at
  end
end
