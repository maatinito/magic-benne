# == Schema Information
#
# Table name: task_executions
#
#  id          :integer          not null, primary key
#  dossier     :integer
#  failed      :boolean
#  version     :float
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  job_task_id :integer          not null
#
# Indexes
#
#  index_task_executions_on_dossier      (dossier)
#  index_task_executions_on_failed       (failed)
#  index_task_executions_on_job_task_id  (job_task_id)
#
# Foreign Keys
#
#  job_task_id  (job_task_id => job_tasks.id)
#
FactoryBot.define do
  factory :task_execution do
    failed { false }
    dossier { 1 }
    job_task { create(:job_task) }
  end
end
