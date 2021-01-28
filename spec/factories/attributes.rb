# == Schema Information
#
# Table name: attributes
#
#  id          :integer          not null, primary key
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
#  demarche_id  (demarche_id => demarches.id)
#
FactoryBot.define do
  factory :attribute do
    task { "MyString" }
    variable { "MyString" }
    value { "MyString" }
  end
end
