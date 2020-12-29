# frozen_string_literal: true

# controller to trigger CSV exports
#
class DemarchesController < ApplicationController
  def export
    @service = DownloadCsvService.new.export
    redirect_to demarches_main_path
  end

  def export_all
    @service = DownloadCsvService.new(reset: true).export
    redirect_to demarches_main_path
  end

  def main; end
end
