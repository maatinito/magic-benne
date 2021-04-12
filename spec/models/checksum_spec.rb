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
require 'rails_helper'

RSpec.describe Checksum, type: :model do
  let(:task_execution) { create(:task_execution) }
  let(:filename) { 'bonjour.txt' }

  it "doesn't remove file exported for the first time" do
    File.open(filename, 'w') { |f|  f.write 'bonjour' }
    Checksum.dedupe(task_execution, filename)
    expect(File).to exist(filename)
  ensure
    File.delete(filename) if File.exist?(filename)
  end

  it 'remove file exported for the second time' do
    File.open(filename, 'w') { |f|  f.write 'bonjour' }
    Checksum.dedupe(task_execution, filename)
    Checksum.dedupe(task_execution, filename)
    expect(File).not_to exist(filename)
  ensure
    File.delete(filename) if File.exist?(filename)
  end

  it "doesn't remove updated file" do
    File.open(filename, 'w') { |f|  f.write 'bonjour' }
    Checksum.dedupe(task_execution, filename)
    File.open(filename, 'w') { |f|  f.write 'bonjour à tous' }
    Checksum.dedupe(task_execution, filename)
    expect(File).to exist(filename)
  ensure
    File.delete(filename) if File.exist?(filename)
  end
end
