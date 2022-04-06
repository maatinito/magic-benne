# frozen_string_literal: true

# == Schema Information
#
# Table name: task_executions
#
#  id           :bigint           not null, primary key
#  discarded_at :datetime
#  dossier      :integer
#  failed       :boolean
#  reprocess    :boolean          default(FALSE)
#  version      :bigint
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  job_task_id  :integer          not null
#
# Indexes
#
#  index_task_executions_on_discarded_at             (discarded_at)
#  index_task_executions_on_dossier                  (dossier)
#  index_task_executions_on_dossier_and_job_task_id  (dossier,job_task_id) UNIQUE
#  index_task_executions_on_failed                   (failed)
#  index_task_executions_on_job_task_id              (job_task_id)
#
# Foreign Keys
#
#  fk_rails_...  (job_task_id => job_tasks.id)
#
require 'rails_helper'

RSpec.describe TaskExecution, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
