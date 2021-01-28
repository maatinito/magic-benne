# frozen_string_literal: true

# controller to trigger CSV exports
#
class DemarchesController < ApplicationController
  def export
    @service = DemarcheService.new(reset: false, config_file: 'storage/demarches.yml').process
    redirect_to demarches_main_path
  end

  def export_all
    @service = DemarcheService.new(reset: true, config_file: 'storage/demarches.yml').process
    # @service = DemarcheService.new(reset: true, config_file: 'spec/fixtures/files/raise_exception.yml').process
    redirect_to demarches_main_path
  end

  def main; end
end
