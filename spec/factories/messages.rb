# frozen_string_literal: true

# == Schema Information
#
# Table name: messages
#
#  id                :integer          not null, primary key
#  level             :integer
#  message           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  task_execution_id :integer          not null
#
# Indexes
#
#  index_messages_on_level              (level)
#  index_messages_on_task_execution_id  (task_execution_id)
#
# Foreign Keys
#
#  task_execution_id  (task_execution_id => task_executions.id)
#
FactoryBot.define do
  factory :message do
    message { 'MyString' }
    level { '' }
    task_execution { nil }
  end
end
