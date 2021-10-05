class AddReprocessToTaskExecutions < ActiveRecord::Migration[6.0]
  def change
    add_column :task_executions, :reprocess, :boolean, default: false
  end
end
