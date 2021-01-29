# frozen_string_literal: true

# service to download dossier report and save them in common format

require 'tempfile'
require 'open-uri'
require 'roo'
require 'fileutils'

class ExportEtatReel < DossierTask

  def version
    1
  end

  def required_fields
    super + %i[champ_etat champ_mois champ_dossier]
  end

  def authorized_fields
    super + %i[empty_lines]
  end

  TITLE_LABELS = [
    'Nom de famille', 'Nom marital', 'Prénom', 'Date de naissance', 'DN', 'Heures avant convention',
    'Brut mensuel moyen', 'Heures à réaliser', 'DMO', 'Jours non rémunérés',
    "Jours d'indemnités journalières", 'Taux RTT*', 'Aide', 'Cotisations', '% temps présent', '% réalisé convention',
    '% perte salaire', '% aide', 'plafond', 'aide maximale'
  ].freeze

  def self.symbolize(name)
    name.tr('%', 'P').parameterize.underscore.to_sym
  end

  TITLE_STRINGS = TITLE_LABELS[0..2].map { |s| symbolize(s) }

  COLUMNS = TITLE_LABELS.map { |name| [symbolize(name), Regexp.new(name)] }.to_h

  def run
    etat = param_value(:champ_etat)
    return if etat.nil?

    month_field = param_value(:champ_mois)
    return if month_field.nil?

    year = month_field.primary_value
    month = month_field.secondary_value

    diese_field = param_value(:champ_dossier)
    return if diese_field.nil?

    diese_number = diese_field.string_value

    export_report(etat, diese_number, month, year)
  end

  private

  def export_report(etat, diese_number, month, year)
    file = etat.file
    if file.present?
      filename = file.filename
      url = file.url
      extension = File.extname(filename)
      # no_tahiti = dossier.demandeur.siret || ''
      basename = params['champ_etat'] || 'Etat'
      output_path = "#{output_dir}/#{basename}-#{diese_number}-#{year}-#{month}.csv"
      download_report(output_path, extension, url)
    else
      Rails.logger.warn("Pas d'état nominatif attaché au dossier #{dossier.number}")
    end
  end

  def download_report(output_path, extension, url)
    download(url, extension) do |file|
      case extension
      when '.xls', '.xlsx', '.csv'
        save_report(output_path, file)
      else
        Rails.logger.warn("Mauvaise extension de fichier #{extension} pour l'état du dossier #{dossier.number}")
      end
    end
  end

  def save_report(output_path, file)
    Rails.logger.info("Saving report to #{output_path}")
    xlsx = Roo::Spreadsheet.open(file)
    xlsx.sheets.filter { |name| name =~ /Etat|default/ }.each do |name|
      save_sheet(output_path, xlsx.sheet(name))
    end
  end

  def save_sheet(output_path, sheet)
    employees = employees(sheet)
    save_employees(output_path, employees)
  rescue Roo::HeaderRowNotFoundError => e
    columns = e.message.gsub(%r{[/\[\]]}, '')
    Rails.logger.error("Colonnes manquantes dans #{output_path} : #{columns}")
  end

  def save_employees(output_path, employees)
    Rails.logger.info("Saving #{employees.size} lines")
    CSV.open(output_path, 'wb',
             headers: TITLE_LABELS,
             write_headers: true,
             write_headers: true,
             col_sep: ';') do |csv|
      empty_lines = params['empty_lines']
      empty_lines.to_i.times { csv << [] } if empty_lines.present?
      employees.each do |line|
        output_line = TITLE_LABELS.map do |column|
          value = line[self.class.symbolize(column)]
          case value
          when Date
            value.strftime('%d/%m/%Y')
          when Float
            value.to_s.tr('.', ',')
          else
            value
          end
        end
        Rails.logger.info(output_line)
        csv << output_line
      end
    end
  end

  def employees(sheet)
    rows = sheet.parse(COLUMNS)
    rows.reject { |line| line[:prenom].nil? || line[:prenom] =~ /Prénom/ }.map do |line|
      if line[:date_de_naissance].present?
        line[:date_de_naissance] =
          Date.new(1899, 12, 30) + line[:date_de_naissance].days
      end
      pp line
      TITLE_STRINGS.each { |key| line[key].strip! }
      line[:aide] = line[:aide].round if line[:aide].is_a?(Float)
      line
    end
  end

  def download(url, extension)
    Tempfile.create(['res', extension]) do |f|
      f.binmode
      f.write URI.open(url).read
      f.rewind
      yield f
    end
  end
end
