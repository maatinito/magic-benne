# frozen_string_literal: true

# service to download dossier report and save them in common format

require 'tempfile'
require 'open-uri'
require 'roo'
require 'fileutils'

class ExportEtatNominatif < DossierTask
  def version
    1
  end

  def required_fields
    super + %i[champ_etat]
  end

  def authorized_fields
    super + %i[empty_lines prefixe_fichier]
  end

  def self.symbolize(name)
    name.tr('%', 'P').parameterize.underscore.to_sym
  end

  TITLE_LABELS = [
    'Nom de famille', 'Nom marital', 'Prénom', 'Date de naissance', 'DN', 'Heures avant ',
    'Brut mensuel moyen', 'Heures à réaliser', 'DMO', "Jours non rémunérés|Jours d'absence",
    "Jours d'indemnités journalières", 'Taux RTT*', 'Aide', 'Cotisations', '% temps présent',
    '% réalisé convention|% convention effectuée', '% perte salaire', '% aide', 'plafond'
  ].freeze

  COLUMN_LABELS = (TITLE_LABELS + ['aide maximale']).freeze

  COLUMNS = TITLE_LABELS.map { |name| [symbolize(name), Regexp.new(name, Regexp::IGNORECASE)] }.to_h

  def run
    report = param_value(:champ_etat)
    return if report.nil?

    export_report(report)
  end

  private

  def export_report(report)
    file = report.file
    if file.present?
      filename = file.filename
      url = file.url
      extension = File.extname(filename)
      download_report(extension, url)
    else
      Rails.logger.warn("Pas d'état nominatif attaché au dossier #{dossier.number}")
    end
  end

  def self.create_target_dir(task, dossier)
    no_tahiti = no_tahiti_iti(dossier) || task.dossier.demandeur.siret || ''
    raison_sociale = dossier.demandeur.entreprise.raison_sociale || dossier.demandeur.entreprise.nom_commerciale || ''
    dir = "#{task.output_dir}/#{raison_sociale}#{raison_sociale ? ' - ' : ''}#{no_tahiti}/#{task.demarche_dir}/#{dossier.number}"

    FileUtils.mkpath(dir)
    dir
  end

  def self.no_tahiti_iti(dossier)
    field = dossier_field_value(dossier, 'Numéro Tahiti Iti')&.value
    return nil if field.nil?

    field.strip.upcase.gsub(/[^0-9A-Z]/, '')
  end

  def self.dossier_field_value(dossier, field)
    return nil if dossier.nil? || field.blank?

    objects = [*dossier]
    field.split(/\./).each do |name|
      objects = objects.flat_map { |object| object.champs.select { |champ| champ.label == name } }
      Rails.logger.warn("Sur le dossier #{dossier.number}, le champ #{field} est vide.") if objects.blank?
    end
    objects&.first
  end

  def download_report(extension, url)
    download(url, extension) do |file|
      case extension
      when '.xls', '.xlsx', '.csv'
        save_report(file)
      else
        Rails.logger.warn("Mauvaise extension de fichier #{extension} pour l'état du dossier #{dossier.number}")
      end
    end
  end

  def save_report(file)
    xlsx = Roo::Spreadsheet.open(file)
    regexp = sheet_regexp
    xlsx.sheets.filter { |name| name =~ regexp }.each do |name|
      save_sheet(name, xlsx.sheet(name))
    end
  end

  def save_sheet(sheet_name, sheet)
    save_employees(sheet_name, employees(sheet))
  rescue Roo::HeaderRowNotFoundError => e
    columns = e.message.gsub(%r{[/\[\]]}, '')
    Rails.logger.error("Colonnes manquantes dans le dossier #{dossier.number} : #{columns}")
  end

  def output_path(_sheet_name)
    throw 'Must be defined by sub class'
  end

  def sheet_regexp
    throw 'Must be defined by subclass'
  end

  def save_employees(sheet_name, employees)
    Rails.logger.info("Saving #{employees.size} lines")
    path = output_path(sheet_name)
    CSV.open(path, 'wb',
             headers: COLUMN_LABELS,
             write_headers: true,
             col_sep: ';') do |csv|
      empty_lines = params[:empty_lines]
      empty_lines.to_i.times { csv << [] } if empty_lines.present?
      employees.each do |line|
        output_line = COLUMN_LABELS.map do |column|
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
        csv << output_line
      end
    end
  end

  def employees(sheet)
    rows = sheet.parse(COLUMNS)
    rows.reject { |line| line[:prenom].nil? || line[:prenom] =~ /Prénom/ }.map do |line|
      line.each { |_, value| value.strip! if value.is_a?(String) }
      if (date = line[:date_de_naissance]).present?
        normalize_date(date, line)
      end
      # pp line
      line[:aide] = line[:aide].round if line[:aide].is_a?(Float)
      line[:aide_maximale] = 0
      line
    end
  end

  def normalize_date(date, line)
    case date
    when Integer, Float
      date = Date.new(1899, 12, 30) + line[:date_de_naissance].days
    when String
      date = parse(date, line)
    end
    line[:date_de_naissance] = date
  end

  def parse(date, line)
    date.gsub!(%r{[-:./]}, '-')
    if match = date.match(/(\d+)-(\d+)-(\d+)/)
      day, month, year = match.captures.map(&:to_i)
      year += 2000 if year < 100
      year -= 100 if year > Date.today.year
      date = Date.new(year, month, day)
    else
      Rails.logger.error("dossier #{dossier.number}: impossible de lire la date #{line[:date_de_naissance]} (#{line[:nom]}")
      date = Date.new(1900, 1, 1)
    end
    date
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
