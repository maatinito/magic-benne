# frozen_string_literal: true

# == Schema Information
#
# Table name: attributes
#
#  id          :bigint           not null, primary key
#  dossier     :integer
#  task        :string
#  value       :string
#  variable    :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  demarche_id :integer          not null
#
# Indexes
#
#  index_attributes_on_demarche_id  (demarche_id)
#  index_attributes_on_dossier      (dossier)
#  index_attributes_on_variable     (variable)
#
# Foreign Keys
#
#  fk_rails_...  (demarche_id => demarches.id)
#
require 'rails_helper'

RSpec.describe Attribute, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
