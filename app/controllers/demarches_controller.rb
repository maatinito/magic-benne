# frozen_string_literal: true

# controller to trigger CSV exports
#
class DemarchesController < ApplicationController
  def export
    ExportJob.run(false, 'storage/demarches.yml')
    redirect_to demarches_main_path
  end

  def export_all
    ExportJob.run(true, 'storage/demarches.yml')
    redirect_to demarches_main_path
  end

  def main
    @running = ExportJob.running?
    pp @running
  end
end
