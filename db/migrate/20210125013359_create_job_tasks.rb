# frozen_string_literal: true

class CreateJobTasks < ActiveRecord::Migration[6.0]
  def change
    create_table :job_tasks do |t|
      t.belongs_to :demarche, null: false, foreign_key: true
      t.string :name

      t.timestamps
    end
  end
end
