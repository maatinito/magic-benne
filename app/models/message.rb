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
class Message < ApplicationRecord
  ERROR = 0
  WARN = 1
  INFO = 2
  DEBUG = 3

  LEVELS = %w[Erreur Attention Information Trace].freeze

  belongs_to :task_execution

  def hashkey
    (message || '') + level.to_s
  end

  def ==(other)
    message == other.message &&
      level == other.level
  end

  def level_string
    level >= 0 && level < LEVELS.size ? LEVELS[level] : 'Inconnu'
  end
end
