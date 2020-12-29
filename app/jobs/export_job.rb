# frozen_string_literal: true

class ExportJob < CronJob
  self.schedule_expression = 'every weekday at 07:00 and 13:00'

  def perform(*_args)
    DownloadCsvService.new.export
  end
end
