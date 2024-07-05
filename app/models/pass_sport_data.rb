# frozen_string_literal: true

# == Schema Information
#
# Table name: pass_sport_data
#
#  id                    :bigint           not null, primary key
#  cps_feedback_checksum :string
#  dossier               :integer          not null
#  eligible              :boolean
#  siret                 :string           not null
#  status                :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_pass_sport_data_on_dossier  (dossier) UNIQUE
#  index_pass_sport_data_on_siret    (siret)
#
class PassSportData < ApplicationRecord
end
