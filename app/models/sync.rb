# frozen_string_literal: true

# == Schema Information
#
# Table name: syncs
#
#  id         :integer          not null, primary key
#  job        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Sync < ApplicationRecord
end
