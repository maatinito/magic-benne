# frozen_string_literal: true

class ExportJob < CronJob
  self.schedule_expression = 'every weekday at 12:00 and 19:00'

  MANUAL_SYNC = 'ManualSync'

  def perform(reset: false, config: 'storage/demarches.yml')
    Sync.find_or_create_by(job: MANUAL_SYNC)
    Sync.find_or_create_by(job: self.class.name) do
      DemarcheService.new(reset: reset, config_file: config).process
    end
  ensure
    Sync.where(job: self.class.name).destroy_all
    Sync.where(job: MANUAL_SYNC).destroy_all
  end

  def max_attempts
    1
  end

  class << self
    def run(reset, config)
      Sync.find_or_create_by(job: MANUAL_SYNC) do
        ExportJob.perform_later(reset: reset, config: config)
      end
    end

    def running?
      Sync.exists?(job: MANUAL_SYNC)
    end
  end
end
