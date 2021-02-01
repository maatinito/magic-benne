# frozen_string_literal: true

class AddDossierToAttribute < ActiveRecord::Migration[6.0]
  def change
    add_column :attributes, :dossier, :integer
    add_index :attributes, :dossier
  end
end
