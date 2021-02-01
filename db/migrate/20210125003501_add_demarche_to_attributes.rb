# frozen_string_literal: true

class AddDemarcheToAttributes < ActiveRecord::Migration[6.0]
  def change
    add_reference :attributes, :demarche, null: false, foreign_key: true
  end
end
