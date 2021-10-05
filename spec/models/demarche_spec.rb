# frozen_string_literal: true

# == Schema Information
#
# Table name: demarches
#
#  id         :bigint           not null, primary key
#  name       :string
#  queried_at :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require 'rails_helper'

RSpec.describe Demarche, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
