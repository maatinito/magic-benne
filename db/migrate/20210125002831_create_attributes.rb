class CreateAttributes < ActiveRecord::Migration[6.0]
  def change
    create_table :attributes do |t|
      t.string :task
      t.string :variable
      t.string :value

      t.timestamps
    end
  end
end
