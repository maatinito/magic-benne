# frozen_string_literal: true

# == Schema Information
#
# Table name: checksums
#
#  id                :bigint           not null, primary key
#  filename          :string
#  md5               :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  task_execution_id :bigint           not null
#
# Indexes
#
#  index_checksums_on_md5                             (md5)
#  index_checksums_on_task_execution_id               (task_execution_id)
#  index_checksums_on_task_execution_id_and_filename  (task_execution_id,filename)
#
# Foreign Keys
#
#  fk_rails_...  (task_execution_id => task_executions.id)
#
require 'rails_helper'

RSpec.describe Checksum, type: :model do
  let(:task_execution) { create(:task_execution) }
  let(:filename) { 'bonjour.txt' }

  it "doesn't remove file exported for the first time" do
    File.write(filename, 'bonjour')
    Checksum.dedupe(task_execution, filename)
    expect(File).to exist(filename)
  ensure
    FileUtils.rm_f(filename)
  end

  it 'remove file exported for the second time' do
    File.write(filename, 'bonjour')
    Checksum.dedupe(task_execution, filename)
    Checksum.dedupe(task_execution, filename)
    expect(File).not_to exist(filename)
  ensure
    FileUtils.rm_f(filename)
  end

  it "doesn't remove updated file" do
    File.write(filename, 'bonjour')
    Checksum.dedupe(task_execution, filename)
    File.write(filename, 'bonjour à tous')
    Checksum.dedupe(task_execution, filename)
    expect(File).to exist(filename)
  ensure
    FileUtils.rm_f(filename)
  end
end
