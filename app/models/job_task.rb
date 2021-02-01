# frozen_string_literal: true

# == Schema Information
#
# Table name: job_tasks
#
#  id          :integer          not null, primary key
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  demarche_id :integer          not null
#
# Indexes
#
#  index_job_tasks_on_demarche_id  (demarche_id)
#
# Foreign Keys
#
#  demarche_id  (demarche_id => demarches.id)
#
class JobTask < ApplicationRecord
  belongs_to :demarche
  has_many :task_execution, dependent: :destroy
end
