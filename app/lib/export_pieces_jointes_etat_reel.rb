# frozen_string_literal: true

# service to download dossier report and save them in common format

require 'tempfile'
require 'open-uri'
require 'roo'
require 'fileutils'

class ExportPiecesJointesEtatReel < ExportPiecesJointes
  include Utils

  def version
    super + 1
  end

  def required_fields
    super + %i[champ_dossier champ_mois]
  end

  private

  def run
    month_field = param_value(:champ_mois)
    return if month_field.nil?

    @year = month_field.primary_value
    @month = month_field.secondary_value

    @initial_dossier = nil

    super
  end

  def output_path(champ, filename)
    dir = create_target_dir(initial_dossier)
    self.class.sanitize(@index, "#{champ} - #{filename}")
    index = report_index(@initial_dossier, @month)

    extension = File.extname(filename)
    file = self.class.sanitize(@index, "Mois #{index} - #{champ} - #{@month}-#{@year} - #{dossier.number}#{extension}")
    "#{dir}/#{file}"
  end
end
