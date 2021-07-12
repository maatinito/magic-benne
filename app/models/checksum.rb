# frozen_string_literal: true

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

class Checksum < ApplicationRecord
  belongs_to :task_execution

  def self.dedupe(task_execution, filename, overwritten: false)
    md5 = hexdigest(filename)
    checksum = Checksum.find_or_initialize_by(task_execution: task_execution, filename: filename)
    if checksum.md5 == md5 && !overwritten
      File.delete(filename)
    else
      checksum.md5 = md5
      checksum.save
    end
  end

  def self.clear_all
    Checksum.destroy_all
  end

  def self.hexdigest(filename)
    File.open(filename, 'rb') do |io|
      dig = Digest::MD5.new
      buf = +''
      dig.update(buf) while io.read(4096, buf)
      dig.hexdigest
    end
  end
end
