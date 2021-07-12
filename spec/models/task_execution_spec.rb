# frozen_string_literal: true

# == Schema Information
#
# Table name: task_executions
#
#  id           :integer          not null, primary key
#  discarded_at :datetime
#  dossier      :integer
#  failed       :boolean
#  version      :bigint
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  job_task_id  :integer          not null
#
# Indexes
#
#  index_task_executions_on_discarded_at  (discarded_at)
#  index_task_executions_on_dossier       (dossier)
#  index_task_executions_on_failed        (failed)
#  index_task_executions_on_job_task_id   (job_task_id)
#
# Foreign Keys
#
#  job_task_id  (job_task_id => job_tasks.id)
#
require 'rails_helper'

RSpec.describe TaskExecution, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
