# frozen_string_literal: true

class AddUniqueIndexToTaskExecutions < ActiveRecord::Migration[6.0]
  def change
    add_index :task_executions, %i[dossier job_task_id], unique: true
  end
end
