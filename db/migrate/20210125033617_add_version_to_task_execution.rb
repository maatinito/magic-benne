class AddVersionToTaskExecution < ActiveRecord::Migration[6.0]
  def change
    add_column :task_executions, :version, :float
  end
end
