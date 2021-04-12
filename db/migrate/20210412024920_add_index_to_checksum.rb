class AddIndexToChecksum < ActiveRecord::Migration[6.0]
  def change
    add_index :checksums, %i[task_execution_id filename]
  end
end
