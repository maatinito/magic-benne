# frozen_string_literal: true

# == Schema Information
#
# Table name: syncs
#
#  id         :bigint           not null, primary key
#  job        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require 'rails_helper'

RSpec.describe Sync, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
