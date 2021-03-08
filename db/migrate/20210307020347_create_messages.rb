# frozen_string_literal: true

class CreateMessages < ActiveRecord::Migration[6.0]
  def change
    create_table :messages do |t|
      t.string :message
      t.integer :level, index: true
      t.belongs_to :task_execution, null: false, foreign_key: true

      t.timestamps
    end
  end
end
