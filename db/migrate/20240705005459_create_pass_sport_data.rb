# frozen_string_literal: true

class CreatePassSportData < ActiveRecord::Migration[6.1]
  def change
    create_table :pass_sport_data do |t|
      t.integer :dossier, null: false
      t.string :siret, null: false
      t.string :status
      t.boolean :eligible
      t.boolean :invoices_verified
      t.string :cps_feedback_checksum

      t.timestamps
    end

    # Ajout des index
    add_index :pass_sport_data, :dossier, unique: true
    add_index :pass_sport_data, :siret
  end
end
