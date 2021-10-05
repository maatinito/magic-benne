# frozen_string_literal: true

# == Schema Information
#
# Table name: demarches
#
#  id         :bigint           not null, primary key
#  name       :string
#  queried_at :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :demarche do
    name { 'MyString' }
    queried_at { '2020-12-29 11:08:29' }
  end
end
