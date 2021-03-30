# frozen_string_literal: true

# == Schema Information
#
# Table name: demarches
#
#  id         :integer          not null, primary key
#  name       :string
#  queried_at :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Demarche < ApplicationRecord
  has_many :job_tasks, dependent: :destroy
  has_and_belongs_to_many :instructeurs, class_name: 'User'
end
