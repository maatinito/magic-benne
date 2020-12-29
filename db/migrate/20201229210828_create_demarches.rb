# frozen_string_literal: true

class CreateDemarches < ActiveRecord::Migration[6.0]
  def change
    create_table :demarches do |t|
      t.string :name
      t.datetime :queried_at

      t.timestamps
    end
  end
end
