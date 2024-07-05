# frozen_string_literal: true

class RemoveInvoicesVerifiedFromPassSportData < ActiveRecord::Migration[6.1]
  def change
    remove_column :pass_sport_data, :invoices_verified, :boolean
  end
end
