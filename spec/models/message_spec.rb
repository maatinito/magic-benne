# frozen_string_literal: true

# == Schema Information
#
# Table name: messages
#
#  id                :bigint           not null, primary key
#  level             :integer
#  message           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  task_execution_id :bigint           not null
#
# Indexes
#
#  index_messages_on_level              (level)
#  index_messages_on_task_execution_id  (task_execution_id)
#
# Foreign Keys
#
#  fk_rails_...  (task_execution_id => task_executions.id)
#
require 'rails_helper'

RSpec.describe Message, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
