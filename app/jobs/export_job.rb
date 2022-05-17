# frozen_string_literal: true

class ExportJob < CronJob
  self.schedule_expression = ENV.fetch('SCHEDULE', 'every weekday at 18:30')

  MANUAL_SYNC = 'ManualSync'

  def perform(reset: false, config: nil)
    Sync.find_or_create_by(job: MANUAL_SYNC)
    Sync.find_or_create_by(job: self.class.name) do
      DemarcheService.new(reset:, config_file: config).process
    end
  ensure
    Sync.where(job: self.class.name).destroy_all
    Sync.where(job: MANUAL_SYNC).destroy_all
  end

  def max_attempts
    1
  end

  class << self
    def run(reset, config: nil)
      Sync.find_or_create_by(job: MANUAL_SYNC) do
        ExportJob.perform_later(reset:, config:)
      end
    end

    def running?
      Sync.exists?(job: MANUAL_SYNC)
    end
  end
end
