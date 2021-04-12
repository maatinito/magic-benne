class CreateChecksums < ActiveRecord::Migration[6.0]
  def change
    create_table :checksums do |t|
      t.references :task_execution, null: false, foreign_key: true

      t.timestamps
    end
  end
end
