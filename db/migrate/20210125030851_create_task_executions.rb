class CreateTaskExecutions < ActiveRecord::Migration[6.0]
  def change
    create_table :task_executions do |t|
      t.belongs_to :job_task, null: false, foreign_key: true
      t.integer :dossier
      t.boolean :failed

      t.timestamps
    end
    add_index :task_executions, :failed
    add_index :task_executions, :dossier
  end
end
