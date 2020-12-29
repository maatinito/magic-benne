# frozen_string_literal: true

# controller to trigger CSV exports
#
class DemarchesController < ApplicationController
  def download
    @service = DownloadCsvService.new(24.days)
    redirect_to demarches_main_path
  end

  def main; end
end
