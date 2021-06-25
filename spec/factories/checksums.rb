# frozen_string_literal: true

# == Schema Information
#
# Table name: checksums
#
#  id                :integer          not null, primary key
#  filename          :string
#  md5               :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  task_execution_id :integer          not null
#
# Indexes
#
#  index_checksums_on_md5                             (md5)
#  index_checksums_on_task_execution_id               (task_execution_id)
#  index_checksums_on_task_execution_id_and_filename  (task_execution_id,filename)
#
# Foreign Keys
#
#  task_execution_id  (task_execution_id => task_executions.id)
#
FactoryBot.define do
  factory :checksum do
    task_execution { create(task_execution) }
    filename { 'bonjour.txt' }
    md5 { 'f02368945726d5fc2a14eb576f7276c0' }
  end
end
